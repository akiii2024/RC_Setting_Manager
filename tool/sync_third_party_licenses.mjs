import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

// Run after flutter pub get. --check detects stale notices without changing files.
const root = new URL('../', import.meta.url);
const configUrl = new URL('.dart_tool/package_config.json', root);
const config = JSON.parse(readFileSync(configUrl, 'utf8'));
const graph = JSON.parse(readFileSync(new URL('.dart_tool/package_graph.json', root), 'utf8'));
const check = process.argv.includes('--check');
const sources = [];
for (const name of ['image', 'archive']) {
  const pkg = config.packages.find((entry) => entry.name === name);
  const resolved = graph.packages.find((entry) => entry.name === name);
  assert.ok(pkg && resolved, `Run flutter pub get first: ${name}`);
  const source = new URL('LICENSE-other.md', new URL(pkg.rootUri.endsWith('/') ? pkg.rootUri : `${pkg.rootUri}/`, configUrl));
  const content = readFileSync(source);
  assert.ok(content.length > 0, `Empty license: ${name}`);
  const asset = `assets/licenses/${name}-LICENSE-other.md`;
  if (check) {
    assert.ok(content.equals(readFileSync(new URL(asset, root))), `Stale ${asset}; run node tool/sync_third_party_licenses.mjs`);
  } else {
    mkdirSync(fileURLToPath(new URL('assets/licenses/', root)), {recursive: true});
    writeFileSync(new URL(asset, root), content);
  }
  sources.push({package: name, version: resolved.version, file: 'LICENSE-other.md',
    source: `https://pub.dev/packages/${name}/versions/${resolved.version}`,
    asset, sha256: createHash('sha256').update(content).digest('hex')});
}
const manifest = `${JSON.stringify(sources, null, 2)}\n`;
const manifestUrl = new URL('assets/licenses/sources.json', root);
if (check) {
  assert.equal(readFileSync(manifestUrl, 'utf8'), manifest, 'License source versions changed; regenerate supplemental notices');
} else {
  writeFileSync(manifestUrl, manifest);
}
console.log(`追加ライセンス: ${sources.map((entry) => `${entry.package} ${entry.version}`).join(', ')} ${check ? '照合済み' : '同期済み'}`);
