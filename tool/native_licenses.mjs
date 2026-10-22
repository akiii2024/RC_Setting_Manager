import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdirSync, readFileSync, writeFileSync, existsSync} from 'node:fs';

const root = new URL('../', import.meta.url);
const input = new URL('build/native-licenses/artifacts.json', root);
const records = JSON.parse(readFileSync(input, 'utf8'));
const cache = new URL('build/native-licenses/downloads/', root);
mkdirSync(cache, {recursive: true});
const decode = (text) => text.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'");
const tag = (xml, name) => decode(xml?.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`))?.[1]?.trim() ?? '');
const readLicenses = (pom) => [...(pom?.match(/<licenses>([\s\S]*?)<\/licenses>/)?.[1] ?? '').matchAll(/<license>([\s\S]*?)<\/license>/g)]
  .map((match) => ({name: tag(match[1], 'name'), url: tag(match[1], 'url')}));
async function download(url) {
  const destination = new URL(`${createHash('sha256').update(url).digest('hex')}.txt`, cache);
  if (existsSync(destination)) return readFileSync(destination, 'utf8');
  const response = await fetch(url, {signal: AbortSignal.timeout(30000)});
  assert.ok(response.ok, `${response.status}: ${url}`);
  const body = await response.text();
  assert.ok(body.trim(), `Empty response: ${url}`);
  writeFileSync(destination, body);
  return body;
}
async function licenseMetadata(pom, depth = 0) {
  const licenses = readLicenses(pom);
  if (licenses.length || depth > 5) return licenses;
  const parent = pom?.match(/<parent>([\s\S]*?)<\/parent>/)?.[1];
  if (!parent) return [];
  const group = tag(parent, 'groupId'), name = tag(parent, 'artifactId'), version = tag(parent, 'version');
  assert.ok(group && name && version && !version.includes('${'), 'Unresolved parent POM');
  const url = `https://repo.maven.apache.org/maven2/${group.replaceAll('.', '/')}/${name}/${version}/${name}-${version}.pom`;
  return licenseMetadata(await download(url), depth + 1);
}

const sections = [
  'Android native SDK licenses and notices',
  'Source: resolved releaseRuntimeClasspath POM metadata and embedded LICENSE / NOTICE / COPYING files.',
  'Flutter engine notices are provided separately by Flutter NOTICES.',
  'POM declarations do not prove that every upstream source notice is embedded in a binary. See docs/NATIVE_LICENSES.md for scope.',
];
const manifest = [];
const seen = new Set();
for (const record of records) {
  const key = `${record.coordinate}/${record.artifact}`;
  if (seen.has(key)) continue;
  seen.add(key);
  const licenses = await licenseMetadata(record.pom);
  const flutter = record.coordinate.startsWith('io.flutter:');
  assert.ok(licenses.length || flutter || record.notices.length, `No license information: ${record.coordinate}`);
  for (const license of licenses) {
    assert.match(license.name, /Apache|Android Software Development Kit|Play (Core|Integrity)|BSD-3-Clause|MIT|Go License/i,
      `Review newly introduced license: ${record.coordinate} (${license.name})`);
  }
  sections.push(`\n===== ${record.coordinate} (${record.artifact}) =====`,
    ...licenses.map((license) => `${license.name}\n${license.url}`));
  if (flutter) sections.push('License and third-party notices: Flutter NOTICES, included with this application.');
  for (const comment of record.pom?.matchAll(/<!--([\s\S]*?)-->/g) ?? []) {
    if (/copyright|\blicen[sc]e\b/i.test(comment[1])) {
      sections.push(`\n--- License notice in published POM ---\n${comment[1]}`);
    }
  }
  for (const notice of record.notices) {
    sections.push(`\n--- Embedded file: ${notice.path} ---\n${notice.text}`);
  }
  manifest.push({coordinate: record.coordinate, artifact: record.artifact, licenses,
    embeddedNotices: record.notices.map((notice) => ({path: notice.path, sha256: createHash('sha256').update(notice.text).digest('hex')}))});
}
sections.push('\n===== Apache License 2.0: full text for the components declared above =====',
  readFileSync(new URL('assets/licenses/Apache-2.0.txt', root), 'utf8'));
const supplemental = [
  ['Protocol Buffers v25.5 (protobuf-javalite 3.25.5)', 'https://raw.githubusercontent.com/protocolbuffers/protobuf/v25.5/LICENSE'],
  ['RE2/J 1.6', 'https://raw.githubusercontent.com/google/re2j/re2j-1.6/LICENSE'],
  ['Reactive Streams 1.0.4', 'https://raw.githubusercontent.com/reactive-streams/reactive-streams-jvm/v1.0.4/LICENSE'],
];
for (const expected of ['com.google.protobuf:protobuf-javalite:3.25.5', 'com.google.re2j:re2j:1.6', 'org.reactivestreams:reactive-streams:1.0.4']) {
  assert.ok(records.some((record) => record.coordinate === expected), `Review supplemental source versions: ${expected}`);
}
for (const [name, url] of supplemental) {
  sections.push(`\n===== ${name} =====\nSource: ${url}\n${await download(url)}`);
}
const output = new URL('assets/licenses/android_native.txt', root);
writeFileSync(output, `${sections.join('\n\n')}\n`);
writeFileSync(new URL('assets/licenses/android_native_sources.json', root), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Android native: ${manifest.length} resolved artifacts, metadata + embedded notices + supplemental license texts written.`);
