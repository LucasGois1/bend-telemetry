// Unit tests of the verifier, run with `node --test qualification/*.test.mjs`
// on recorded fixtures: the line that the Collector's file exporter wrote and
// the answer of Tempo's trace API, both for the reference trace sent by curl
// to the pinned stack. Each mismatching case changes the recorded output in
// one way and must fail with a diff that names the change.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { canonicalize, compareCollector, compareTempo, parseJson, readJsonLines } from './verify.mjs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
const reference = parseJson(read('reference-trace.json'));
// Fresh parses, so that each test may change its own copy.
const collectorOutput = () => readJsonLines(read('fixtures/collector-output.jsonl'));
const tempoResponse = () => parseJson(read('fixtures/tempo-response.json'));

const spansOf = (request) =>
  request.resourceSpans.flatMap((resource) => resource.scopeSpans.flatMap((scope) => scope.spans));
const spanNamed = (requests, name) => requests.flatMap(spansOf).find((span) => span.name === name);
const tempoSpanNamed = (response, name) => spansOf(response.trace).find((span) => span.name === name);
const changedLines = (diff, sign) => diff.split('\n').filter((line) => line.startsWith(sign) && !line.startsWith(sign.repeat(3)));

test('the recorded Collector output matches the reference trace', () => {
  const result = compareCollector(reference, collectorOutput());
  assert.equal(result.diff, '');
  assert.equal(result.match, true);
});

test('a changed attribute fails, and the diff shows both values', () => {
  const output = collectorOutput();
  const root = spanNamed(output, 'GET /users/:id');
  root.attributes.find((attribute) => attribute.key === 'qualification.int').value.intValue = '-9007199254740992';
  const result = compareCollector(reference, output);
  assert.equal(result.match, false);
  assert.match(changedLines(result.diff, '-').join('\n'), /"intValue": "-9007199254740993"/);
  assert.match(changedLines(result.diff, '+').join('\n'), /"intValue": "-9007199254740992"/);
});

test('a missing span fails, and the diff shows the span removed', () => {
  const output = collectorOutput();
  for (const resource of output[0].resourceSpans) {
    for (const scope of resource.scopeSpans) scope.spans = scope.spans.filter((span) => span.name !== 'render');
  }
  const result = compareCollector(reference, output);
  assert.equal(result.match, false);
  assert.match(changedLines(result.diff, '-').join('\n'), /"name": "render"/);
  assert.deepEqual(changedLines(result.diff, '+'), []);
});

test('a wrong parent fails, and the diff shows both parents', () => {
  const output = collectorOutput();
  spanNamed(output, 'render').parentSpanId = spanNamed(output, 'GET').spanId;
  const result = compareCollector(reference, output);
  assert.equal(result.match, false);
  assert.match(changedLines(result.diff, '-').join('\n'), /"parentSpanId": "90fc8028d84b8528"/);
  assert.match(changedLines(result.diff, '+').join('\n'), /"parentSpanId": "a4e46f4e67ea0510"/);
});

test('spans of the reference trace split over several exports still match', () => {
  const [first] = collectorOutput();
  const [second] = collectorOutput();
  first.resourceSpans[0].scopeSpans[0].spans.splice(1);
  second.resourceSpans[0].scopeSpans[0].spans.splice(0, 1);
  assert.equal(compareCollector(reference, [first, second]).match, true);
});

test('a span exported twice fails', () => {
  const output = collectorOutput();
  const result = compareCollector(reference, [...output, ...collectorOutput()]);
  assert.equal(result.match, false);
});

test('spans of other traces in the output are ignored', () => {
  const output = collectorOutput();
  const other = collectorOutput()[0];
  for (const span of spansOf(other)) span.traceId = '0123456789abcdef0123456789abcdef';
  other.resourceSpans[0].scopeSpans[0].spans[0].name = 'another trace';
  assert.equal(compareCollector(reference, [other, ...output]).match, true);
});

test('the recorded Tempo response matches the reference trace', () => {
  const result = compareTempo(reference, tempoResponse());
  assert.equal(result.diff, '');
  assert.equal(result.match, true);
});

test('Tempo missing a span fails', () => {
  const response = tempoResponse();
  for (const resource of response.trace.resourceSpans) {
    for (const scope of resource.scopeSpans) scope.spans = scope.spans.filter((span) => span.name !== 'GET');
  }
  const result = compareTempo(reference, response);
  assert.equal(result.match, false);
  assert.match(changedLines(result.diff, '-').join('\n'), /"name": "GET"/);
});

