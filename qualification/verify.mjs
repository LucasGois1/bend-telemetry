// The verifier of the qualification harness. After a producer has sent its
// trace to the stack, it checks two layers against the reference trace and
// prints a readable diff of any mismatch:
//
//   - the Collector: the OTLP/JSON lines that the Collector's file exporter
//     wrote from --from-byte on must hold the reference trace exactly. Both
//     sides are compared in canonical form: keys sorted; 64-bit integers read
//     exactly, whether written as strings, as OTLP/JSON does, or as numbers;
//     enumerations as numbers; default values omitted, except the one field
//     of an attribute value, kept even when it is false, 0 or empty;
//     identifiers in lowercase hex; bytes in padded standard base64;
//     attributes ordered by key and spans by identifier; and the spans of the
//     reference trace gathered by resource and scope across exports, so that
//     the way a producer batches its spans does not matter. Spans of other
//     traces are left out.
//   - Tempo: GET /api/v2/traces/<trace id> must show the reference trace's
//     spans, with their names and parent links. Tempo's JSON writes
//     identifiers in base64; they are compared in hex.
//
// Each layer is retried until it matches or until the timeout passes: the
// Collector flushes its file every second, and Tempo answers 404 until it has
// the trace.
//
//   node qualification/verify.mjs [--reference FILE] [--collector-output FILE]
//     [--from-byte N] [--tempo URL] [--timeout SECONDS] [--evidence DIR]
//
// The defaults are those of the stack in qualification/compose.yaml:
// qualification/reference-trace.json, build/qualification/collector/
// traces.jsonl from its first byte, http://127.0.0.1:3200, 30 seconds per
// layer, and build/qualification/verifier/ for the evidence: each layer's
// expected and actual canonical forms, their diff on a mismatch, Tempo's last
// answer and a summary. The exit status is 0 when both layers match, 1 when
// either does not, and 2 on a usage error. scripts/qualify.sh runs it.
import { existsSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';

// A JSON number, kept as the text it was written with: a 64-bit integer may
// not survive a double.
class JsonNumber {
  constructor(source) {
    this.source = source;
  }
}

// The value of a JSON text, with every number as a JsonNumber.
export function parseJson(text) {
  return JSON.parse(text, (key, value, context) =>
    typeof value === 'number' ? new JsonNumber(context?.source ?? String(value)) : value);
}

// The parsed lines of a JSON lines text; a last line without its newline is
// still being written and is left out.
export function readJsonLines(text) {
  return text.slice(0, text.lastIndexOf('\n') + 1).split('\n').filter((line) => line.trim() !== '').map(parseJson);
}

const INT64_FIELDS = new Set(['intValue', 'timeUnixNano', 'startTimeUnixNano', 'endTimeUnixNano']);
const UINT32_FIELDS = new Set(['flags', 'droppedAttributesCount', 'droppedEventsCount', 'droppedLinksCount']);
const ENUM_FIELDS = {
  kind: ['SPAN_KIND_UNSPECIFIED', 'SPAN_KIND_INTERNAL', 'SPAN_KIND_SERVER', 'SPAN_KIND_CLIENT', 'SPAN_KIND_PRODUCER',
    'SPAN_KIND_CONSUMER'],
  code: ['STATUS_CODE_UNSET', 'STATUS_CODE_OK', 'STATUS_CODE_ERROR'],
};
const ID_FIELDS = new Set(['traceId', 'spanId', 'parentSpanId']);
// The members of an attribute value's oneof, present even with a default.
const VALUE_FIELDS = new Set(['stringValue', 'boolValue', 'intValue', 'doubleValue', 'bytesValue', 'arrayValue',
  'kvlistValue']);
const DOUBLE_WORDS = new Set(['NaN', 'Infinity', '-Infinity']);

const textOf = (value) => (value instanceof JsonNumber ? value.source : value);
const isInteger = (text) => typeof text === 'string' && /^-?\d+$/.test(text);

function integer(value) {
  const text = textOf(value);
  return isInteger(text) ? Number(text) : canonicalize(value);
}

function int64(value) {
  const text = textOf(value);
  return isInteger(text) ? BigInt(text).toString() : canonicalize(value);
}

function double(value) {
  const text = textOf(value);
  if (DOUBLE_WORDS.has(text)) return text;
  return typeof text === 'string' && text.trim() !== '' && !Number.isNaN(Number(text)) ? Number(text) : canonicalize(value);
}

function enumeration(names, value) {
  return names.includes(value) ? names.indexOf(value) : integer(value);
}

// The order of two texts by their UTF-16 code units, the same everywhere,
// unlike a locale's.
const byCodeUnits = (a, b) => (a < b ? -1 : Number(a > b));
const byFirst = ([a], [b]) => byCodeUnits(a, b);

// Sorted by a field, then by the whole item, so that equal fields still sort
// the same way on both sides.
function sortedBy(items, field) {
  if (!Array.isArray(items)) return items;
  return items.map((item) => [`${item?.[field]}\u0000${JSON.stringify(item)}`, item]).sort(byFirst).map(([, item]) => item);
}

function isDefault(key, value) {
  if (VALUE_FIELDS.has(key)) return false;
  if (INT64_FIELDS.has(key)) return value === '0';
  if (Array.isArray(value)) return value.length === 0;
  if (value !== null && typeof value === 'object') return Object.keys(value).length === 0;
  return value === null || value === '' || value === false || value === 0;
}

// The canonical form of a field's value; `owner` is the key of the object
// that holds the field.
function canonicalField(key, value, owner) {
  if (INT64_FIELDS.has(key)) return int64(value);
  if (UINT32_FIELDS.has(key)) return integer(value);
  if (key in ENUM_FIELDS) return enumeration(ENUM_FIELDS[key], value);
  if (key === 'doubleValue') return double(value);
  if (ID_FIELDS.has(key) && typeof value === 'string') return value.toLowerCase();
  if (key === 'bytesValue' && typeof value === 'string') return Buffer.from(value, 'base64').toString('base64');
  if (key === 'attributes' || (key === 'values' && owner === 'kvlistValue')) return sortedBy(canonicalize(value, key), 'key');
  if (key === 'spans') return sortedBy(canonicalize(value, key), 'spanId');
  return canonicalize(value, key);
}

// The canonical form of a parsed OTLP/JSON value, or of any part of one;
// `key` is the key that holds it, if any.
export function canonicalize(value, key) {
  if (value instanceof JsonNumber) return Number(value.source);
  if (Array.isArray(value)) return value.map((item) => canonicalize(item, key));
  if (value === null || typeof value !== 'object') return value;
  const fields = [];
  for (const field of Object.keys(value).sort(byCodeUnits)) {
    const canonical = canonicalField(field, value[field], key);
    if (!isDefault(field, canonical)) fields.push([field, canonical]);
  }
  return Object.fromEntries(fields);
}

const spansOf = (request) =>
  (request?.resourceSpans ?? []).flatMap((resource) => (resource.scopeSpans ?? []).flatMap((scope) => scope.spans ?? []));

const traceIdsOf = (requests) => new Set(requests.flatMap((request) => spansOf(canonicalize(request))).map((span) => span.traceId));

// Each span of a canonical request with its resource spans and its scope spans,
// both without their lists.
const placedSpans = (request) =>
  (request.resourceSpans ?? []).flatMap(({ scopeSpans = [], ...resource }) =>
    scopeSpans.flatMap(({ spans = [], ...scope }) => spans.map((span) => ({ resource, scope, span }))));

// The entry of a map for a value, by the value's JSON text, made on first use.
function entryFor(map, value, make) {
  const key = JSON.stringify(value);
  if (!map.has(key)) map.set(key, make());
  return map.get(key);
}

// The spans of the given traces in a list of export requests, as one canonical
// request: one resource spans per distinct resource and schema URL, one scope
// spans per distinct scope and schema URL within it.
function canonicalTrace(requests, traceIds) {
  const resources = new Map();
  const placed = requests.flatMap((request) => placedSpans(canonicalize(request)));
  for (const { resource, scope, span } of placed.filter((item) => traceIds.has(item.span.traceId))) {
    const { scopes } = entryFor(resources, resource, () => ({ resource, scopes: new Map() }));
    entryFor(scopes, scope, () => ({ scope, spans: [] })).spans.push(span);
  }
  return canonicalize({
    resourceSpans: [...resources].sort(byFirst).map(([, { resource, scopes }]) => ({
      ...resource,
      scopeSpans: [...scopes].sort(byFirst).map(([, { scope, spans }]) => ({ ...scope, spans })),
    })),
  });
}

// An array item's name in a path: an attribute's key, a span's or an event's
// name, or else its index.
function itemName(item, index) {
  for (const field of ['key', 'name']) {
    if (typeof item?.[field] === 'string') return JSON.stringify(item[field]);
  }
  return String(index);
}

// The path, the text before and the value of each item of an array or each
// field of an object; none for any other value.
function entriesOf(value, path) {
  if (Array.isArray(value)) return value.map((item, index) => [`${path}[${itemName(item, index)}]`, '', item]);
  if (value === null || typeof value !== 'object') return [];
  return Object.entries(value).map(([key, item]) => [path ? `${path}.${key}` : key, `${JSON.stringify(key)}: `, item]);
}

// The lines of JSON.stringify(value, null, 2), each with the path of the value
// it belongs to, such as spans["GET"].attributes["url.full"].value.
function rendered(value, path = '', indent = '', head = '', tail = '', lines = []) {
  const entries = entriesOf(value, path);
  if (entries.length === 0) {
    lines.push({ text: `${indent}${head}${JSON.stringify(value)}${tail}`, path });
    return lines;
  }
  const [open, close] = Array.isArray(value) ? ['[', ']'] : ['{', '}'];
  lines.push({ text: `${indent}${head}${open}`, path });
  entries.forEach(([itemPath, itemHead, item], index) =>
    rendered(item, itemPath, `${indent}  `, itemHead, index < entries.length - 1 ? ',' : '', lines));
  lines.push({ text: `${indent}${close}${tail}`, path });
  return lines;
}

const textOfLines = (lines) => `${lines.map((line) => line.text).join('\n')}\n`;

// The comparison of two canonical values: whether they match, both rendered,
// and the diff.
function comparison(expectedValue, actualValue) {
  const [expectedLines, actualLines] = [rendered(expectedValue), rendered(actualValue)];
  const [expected, actual] = [textOfLines(expectedLines), textOfLines(actualLines)];
  const match = expected === actual;
  return { match, expected, actual, diff: match ? '' : unifiedDiff(expectedLines, actualLines) };
}

// The comparison of the Collector's output, a list of parsed export requests,
// with the parsed reference trace.
export function compareCollector(reference, requests) {
  const traceIds = traceIdsOf([reference]);
  return comparison(canonicalTrace([reference], traceIds), canonicalTrace(requests, traceIds));
}

// Each span's identifier, parent and name, in the order of the identifiers.
const spanTree = (spans) => sortedBy(spans.map(({ spanId, parentSpanId, name }) =>
  ({ spanId, ...(parentSpanId ? { parentSpanId } : {}), name })), 'spanId');

const hexOfBase64 = (value) => (typeof value === 'string' ? Buffer.from(value, 'base64').toString('hex') : value);

// The comparison of Tempo's answer for the trace, parsed, with the parsed
// reference trace: the span count, the names and the parent links.
export function compareTempo(reference, response) {
  const expected = spanTree(spansOf(canonicalize(reference)));
  const actual = spanTree(spansOf(response?.trace).map((span) =>
    ({ spanId: hexOfBase64(span.spanId), parentSpanId: hexOfBase64(span.parentSpanId), name: span.name })));
  return comparison(expected, actual);
}

// common[i][j]: the length of the longest common subsequence of the lines
// a[i..] and b[j..].
function commonLengths(a, b) {
  const common = Array.from({ length: a.length + 1 }, () => new Uint32Array(b.length + 1));
  for (let i = a.length - 1; i >= 0; i -= 1) {
    for (let j = b.length - 1; j >= 0; j -= 1) {
      common[i][j] = a[i].text === b[j].text ? common[i + 1][j + 1] + 1 : Math.max(common[i + 1][j], common[i][j + 1]);
    }
  }
  return common;
}

// The lines of two rendered values aligned on their longest common
// subsequence: each line kept (' '), removed from the first ('-') or added in
// the second ('+').
function alignedLines(a, b) {
  const common = commonLengths(a, b);
  const lines = [];
  let i = 0;
  let j = 0;
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i].text === b[j].text) {
      lines.push([' ', a[i]]);
      i += 1;
      j += 1;
    } else if (i < a.length && (j === b.length || common[i + 1][j] >= common[i][j + 1])) {
      lines.push(['-', a[i]]);
      i += 1;
    } else {
      lines.push(['+', b[j]]);
      j += 1;
    }
  }
  return lines;
}

