// The compliance status of bend-telemetry against the compliance matrix of
// the OpenTelemetry specification (#51). scripts/compliance.sh runs it after
// checking the template's pin:
//
//   node scripts/compliance.mjs REVISION TEMPLATE STATUS OUTPUT
//
// TEMPLATE is the specification's spec-compliance-matrix/template.yaml at
// REVISION, such as v1.61.0, and STATUS is this project's status file,
// qualification/compliance/bend.yaml, in the schema of the specification's
// language files: the template's sections, headings and rows, each row with
// its `status`. The status file names REVISION under `specification` and
// classifies every row of the template, in the template's order, and no
// other. Beside the specification's `status`, each row carries the keys of
// this project that say what COMPLIANCE.md shows, keys that the
// specification's own generator ignores:
//
//   implemented     '+', with an optional `note`
//   partial         '-', with `partial`, what exists of the row, and
//                   `ticket`, the issue that implements the rest
//   pending         '-', with `ticket`, the issue that implements the row
//   not applicable  `reason`, why the row does not apply to this project,
//                   with 'N/A' when its subject does not exist in this
//                   design, or '-' when a specification of this project
//                   decided against it
//
// When both files hold, it writes COMPLIANCE.md's text to OUTPUT and prints a
// PASS line with the count of each status; otherwise it prints a FAIL line
// for each problem, writes nothing and exits with 1. A usage error exits with
// 2.
//
// The YAML it reads is the subset that the specification's matrix files use:
// block mappings with plain keys; block sequences indented below their key,
// whose items are scalars or mappings; plain scalars, which may continue on
// lines indented below their key; single-quoted scalars, which may span lines
// the same way; and comments on lines of their own or after a key whose value
// starts on the next line. `true` and `false` are Booleans, a key with no
// value holds null, and every other scalar is text. Anything else, such as a
// tab, a flow collection, an anchor, a tag, a block scalar, a double-quoted
// scalar, a plain scalar holding ': ' or ' #', or a repeated key, is an error
// that names the file and the line.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const ISSUES = 'https://github.com/LucasGois1/bend-telemetry/issues/';
const SPECIFICATION = 'https://github.com/open-telemetry/opentelemetry-specification';
const USAGE = 'Usage: node scripts/compliance.mjs REVISION TEMPLATE STATUS OUTPUT';

// The line on which each mapping that parseYaml answers starts.
const lineOf = new WeakMap();

const KEY = /^([A-Za-z_][A-Za-z0-9_]*):(?: +(.*))?$/;