test('Tempo with a wrong parent fails', () => {
  const response = tempoResponse();
  tempoSpanNamed(response, 'render').parentSpanId = tempoSpanNamed(response, 'GET').spanId;
  const result = compareTempo(reference, response);
  assert.equal(result.match, false);
  assert.match(changedLines(result.diff, '+').join('\n'), /"parentSpanId": "a4e46f4e67ea0510"/);
});

test('Tempo with a changed name fails', () => {
  const response = tempoResponse();
  tempoSpanNamed(response, 'render').name = 'draw';
  assert.equal(compareTempo(reference, response).match, false);
});

// Every object of a value with its keys in reverse order.
function reversed(value) {
  if (Array.isArray(value)) return value.map(reversed);
  if (value === null || typeof value !== 'object' || value.constructor !== Object) return value;
  return Object.fromEntries(Object.entries(value).reverse().map(([key, item]) => [key, reversed(item)]));
}

test('canonicalization ignores the order of keys', () => {
  const span = spansOf(reference)[0];
  assert.notDeepEqual(Object.keys(reversed(span)), Object.keys(span));
  assert.deepEqual(canonicalize(reversed(span)), canonicalize(span));
});

test('canonicalization reads 64-bit integers exactly, as strings or as numbers', () => {
  const asNumbers = canonicalize(parseJson('{"intValue": -9007199254740993, "timeUnixNano": 1790856000182456789}'));
  const asStrings = canonicalize(parseJson('{"intValue": "-9007199254740993", "timeUnixNano": "1790856000182456789"}'));
  assert.deepEqual(asNumbers, { intValue: '-9007199254740993', timeUnixNano: '1790856000182456789' });
  assert.deepEqual(asStrings, asNumbers);
  assert.notDeepEqual(canonicalize(parseJson('{"intValue": "-9007199254740992"}')), { intValue: '-9007199254740993' });
});

test('canonicalization reads enumerations by name or by number', () => {
  assert.deepEqual(
    canonicalize(parseJson('{"kind": "SPAN_KIND_CLIENT", "status": {"code": "STATUS_CODE_ERROR"}}')),
    canonicalize(parseJson('{"kind": 3, "status": {"code": 2}}')));
});

test('canonicalization omits default values, but not the value of an attribute', () => {
  assert.deepEqual(
    canonicalize(parseJson('{"name": "a", "parentSpanId": "", "flags": 0, "droppedLinksCount": 0, "links": [], "status": {}}')),
    { name: 'a' });
  assert.deepEqual(canonicalize(parseJson('{"boolValue": false}')), { boolValue: false });
  assert.notDeepEqual(
    canonicalize(parseJson('{"key": "k", "value": {"intValue": "0"}}')),
    canonicalize(parseJson('{"key": "k", "value": {}}')));
});

test('canonicalization reads identifiers in any case and bytes in any base64 alphabet', () => {
  assert.deepEqual(
    canonicalize(parseJson('{"traceId": "2904730AFD20F69BAABE13593B08A9A0", "bytesValue": "AAEC-_3-_w"}')),
    { traceId: '2904730afd20f69baabe13593b08a9a0', bytesValue: 'AAEC+/3+/w==' });
});

test('canonicalization orders attributes by key and spans by identifier, and keeps the order of array values', () => {
  const canonical = canonicalize(parseJson(`{
    "spans": [{"spanId": "b0"}, {"spanId": "a0"}],
    "attributes": [
      {"key": "z", "value": {"arrayValue": {"values": [{"intValue": "2"}, {"intValue": "1"}]}}},
      {"key": "a", "value": {"kvlistValue": {"values": [{"key": "y"}, {"key": "x"}]}}}
    ]}`));
  assert.deepEqual(canonical.spans.map((span) => span.spanId), ['a0', 'b0']);
  assert.deepEqual(canonical.attributes.map((attribute) => attribute.key), ['a', 'z']);
  assert.deepEqual(canonical.attributes[0].value.kvlistValue.values.map((entry) => entry.key), ['x', 'y']);
  assert.deepEqual(canonical.attributes[1].value.arrayValue.values, [{ intValue: '2' }, { intValue: '1' }]);
});

test('reading JSON lines leaves out a line the Collector has not finished', () => {
  const text = read('fixtures/collector-output.jsonl');
  assert.equal(readJsonLines(text + text.slice(0, 40)).length, readJsonLines(text).length);
});