// The ranges of aligned lines holding changes no more than twice the context
// apart.
function changedRanges(lines, context) {
  const ranges = [];
  lines.forEach(([sign], index) => {
    if (sign === ' ') return;
    const last = ranges.at(-1);
    if (last && index - last.end <= 2 * context) last.end = index;
    else ranges.push({ start: index, end: index });
  });
  return ranges;
}

// A unified diff of two rendered values, line by line, with three lines of
// context; each hunk names the path of its first changed line.
function unifiedDiff(a, b, context = 3) {
  const lines = alignedLines(a, b);
  const count = (items, sign) => items.filter(([itemSign]) => itemSign !== sign).length;
  const output = ['--- expected', '+++ actual'];
  for (const { start, end } of changedRanges(lines, context)) {
    const from = Math.max(0, start - context);
    const body = lines.slice(from, end + context + 1);
    const before = lines.slice(0, from);
    const ranges = `-${count(before, '+') + 1},${count(body, '+')} +${count(before, '-') + 1},${count(body, '-')}`;
    const path = lines[start][1].path;
    output.push(path ? `@@ ${ranges} @@ ${path}` : `@@ ${ranges} @@`, ...body.map(([sign, line]) => sign + line.text));
  }
  return output.length > 2 ? `${output.join('\n')}\n` : '';
}

