// Run after flutter pub get: node tool/firebase_csp.mjs [--check]
// Permit only the exact FlutterFire SDK loader bodies, including both the
// Trusted Types and Safari branches. Never enable unsafe-inline for scripts.
import {createHash} from 'node:crypto';
import {readdirSync, readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const root = new URL('../', import.meta.url);
const configUrl = new URL('.dart_tool/package_config.json', root);
const packages = JSON.parse(readFileSync(configUrl, 'utf8')).packages;
const core = packages.find((p) => p.name === 'firebase_core_web');
if (!core) throw new Error('Run flutter pub get first.');
const coreRoot = new URL(core.rootUri.replace(/\/?$/, '/'), configUrl);
const readCore = (path) => readFileSync(new URL(path, coreRoot), 'utf8')
    .replaceAll('\r\n', '\n');
const source = readCore('lib/src/firebase_core_web.dart');
const version = readCore('lib/src/firebase_sdk_version.dart')
    .match(/supportedFirebaseJsSdkVersion = '([^']+)'/)[1];
const loaderSource = source.slice(source.indexOf('Future<void> injectSrcScript('),
    source.indexOf('Future<void> _initializeCore('));
// Dart multiline strings omit the first newline after the opening delimiter.
const templates = [...loaderSource.matchAll(/'''\n([\s\S]*?)'''/g)]
    .map((m) => m[1]);
if (templates.length !== 2 || templates.some((s) =>
  !s.includes('callback(await import("$stringUrl"))'))) {
  throw new Error('FlutterFire loader changed; review CSP generation.');
}

const readDartSources = (directory) => readdirSync(directory, {
  withFileTypes: true,
}).flatMap((entry) => {
  const path = new URL(entry.name + (entry.isDirectory() ? '/' : ''), directory);
  if (entry.isDirectory()) return readDartSources(path);
  return entry.isFile() && entry.name.endsWith('.dart')
    ? [readFileSync(path, 'utf8')]
    : [];
});

const services = [{name: 'app', variable: 'core'}];
for (const pkg of packages.filter((p) => p.name.endsWith('_web') &&
    /^(firebase_|cloud_)/.test(p.name) && p.name !== 'firebase_core_web')) {
  const pkgRoot = new URL(pkg.rootUri.replace(/\/?$/, '/'), configUrl);
  for (const source of readDartSources(new URL('lib/', pkgRoot))) {
    for (const match of source.matchAll(
        /FirebaseCoreWeb\.registerService\(\s*'([^']+)'(?:,\s*productNameOverride:\s*'([^']+)')?/g)) {
      services.push({name: match[1], variable: match[2] ?? match[1]});
    }
  }
}
export const loaders = services.flatMap(({name, variable}) => {
  const module = name === 'firestore' ? 'firestore-pipelines' : name;
  const url = `https://www.gstatic.com/firebasejs/${version}/firebase-${module}.js`;
  return templates.map((body) => body
      .replaceAll('$windowVar', `firebase_${variable}`)
      .replaceAll('$stringUrl', url));
});
const hashes = [...new Set(loaders.map((body) =>
  `'sha256-${createHash('sha256').update(body).digest('base64')}'`))].sort();

export const indexUrl = new URL('web/index.html', root);
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const html = readFileSync(indexUrl, 'utf8');
  const directive = html.match(/script-src [^;]+;/)?.[0];
  if (!directive || directive.includes("'unsafe-inline'")) {
    throw new Error('Missing or unsafe script-src directive.');
  }
  const connectDirective = html.match(/connect-src [^;]+;/)?.[0];
  if (!connectDirective?.split(/\s+/).includes('blob:')) {
    throw new Error('connect-src must allow blob: for web image bytes.');
  }
  // All script-src SHA-256 hashes in this app are managed by this generator.
  const base = directive.replace(/ 'sha256-[^']+'/g, '').slice(0, -1);
  const updated = html.replace(directive, `${base} ${hashes.join(' ')};`);
  if (process.argv.includes('--check')) {
    if (updated !== html) {
      throw new Error('Firebase CSP is stale. Run node tool/firebase_csp.mjs.');
    }
    console.log(`Firebase ${version}: ${hashes.length} CSP hashes verified.`);
  } else {
    writeFileSync(indexUrl, updated);
    console.log(`Firebase ${version}: wrote ${hashes.length} CSP hashes.`);
  }
}
