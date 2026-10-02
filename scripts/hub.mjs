// A local BendHub that serves this repository's packages during development
// and qualification. It answers the requests that the pinned compiler's
// `--publish` and `link` and its loader make of https://hub.bend-lang.com
// (bend2/main.ts and bend2/bend.ts at the release commit), so that a package
// of the working tree is published, named and imported as a release would
// be, without publishing anything:
//   GET  /pow.json                   a proof of work that any nonce meets,
//                                    where BendHub asks for real work
//   POST /                           {files, nonce}: store a package, answer
//                                    its hash
//   GET  /publish-check?name&version whether the name is free or taken, and
//                                    whether the version is new
//   POST /register                   {name}: take a free name
//   POST /link                       {name, version, hash}: name a package
//   GET  /0x<hash>/manifest          the package's "sha256 path" lines
//   GET  /0x<hash>/<path>            one of its files
//   GET  /name/<name>@<version>      the hash that a link names
// Any bearer key is a login here. A package's hash is the one the compiler
// computes: the first 32 digits of the SHA-256 of its manifest. Every other
// GET goes to the real hub, for the packages that the working tree imports,
// such as bend-trace-context. HUB_STORE is the directory that keeps the
// packages, the names and the links; the hub listens on HUB_PORT, or on a
// free port when it is 0, and prints its URL. scripts/local-hub.sh starts it.
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname, join, normalize } from 'node:path';

const port = Number(process.env.HUB_PORT ?? 0);
const store = process.env.HUB_STORE;
if (!store) throw new Error('Set HUB_STORE to the directory of the local hub.');
const upstream = 'https://hub.bend-lang.com';
for (const directory of ['names', 'links']) mkdirSync(join(store, directory), { recursive: true });

const sha256 = (text) => createHash('sha256').update(text).digest('hex');
const NAME = /^[a-z][a-z0-9-]{0,63}$/;
const VERSION = /^(?:0|[1-9][0-9]*)(?:\.(?:0|[1-9][0-9]*)){3}$/;

// The manifest of a package's files, as the compiler hashes it.
function manifest(files) {
  return Object.keys(files).sort().map((path) => `${sha256(files[path])} ${path}\n`).join('');
}

function send(response, status, body, type = 'text/plain') {
  response.writeHead(status, { 'content-type': type }).end(body);
}

const json = (response, status, value) => send(response, status, JSON.stringify(value), 'application/json');

async function relay(url, response) {
  try {
    const answer = await fetch(upstream + url, { headers: { 'user-agent': 'bend-telemetry local hub' } });
    send(response, answer.status, Buffer.from(await answer.arrayBuffer()),
      answer.headers.get('content-type') ?? 'application/octet-stream');
  } catch {
    send(response, 502, 'the real hub could not be reached');
  }
}

function body(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch (error) {
        reject(error);
      }
    });
  });
}

function publish(files) {
  const listed = manifest(files);
  const hash = `0x${sha256(listed).slice(0, 32)}`;
  for (const [path, text] of Object.entries(files)) {
    const at = join(store, hash, normalize(path));
    if (!at.startsWith(join(store, hash) + '/')) throw new Error(`a path outside the package: ${path}`);
    mkdirSync(dirname(at), { recursive: true });
    writeFileSync(at, text);
  }
  writeFileSync(join(store, hash, 'manifest'), listed);
  return hash;
}

const keyed = (request) => /^Bearer \S+$/.test(request.headers.authorization ?? '');

createServer(async (request, response) => {
  const url = new URL(request.url, 'http://127.0.0.1');
  try {
    if (request.method === 'POST') {
      const value = await body(request);
      if (url.pathname === '/') {
        send(response, 200, publish(value.files));
      } else if (!keyed(request)) {
        json(response, 401, { ok: false, reason: 'no login' });
      } else if (url.pathname === '/register' && NAME.test(value.name ?? '')) {
        if (existsSync(join(store, 'names', value.name))) {
          json(response, 409, { ok: false, reason: `${value.name} is taken` });
        } else {
          writeFileSync(join(store, 'names', value.name), 'local\n');
          json(response, 200, { ok: true });
        }
      } else if (url.pathname === '/link' && NAME.test(value.name ?? '') && VERSION.test(value.version ?? '')) {
        const link = join(store, 'links', `${value.name}@${value.version}`);
        if (!existsSync(join(store, 'names', value.name)) || existsSync(link)
          || !existsSync(join(store, String(value.hash), 'manifest'))) {
          json(response, 409, { ok: false, reason: 'the name is not yours, the version exists or the package does not' });
        } else {
          writeFileSync(link, `${value.hash}\n`);
          json(response, 200, { ok: true });
        }
      } else {
        json(response, 400, { ok: false, reason: 'a malformed request' });
      }
      return;
    }
    if (request.method !== 'GET') {
      send(response, 405, 'only GET and POST');
      return;
    }
    if (url.pathname === '/pow.json') {
      json(response, 200, { pow: 1 });
      return;
    }
    if (url.pathname === '/publish-check') {
      const name = url.searchParams.get('name') ?? '';
      const version = url.searchParams.get('version') ?? '';
      if (!keyed(request)) {
        json(response, 401, { ok: false, reason: 'no login' });
      } else if (!NAME.test(name) || !VERSION.test(version)) {
        json(response, 400, { ok: false, reason: 'a malformed name or version' });
      } else {
        json(response, 200, {
          name: existsSync(join(store, 'names', name)) ? 'yours' : 'free',
          version_ok: !existsSync(join(store, 'links', `${name}@${version}`)),
        });
      }
      return;
    }
    const named = /^\/name\/([a-z][a-z0-9-]{0,63}@[0-9.]+)$/.exec(url.pathname);
    if (named !== null && existsSync(join(store, 'links', named[1]))) {
      send(response, 200, readFileSync(join(store, 'links', named[1]), 'utf8').trim());
      return;
    }
    const file = /^\/(0x[0-9a-f]{32})\/(.+)$/.exec(url.pathname);
    if (file !== null && existsSync(join(store, file[1], 'manifest'))) {
      const at = join(store, file[1], normalize(file[2]));
      if (at.startsWith(join(store, file[1]) + '/') && existsSync(at)) {
        send(response, 200, readFileSync(at));
      } else {
        send(response, 404, 'no such file');
      }
      return;
    }
    await relay(url.pathname + url.search, response);
  } catch (error) {
    send(response, 400, String(error));
  }
}).listen(port, '127.0.0.1', function listening() {
  console.log(`http://127.0.0.1:${this.address().port}`);
});