const repository = fileURLToPath(new URL('..', import.meta.url));
const usage = `Usage: node qualification/verify.mjs [--reference FILE] [--collector-output FILE] [--from-byte N]
  [--tempo URL] [--timeout SECONDS] [--evidence DIR]`;

function settingsOf(argv) {
  const settings = {
    reference: join(repository, 'qualification/reference-trace.json'),
    'collector-output': join(repository, 'build/qualification/collector/traces.jsonl'),
    'from-byte': '0',
    tempo: 'http://127.0.0.1:3200',
    timeout: '30',
    evidence: join(repository, 'build/qualification/verifier'),
  };
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index].replace(/^--/, '');
    if (!argv[index].startsWith('--') || !Object.hasOwn(settings, name) || index + 1 >= argv.length) return undefined;
    settings[name] = argv[index + 1];
  }
  const counts = [settings['from-byte'], settings.timeout];
  return counts.every((count) => /^\d+$/.test(count)) && URL.canParse(settings.tempo) ? settings : undefined;
}

// Calls `attempt` until its result matches or the deadline, a time in
// milliseconds, has passed, and answers the last result.
async function retry(deadline, pause, attempt) {
  const result = await attempt();
  if (result.match || Date.now() >= deadline) return result;
  await sleep(pause);
  return retry(deadline, pause, attempt);
}

