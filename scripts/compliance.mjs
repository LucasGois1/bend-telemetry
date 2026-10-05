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
// starts on the next line. Every scalar is text, `true` included, and a key
// with no value holds null. Anything else, such as a tab, a flow collection,
// an anchor, a tag, a block scalar, a double-quoted scalar, a plain scalar
// holding ': ' or ' #', or a repeated key, is an error that names the file
// and the line.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const ISSUES = 'https://github.com/LucasGois1/bend-telemetry/issues/';
const SPECIFICATION = 'https://github.com/open-telemetry/opentelemetry-specification';
const USAGE = 'Usage: node scripts/compliance.mjs REVISION TEMPLATE STATUS OUTPUT';

// The line on which each mapping that parseYaml answers starts.
const lineOf = new WeakMap();

// A key and the text after it, if any, on a line of a mapping.
const KEY = /^([A-Za-z_]\w*):(?: (.*))?$/;

// The position of the quote that closes a single-quoted text, or -1: a
// doubled quote is a quote of the text.
function closingQuote(text) {
  for (let at = 0; at < text.length; at += 1) {
    if (text[at] === "'" && text[at + 1] === "'") at += 1;
    else if (text[at] === "'") return at;
  }
  return -1;
}

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
      if (part.includes(': ') || part.includes(' #') || part.endsWith(':')) {
        fail(start + at, "a plain value cannot hold ': ', ' #' or a final ':'; quote it with single quotes");
      }
    });
    return parts.join(' ');
  }

  // The key on the current line, a line of a mapping whose keys are indented
  // by `indent`, and the text after it.
  function keyAt(indent) {
    const match = KEY.exec(lines[index].slice(indent));
    if (!match) fail(index, 'is not a key with its value; a list is indented below its key');
    return { key: match[1], rest: (match[2] ?? '').trim() };
  }

  // The keys and values of a mapping whose keys are indented by `indent`.
  function mapping(indent) {
    const result = {};
    lineOf.set(result, index + 1);
    for (;;) {
      skipBlank();
      if (index >= lines.length || indentOf(lines[index]) < indent) return result;
      if (indentOf(lines[index]) > indent) fail(index, 'is indented more than the keys before it');
      const { key, rest } = keyAt(indent);
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

// A heading as plain text: its emphasis dropped, and each link replaced by
// its text.
const plain = (text) => text.replaceAll('**', '').replace(/\[([^[\]]*)\]\([^()]*\)/g, '$1');

// A row's place in the matrix, for messages: its section, its heading as
// plain text if it has one, and its name.
const labelOf = ({ section, heading, name }) => [section, heading === null ? null : plain(heading), name]
  .filter((part) => part !== null).join(' > ');

const identityOf = ({ section, heading, name }) => JSON.stringify([section, heading, name]);

// The reading of a matrix file: the file's name, the keys allowed at each
// level when the file is the status file, the problems found, and the rows
// read so far.
const readerOf = (file, problems, keys) => ({ file, problems, keys, rows: [] });

// A mapping of the file at a level, `file`, `section`, `heading` or `row`,
// whose keys the reader checks when it has keys to allow.
function checkKeys(reader, value, level) {
  const unknown = reader.keys ? Object.keys(value).filter((key) => !reader.keys[level].includes(key)) : [];
  if (unknown.length > 0) {
    reader.problems.push(`${placeOf(reader.file, value)}: has the key ${unknown[0]}; `
      + `a ${level} has the keys ${reader.keys[level].join(', ')}`);
  }
}

// A row of a section, under a heading or null, added to the rows and to the
// section's items.
function readRow(reader, section, heading, row, items) {
  if (!isMapping(row) || typeof row.name !== 'string') {
    reader.problems.push(`${placeOf(reader.file, row)}: a row of ${section} has a name`);
    return;
  }
  checkKeys(reader, row, 'row');
  const entry = { kind: 'row', section, heading, name: row.name, row };
  reader.rows.push(entry);
  items.push(entry);
}

// A feature of a section: a row, or a heading with its rows.
function readFeature(reader, section, feature, items) {
  if (!isMapping(feature) || !Object.hasOwn(feature, 'features')) {
    readRow(reader, section, null, feature, items);
  } else if (typeof feature.heading !== 'string' || !Array.isArray(feature.features)) {
    reader.problems.push(`${placeOf(reader.file, feature)}: a heading of ${section} has a text and a list of features`);
  } else {
    checkKeys(reader, feature, 'heading');
    items.push({ kind: 'heading', text: feature.heading });
    for (const row of feature.features) readRow(reader, section, feature.heading, row, items);
  }
}

// A parsed matrix file, a template or a status file: its rows in order, each
// with its section, its heading (null for a row outside a heading), its name
// and its mapping; and its sections, each with its headings and rows in
// order, for rendering. `keys`, when given, lists the keys allowed at each
// level. The problems go to `problems`.
function matrixOf(document, file, problems, keys) {
  const reader = readerOf(file, problems, keys);
  const sections = [];
  if (!isMapping(document) || !Array.isArray(document.sections)) {
    problems.push(`${file}: is not a mapping with a list of sections`);
    return { rows: reader.rows, sections };
  }
  checkKeys(reader, document, 'file');
  for (const section of document.sections) {
    if (!isMapping(section) || typeof section.name !== 'string' || !Array.isArray(section.features)) {
      problems.push(`${placeOf(file, section)}: a section has a name and a list of features`);
      continue;
    }
    checkKeys(reader, section, 'section');
    const items = [];
    sections.push({ name: section.name, hideOptional: section.hide_optional_column === 'true', items });
    for (const feature of section.features) readFeature(reader, section.name, feature, items);
  }
  return { rows: reader.rows, sections };
}

// The keys of this project that a row may hold, in alphabetical order.
const PROJECT_KEYS = ['note', 'partial', 'reason', 'ticket'];

// The keys that the status file allows at each level.
const STATUS_KEYS = {
  file: ['specification', 'sections'],
  section: ['name', 'features'],
  heading: ['heading', 'features'],
  row: ['name', 'status', ...PROJECT_KEYS],
};

// For each status of the specification's legend, the classification of a
// row by the keys of this project it holds, in the order of PROJECT_KEYS and
// joined by spaces, and the problem of a row that holds other keys.
const LEGEND = {
  '+': {
    byKeys: { '': 'implemented', note: 'implemented' },
    problem: "is implemented ('+'): it takes an optional note, and no ticket, partial or reason",
  },
  '-': {
    byKeys: { ticket: 'pending', 'partial ticket': 'partial', reason: 'not applicable' },
    problem: "is not implemented ('-'): it takes its ticket, with a partial when part of the row holds, "
      + 'or the reason it does not apply',
  },
  'N/A': {
    byKeys: { reason: 'not applicable' },
    problem: "does not apply ('N/A'): it takes the reason, and no ticket, partial or note",
  },
};

// The problem of a row's values, or '' when they hold: a note, a partial and
// a reason are texts, and a ticket is an issue number.
function valuesProblem(row) {
  const empty = ['note', 'partial', 'reason'].find((key) => Object.hasOwn(row, key)
    && (typeof row[key] !== 'string' || row[key] === ''));
  if (empty) return `its ${empty} is not a text`;
  if (Object.hasOwn(row, 'ticket') && !/^[1-9]\d*$/.test(String(row.ticket))) {
    return `its ticket ${row.ticket} is not an issue number`;
  }
  return '';
}

// The classification of a row of the status file for COMPLIANCE.md,
// `{ status, ticket, text }`, or `{ problem }`.
function classify(row) {
  const legend = Object.hasOwn(LEGEND, row.status) ? LEGEND[row.status] : undefined;
  if (legend === undefined) {
    return {
      problem: row.status === undefined || row.status === null ? 'has no status'
        : `has the status '${row.status}', which is not one of '+', '-' and 'N/A'`,
    };
  }
  const keys = PROJECT_KEYS.filter((key) => Object.hasOwn(row, key)).join(' ');
  const status = Object.hasOwn(legend.byKeys, keys) ? legend.byKeys[keys] : undefined;
  if (status === undefined) return { problem: legend.problem };
  const problem = valuesProblem(row);
  if (problem) return { problem };
  return { status, ticket: row.ticket, text: row.note ?? row.partial ?? row.reason };
}

// The rows of a matrix file by identity; a row listed twice is a problem.
function rowsByIdentity(rows, file, problems) {
  const map = new Map();
  for (const entry of rows) {
    const identity = identityOf(entry);
    if (map.has(identity)) problems.push(`${placeOf(file, entry.row)}: lists the row ${labelOf(entry)} twice`);
    map.set(identity, entry);
  }
  return map;
}

// The status file lists the rows of the template, each once, in the
// template's order, and no other; each difference is a problem.
function checkRows(template, templateFile, status, statusFile, problems) {
  const before = problems.length;
  const templateRows = rowsByIdentity(template.rows, templateFile, problems);
  const statusRows = rowsByIdentity(status.rows, statusFile, problems);
  for (const [identity, entry] of templateRows) {
    if (!statusRows.has(identity)) {
      problems.push(`${statusFile} does not classify the row ${labelOf(entry)} of the template`);
    }
  }
  for (const [identity, entry] of statusRows) {
    if (!templateRows.has(identity)) {
      problems.push(`${placeOf(statusFile, entry.row)}: classifies the row ${labelOf(entry)}, `
        + 'which the template does not have');
    }
  }
  if (problems.length > before) return;
  const at = status.rows.findIndex((entry, position) => identityOf(entry) !== identityOf(template.rows[position]));
  if (at >= 0) {
    problems.push(`${placeOf(statusFile, status.rows[at].row)}: lists the row ${labelOf(status.rows[at])} `
      + `where the template has ${labelOf(template.rows[at])}; keep the template's order`);
  }
}

// The classification of each row of the status file, by the row's identity,
// once the status file classifies the rows of the template. The problems go
// to `problems`.
function classifyAll(template, templateFile, status, statusFile, problems) {
  checkRows(template, templateFile, status, statusFile, problems);
  const classified = new Map();
  for (const entry of status.rows) {
    const result = classify(entry.row);
    if (result.problem) problems.push(`${placeOf(statusFile, entry.row)}: ${labelOf(entry)}: ${result.problem}`);
    else classified.set(identityOf(entry), result);
  }
  return classified;
}

const STATUSES = ['implemented', 'partial', 'pending', 'not applicable'];

// A text in a table cell.
const cell = (text) => (text ?? '').replaceAll('|', String.raw`\|`);

// The template's text, its links into the specification's repository made
// absolute at the revision.
const fromTemplate = (text, revision) =>
  text.replace(/\]\((?!https?:\/\/|#)(?:\.\/)?([^)]*)\)/g, `](${SPECIFICATION}/blob/${revision}/$1)`);

// A note of the status file, its references to this project's issues, such
// as (#12), linked; a reference into another repository, such as
// bendlang/bend#1162, is left as it is.
const fromStatus = (text) => text.replace(/(^|[^\w/&#[])#([1-9]\d*)\b/g, `$1[#$2](${ISSUES}$2)`);

const countsOf = (entries, classified) =>
  STATUSES.map((name) => entries.filter((entry) => classified.get(identityOf(entry)).status === name).length);

// The specification's Optional mark of a template row: X when the row is
// optional, * when at least one row of its group is required, or the
// condition that the template gives.
function optionalMark(row) {
  if (row.optional === 'true') return 'X';
  if (row.optional_one_of_group_is_required === 'true') return '*';
  if (typeof row.optional === 'string' && row.optional !== 'false') return row.optional;
  return '';
}

// The opening of COMPLIANCE.md: what it is, the legend and the summary's
// header.
function introduction(revision) {
  const matrix = `${SPECIFICATION}/blob/${revision}/spec-compliance-matrix.md`;
  return [
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
}

// The line of a heading in a section's table of `columns` columns: the
// heading in bold, and empty cells.
function headingLine(text, columns, revision) {
  const heading = fromTemplate(text, revision);
  const bold = heading.startsWith('**') && heading.endsWith('**') ? heading : `**${heading}**`;
  return `| ${[cell(bold), ...columns.slice(1).map(() => '')].join(' | ')} |`;
}

// The line of a row in a section's table: its name, its Optional mark when
// the section shows the column, its status, its ticket and its note.
function rowLine(item, optional, revision, classified) {
  const { status, ticket, text } = classified.get(identityOf(item));
  const mark = optional ? [cell(optionalMark(item.row))] : [];
  const link = ticket ? `[#${ticket}](${ISSUES}${ticket})` : '';
  const note = text === undefined ? '' : cell(fromStatus(text));
  return `| ${[cell(fromTemplate(item.name, revision)), ...mark, status, link, note].join(' | ')} |`;
}

// The table of a section: a line for each heading and each row.
function sectionTable(section, revision, classified) {
  const optional = !section.hideOptional;
  const columns = ['Feature', ...(optional ? ['Optional'] : []), 'Status', 'Ticket', 'Note'];
  const lines = ['', `## ${section.name}`, '', `| ${columns.join(' | ')} |`,
    `| ${columns.map(() => '---').join(' | ')} |`];
  for (const item of section.items) {
    if (item.kind === 'heading') lines.push(headingLine(item.text, columns, revision));
    else lines.push(rowLine(item, optional, revision, classified));
  }
  return lines;
}

// COMPLIANCE.md: the introduction and legend, the counts of each section and
// a table per section of the template.
function render(revision, template, classified) {
  const lines = introduction(revision);
  for (const section of template.sections) {
    const rows = section.items.filter((item) => item.kind === 'row');
    lines.push(`| ${section.name} | ${countsOf(rows, classified).join(' | ')} |`);
  }
  lines.push(`| All | ${countsOf(template.rows, classified).join(' | ')} |`);
  for (const section of template.sections) lines.push(...sectionTable(section, revision, classified));
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