// The value of a YAML text of the subset above; `file` names it in errors.
function parseYaml(text, file) {
  const lines = (text.endsWith('\n') ? text.slice(0, -1) : text).split('\n');
  const fail = (index, message) => {
    throw new Error(`${file}:${index + 1}: ${message}`);
  };
  lines.forEach((line, index) => {
    if (/[\t\r]/.test(line)) fail(index, 'holds a tab or a carriage return');
  });
  const indentOf = (line) => line.length - line.trimStart().length;
  const isBlank = (line) => /^ *(#.*)?$/.test(line);
  let index = 0;
  const skipBlank = () => {
    while (index < lines.length && isBlank(lines[index])) index += 1;
  };

  // The position of the quote that closes a single-quoted text, or -1: a
  // doubled quote is a quote of the text.
  function closingQuote(text) {
    for (let at = 0; at < text.length; at += 1) {
      if (text[at] === "'" && text[at + 1] === "'") at += 1;
      else if (text[at] === "'") return at;
    }
    return -1;
  }

  // A single-quoted scalar whose text after the opening quote is `rest`, on
  // the current line; it continues on lines indented more than `parent`, and
  // each line break folds into a space.
  function quoted(rest, parent) {
    const start = index;
    const pieces = [];
    for (let text = rest; ; text = lines[index].trim()) {
      const close = closingQuote(text);
      if (close >= 0) {
        if (text.slice(close + 1).trim() !== '') fail(index, 'holds text after the closing quote');
        pieces.push(text.slice(0, close));
        index += 1;
        const last = pieces.length - 1;
        return pieces.map((piece, at) => (at === 0 ? piece : piece.trimStart()))
          .map((piece, at) => (at === last ? piece : piece.trimEnd()))
          .join(' ').replaceAll("''", "'");
      }
      pieces.push(text);
      index += 1;
      if (index >= lines.length || lines[index].trim() === '' || indentOf(lines[index]) <= parent) {
        fail(start, 'opens a quote that does not close before a blank or a less indented line');
      }
    }
  }

  // A scalar whose text starts with `first`, on the current line, and
  // continues on the lines indented more than `parent`.
  function scalar(first, parent) {
    if (first.startsWith("'")) return quoted(first.slice(1), parent);
    if (first.startsWith('"')) fail(index, 'holds a double-quoted value; quote it with single quotes');
    if (/^[[\]{}&*!|>%@`#]/.test(first) || /^[-?:]( |$)/.test(first)) {
      fail(index, `a plain value cannot start with ${first[0]}; quote it with single quotes`);
    }
    const start = index;
    const parts = [first];
    index += 1;
    while (index < lines.length && !isBlank(lines[index]) && indentOf(lines[index]) > parent) {
      parts.push(lines[index].trim());
      index += 1;
    }
    parts.forEach((part, at) => {
      if (/: | #|:$/.test(part)) {
        fail(start + at, "a plain value cannot hold ': ', ' #' or a final ':'; quote it with single quotes");
      }
    });
    const value = parts.join(' ');
    return value === 'true' || value === 'false' ? value === 'true' : value;
  }

  // The keys and values of a mapping whose keys are indented by `indent`.
  function mapping(indent) {
    const result = {};
    lineOf.set(result, index + 1);
    for (;;) {
      skipBlank();
      if (index >= lines.length || indentOf(lines[index]) < indent) return result;
      if (indentOf(lines[index]) > indent) fail(index, 'is indented more than the keys before it');
      const match = KEY.exec(lines[index].slice(indent));
      if (!match) fail(index, 'is not a key with its value; a list is indented below its key');
      const [, key, rest = ''] = match;
      if (Object.hasOwn(result, key)) fail(index, `repeats the key ${key}`);
      if (rest === '' || rest.startsWith('#')) {
        index += 1;
        result[key] = block(indent);
      } else {
        result[key] = scalar(rest, indent);
      }
    }
  }

  // The items of a sequence whose dashes are indented by `indent`.
  function sequence(indent) {
    const result = [];
    for (;;) {
      skipBlank();
      if (index >= lines.length || indentOf(lines[index]) < indent) return result;
      const line = lines[index];
      if (indentOf(line) > indent) fail(index, 'is indented more than the items before it');
      if (!line.slice(indent).startsWith('- ')) fail(index, 'is not an item of the list above it');
      const item = line.slice(indent + 2).trimStart();
      if (item === '' || item.startsWith('#')) fail(index, 'is an empty item');
      if (KEY.test(item)) {
        // A mapping whose first key follows the dash: its keys are indented
        // as that first key.
        lines[index] = ' '.repeat(line.length - item.length) + item;
        result.push(mapping(line.length - item.length));
      } else {
        result.push(scalar(item, indent));
      }
    }
  }

  // The value that starts on the next significant line, when that line is
  // indented more than `parent`; null otherwise.
  function block(parent) {
    skipBlank();
    if (index >= lines.length || indentOf(lines[index]) <= parent) return null;
    const indent = indentOf(lines[index]);
    const content = lines[index].slice(indent);
    if (content.startsWith('- ')) return sequence(indent);
    if (KEY.test(content)) return mapping(indent);
    return scalar(content, parent);
  }

  const root = block(-1);
  skipBlank();
  if (index < lines.length) fail(index, 'is not part of the document above it');
  return root;
}

const isMapping = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

// A file and the line where a mapping of it starts, for messages.
const placeOf = (file, value) => (isMapping(value) && lineOf.has(value) ? `${file}:${lineOf.get(value)}` : file);

// A heading as plain text: its links and emphasis dropped.
const plain = (text) => text.replaceAll('**', '').replace(/\[([^\]]*)\]\([^)]*\)/g, '$1');

// A row's place in the matrix, for messages: its section, its heading as
// plain text if it has one, and its name.
const labelOf = ({ section, heading, name }) => [section, heading === null ? null : plain(heading), name]
  .filter((part) => part !== null).join(' > ');

const identityOf = ({ section, heading, name }) => JSON.stringify([section, heading, name]);

// A parsed matrix file, a template or a status file: its rows in order, each
// with its section, its heading (null for a row outside a heading), its name
// and its mapping; and its sections, each with its headings and rows in
// order, for rendering. `keys`, when given, lists the keys allowed at each
// level. The problems go to `problems`.
function matrixOf(document, file, problems, keys) {
  const rows = [];
  const sections = [];
  const allowed = (value, level) => {
    const unknown = keys ? Object.keys(value).filter((key) => !keys[level].includes(key)) : [];
    if (unknown.length > 0) {
      problems.push(`${placeOf(file, value)}: has the key ${unknown[0]}; `
        + `a ${level} has the keys ${keys[level].join(', ')}`);
    }
  };
  if (!isMapping(document) || !Array.isArray(document.sections)) {
    problems.push(`${file}: is not a mapping with a list of sections`);
    return { rows, sections };
  }
  allowed(document, 'file');
  const addRow = (section, heading, row, items) => {
    if (!isMapping(row) || typeof row.name !== 'string') {
      problems.push(`${placeOf(file, row)}: a row of ${section} has a name`);
      return;
    }
    allowed(row, 'row');
    const entry = { kind: 'row', section, heading, name: row.name, row };
    rows.push(entry);
    items.push(entry);
  };
  for (const section of document.sections) {
    if (!isMapping(section) || typeof section.name !== 'string' || !Array.isArray(section.features)) {
      problems.push(`${placeOf(file, section)}: a section has a name and a list of features`);
      continue;
    }
    allowed(section, 'section');
    const items = [];
    sections.push({ name: section.name, hideOptional: section.hide_optional_column === true, items });
    for (const feature of section.features) {
      if (isMapping(feature) && Object.hasOwn(feature, 'features')) {
        if (typeof feature.heading !== 'string' || !Array.isArray(feature.features)) {
          problems.push(`${placeOf(file, feature)}: a heading of ${section.name} has a text and a list of features`);
          continue;
        }
        allowed(feature, 'heading');
        items.push({ kind: 'heading', text: feature.heading });
        for (const row of feature.features) addRow(section.name, feature.heading, row, items);
      } else {
        addRow(section.name, null, feature, items);
      }
    }
  }
  return { rows, sections };
}

const STATUS_KEYS = {
  file: ['specification', 'sections'],
  section: ['name', 'features'],
  heading: ['heading', 'features'],
  row: ['name', 'status', 'note', 'partial', 'ticket', 'reason'],
};

// The classification of a row of the status file, `{ status, ticket, text }`
// for COMPLIANCE.md, or the text of its problem.
function classify(row) {
  const has = (key) => Object.hasOwn(row, key);
  const holdsOnly = (...keys) => Object.keys(row).every((key) => ['name', 'status', ...keys].includes(key));
  for (const key of ['note', 'partial', 'reason']) {
    if (has(key) && (typeof row[key] !== 'string' || row[key] === '')) return `its ${key} is not a text`;
  }
  if (has('ticket') && !/^[1-9][0-9]*$/.test(String(row.ticket))) {
    return `its ticket ${row.ticket} is not an issue number`;
  }
  switch (row.status) {
    case '+':
      if (!holdsOnly('note')) return "is implemented ('+'): it takes a note, and no ticket, partial or reason";
      return { status: 'implemented', text: row.note };
    case 'N/A':
      if (!has('reason')) return "does not apply ('N/A') and gives no reason";
      if (!holdsOnly('reason')) return "does not apply ('N/A'): it takes a reason, and no ticket, partial or note";
      return { status: 'not applicable', text: row.reason };
    case '-':
      if (has('reason')) {
        if (!holdsOnly('reason')) return "does not apply ('-' with a reason): it takes no ticket, partial or note";
        return { status: 'not applicable', text: row.reason };
      }
      if (!has('ticket')) {
        return "is not implemented ('-') and names neither its ticket nor the reason it does not apply";
      }
      if (!holdsOnly('ticket', 'partial')) return "is not implemented ('-'): it takes a ticket and a partial, and no note";
      if (has('partial')) return { status: 'partial', ticket: row.ticket, text: row.partial };
      return { status: 'pending', ticket: row.ticket };
    case undefined:
    case null:
      return 'has no status';
    default:
      return `has the status '${row.status}', which is not one of '+', '-' and 'N/A'`;
  }
}

// The classification of each row of the status file, by the row's identity;
// the status file must classify the rows of the template, each once, in the
// template's order, and no other. The problems go to `problems`.
function classifyAll(template, templateFile, status, statusFile, problems) {
  let matches = template.rows.length === status.rows.length;
  const byIdentity = (rows, file) => {
    const map = new Map();
    for (const entry of rows) {
      const identity = identityOf(entry);
      if (map.has(identity)) {
        problems.push(`${placeOf(file, entry.row)}: lists the row ${labelOf(entry)} twice`);
        matches = false;
      }
      map.set(identity, entry);
    }
    return map;
  };
  const templateRows = byIdentity(template.rows, templateFile);
  const statusRows = byIdentity(status.rows, statusFile);
  for (const [identity, entry] of templateRows) {
    if (!statusRows.has(identity)) {
      problems.push(`${statusFile} does not classify the row ${labelOf(entry)} of the template`);
      matches = false;
    }
  }
  for (const [identity, entry] of statusRows) {
    if (!templateRows.has(identity)) {
      problems.push(`${placeOf(statusFile, entry.row)}: classifies the row ${labelOf(entry)}, `
        + 'which the template does not have');
      matches = false;
    }
  }
  if (matches) {
    const at = status.rows.findIndex((entry, position) => identityOf(entry) !== identityOf(template.rows[position]));
    if (at >= 0) {
      problems.push(`${placeOf(statusFile, status.rows[at].row)}: lists the row ${labelOf(status.rows[at])} `
        + `where the template has ${labelOf(template.rows[at])}; keep the template's order`);
    }
  }
  const classified = new Map();
  for (const [identity, entry] of statusRows) {
    const result = classify(entry.row);
    if (typeof result === 'string') problems.push(`${placeOf(statusFile, entry.row)}: ${labelOf(entry)}: ${result}`);
    else classified.set(identity, result);
  }
  return classified;
}

const STATUSES = ['implemented', 'partial', 'pending', 'not applicable'];

// A text in a table cell.
const cell = (text) => (text ?? '').replaceAll('|', '\\|');

// The template's text, its links into the specification's repository made
// absolute at the revision.
const fromTemplate = (text, revision) =>
  text.replace(/\]\((?!https?:\/\/|#)(?:\.\/)?([^)]*)\)/g, `](${SPECIFICATION}/blob/${revision}/$1)`);

// A note of the status file, its references to this project's issues, such
// as (#12), linked; a reference into another repository, such as
// bendlang/bend#1162, is left as it is.
const fromStatus = (text) => text.replace(/(^|[^\w/&#[])#([1-9][0-9]*)\b/g, `$1[#$2](${ISSUES}$2)`);

const countsOf = (entries, classified) =>
  STATUSES.map((name) => entries.filter((entry) => classified.get(identityOf(entry)).status === name).length);

// COMPLIANCE.md: the legend, the counts of each section and a table per
// section of the template.
function render(revision, template, classified) {
  const matrix = `${SPECIFICATION}/blob/${revision}/spec-compliance-matrix.md`;
  const lines = [
    '# Compliance',
    '',
    '<!-- Generated by ./scripts/compliance.sh from qualification/compliance/bend.yaml: edit that file and regenerate'
      + ' this one. -->',
    '',
    'For every row of the compliance matrix of the OpenTelemetry specification',
    `[${revision}](${matrix}), this file says whether bend-telemetry`,
    'implements it, implements part of it, has it pending with the ticket that',
    'implements it, or does not apply and why. The matrix is a list of features,',
    'not a conformance suite; the [qualification harness](qualification/README.md)',
    'checks what reaches a collector and a backend. This is a community project;',
    'it is not part of, or endorsed by, the OpenTelemetry project.',
    '',
    'The statuses live in',
    '[qualification/compliance/bend.yaml](qualification/compliance/bend.yaml), in',
    "the schema of the specification's own matrix files, and",
    '`./scripts/compliance.sh` generates this file from them;',
    '[CONTRIBUTING.md](CONTRIBUTING.md#compliance) says when they change.',
    '',
    '| Status | Meaning |',
    '| --- | --- |',
    '| implemented | The row holds. |',
    '| partial | Part of the row holds: the note says which, and the ticket implements the rest. |',
    '| pending | The row does not hold yet: the ticket implements it. |',
    '| not applicable | The row does not apply to this project: the note says why. |',
    '',
    "The Optional column is the specification's: `X` marks an optional row, `*` a",
    'row of a group of which at least one is required, and a blank a required',
    'row.',
    '',
    '## Summary',
    '',
    '| Section | Implemented | Partial | Pending | Not applicable |',
    '| --- | --- | --- | --- | --- |',
  ];
  for (const section of template.sections) {
    const rows = section.items.filter((item) => item.kind === 'row');
    lines.push(`| ${section.name} | ${countsOf(rows, classified).join(' | ')} |`);
  }
  lines.push(`| All | ${countsOf(template.rows, classified).join(' | ')} |`);
  for (const section of template.sections) {
    const optional = !section.hideOptional;
    const columns = ['Feature', ...(optional ? ['Optional'] : []), 'Status', 'Ticket', 'Note'];
    lines.push('', `## ${section.name}`, '', `| ${columns.join(' | ')} |`,
      `| ${columns.map(() => '---').join(' | ')} |`);
    for (const item of section.items) {
      if (item.kind === 'heading') {
        const heading = fromTemplate(item.text, revision);
        const bold = heading.startsWith('**') && heading.endsWith('**') ? heading : `**${heading}**`;
        lines.push(`| ${[cell(bold), ...columns.slice(1).map(() => '')].join(' | ')} |`);
        continue;
      }
      const { status, ticket, text } = classified.get(identityOf(item));
      const marker = item.row.optional === true ? 'X'
        : item.row.optional_one_of_group_is_required === true ? '*'
          : typeof item.row.optional === 'string' ? item.row.optional : '';
      const link = ticket ? `[#${ticket}](${ISSUES}${ticket})` : '';
      lines.push(`| ${[cell(fromTemplate(item.name, revision)), ...(optional ? [cell(marker)] : []), status, link,
        cell(text === undefined ? '' : fromStatus(text))].join(' | ')} |`);
    }
  }
  return `${lines.join('\n')}\n`;
}

function load(file, problems) {
  try {
    return parseYaml(readFileSync(file, 'utf8'), file);
  } catch (error) {
    problems.push(error.code ? `${file}: cannot be read (${error.code})` : error.message);
    return undefined;
  }
}

function main(argv) {
  if (argv.length !== 4) {
    console.error(USAGE);
    return 2;
  }
  const [revision, templateFile, statusFile, output] = argv;
  const problems = [];
  const templateDocument = load(templateFile, problems);
  const statusDocument = load(statusFile, problems);
  if (templateDocument !== undefined && statusDocument !== undefined) {
    const template = matrixOf(templateDocument, templateFile, problems);
    const status = matrixOf(statusDocument, statusFile, problems, STATUS_KEYS);
    if (isMapping(statusDocument) && statusDocument.specification !== revision) {
      problems.push(`${statusFile} names the specification ${statusDocument.specification ?? 'nowhere'}; `
        + `the pinned template is that of ${revision}`);
    }
    const classified = classifyAll(template, templateFile, status, statusFile, problems);
    if (problems.length === 0) {
      mkdirSync(dirname(output), { recursive: true });
      writeFileSync(output, render(revision, template, classified));
      const counts = countsOf(template.rows, classified).map((count, at) => `${count} ${STATUSES[at]}`);
      console.log(`PASS: ${statusFile} classifies the ${template.rows.length} rows of the compliance matrix of the `
        + `OpenTelemetry specification ${revision}: ${counts.join(', ')}`);
      return 0;
    }
  }
  for (const problem of problems) console.error(`FAIL: ${problem}`);
  return 1;
}

process.exitCode = main(process.argv.slice(2));