function readFrom(path, offset) {
  return existsSync(path) ? readFileSync(path).subarray(offset).toString('utf8') : '';
}

async function askTempo(url) {
  try {
    const answer = await fetch(url, { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(5000) });
    return { status: String(answer.status), body: await answer.text() };
  } catch (error) {
    return { status: `no answer (${error.message})`, body: '' };
  }
}

function tempoComparison(reference, answer) {
  if (answer.status !== '200') return compareTempo(reference, {});
  try {
    return compareTempo(reference, parseJson(answer.body));
  } catch {
    return compareTempo(reference, {});
  }
}

function writeEvidence(directory, layer, result) {
  writeFileSync(join(directory, `${layer}-expected.json`), result.expected);
  writeFileSync(join(directory, `${layer}-actual.json`), result.actual);
  const diff = join(directory, `${layer}.diff`);
  if (result.match) rmSync(diff, { force: true });
  else writeFileSync(diff, result.diff);
}

function report(passed, failed, result) {
  if (result.match) {
    console.log(`PASS: ${passed}`);
  } else {
    console.log(`FAIL: ${failed}; - expected, + actual:`);
    process.stdout.write(result.diff);
  }
}

async function main(argv) {
  if (argv.length === 1 && argv[0] === '--help') {
    console.log(usage);
    return 0;
  }
  const settings = settingsOf(argv);
  if (!settings) {
    console.error(usage);
    return 2;
  }
  const reference = parseJson(readFileSync(settings.reference, 'utf8'));
  const traceIds = [...traceIdsOf([reference])];
  if (traceIds.length !== 1) {
    console.error(`The reference trace must hold the spans of one trace; ${settings.reference} holds ${traceIds.length}.`);
    return 2;
  }
  const [traceId] = traceIds;
  mkdirSync(settings.evidence, { recursive: true });

  const offset = Number(settings['from-byte']);
  const deadline = () => Date.now() + Number(settings.timeout) * 1000;
  const collector = await retry(deadline(), 250, () =>
    compareCollector(reference, readJsonLines(readFrom(settings['collector-output'], offset))));
  writeEvidence(settings.evidence, 'collector', collector);
  report('the Collector wrote the reference trace exactly',
    `what the Collector wrote to ${settings['collector-output']} from byte ${offset} differs from the reference trace`,
    collector);

  const url = new URL(`/api/v2/traces/${traceId}`, settings.tempo).href;
  let answer;
  const tempo = await retry(deadline(), 1000, async () => {
    answer = await askTempo(url);
    return tempoComparison(reference, answer);
  });
  writeFileSync(join(settings.evidence, 'tempo-response.json'), answer.body);
  writeEvidence(settings.evidence, 'tempo', tempo);
  report(`Tempo shows the reference trace's spans, names and parent links at ${url}`,
    `the trace that Tempo shows at ${url} (last answer: ${answer.status}) differs from the reference trace`,
    tempo);

  const verdict = (result) => (result.match ? 'PASS' : 'FAIL');
  writeFileSync(join(settings.evidence, 'summary.txt'), [
    `reference: ${resolve(settings.reference)}`,
    `trace: ${traceId}`,
    `collector: ${verdict(collector)}: ${resolve(settings['collector-output'])} from byte ${offset}`,
    `tempo: ${verdict(tempo)}: ${url}, last answer ${answer.status}`,
    '',
  ].join('\n'));
  return collector.match && tempo.match ? 0 : 1;
}

if (process.argv[1] && pathToFileURL(realpathSync(process.argv[1])).href === import.meta.url) {
  process.exitCode = await main(process.argv.slice(2));
}
