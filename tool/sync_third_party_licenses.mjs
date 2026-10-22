import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

// Run after flutter pub get. --check detects stale notices without changing files.
// Canonicalize only CRLF: retain all license wording and other whitespace.
const licenseText = (url) => readFileSync(url, 'utf8').replaceAll('\r\n', '\n');

export function syncThirdPartyLicenses(root = new URL('../', import.meta.url), {check = false} = {}) {
  const configUrl = new URL('.dart_tool/package_config.json', root);
  const config = JSON.parse(readFileSync(configUrl, 'utf8'));
  const graph = JSON.parse(readFileSync(new URL('.dart_tool/package_graph.json', root), 'utf8'));
  const sources = [];
  for (const name of ['image', 'archive']) {
    const pkg = config.packages.find((entry) => entry.name === name);
    const resolvedPackage = graph.packages.find((entry) => entry.name === name);
    assert.ok(pkg && resolvedPackage, `Run flutter pub get first: ${name}`);
    const source = new URL('LICENSE-other.md', new URL(pkg.rootUri.endsWith('/') ? pkg.rootUri : `${pkg.rootUri}/`, configUrl));
    const content = licenseText(source);
    assert.ok(content.length > 0, `Empty license: ${name}`);
    const asset = `assets/licenses/${name}-LICENSE-other.md`;
    if (check) {
      assert.equal(content, licenseText(new URL(asset, root)), `Stale ${asset}; run node tool/sync_third_party_licenses.mjs`);
    } else {
      mkdirSync(fileURLToPath(new URL('assets/licenses/', root)), {recursive: true});
      writeFileSync(new URL(asset, root), content, 'utf8');
    }
    sources.push({package: name, version: resolvedPackage.version, file: 'LICENSE-other.md',
      source: `https://pub.dev/packages/${name}/versions/${resolvedPackage.version}`,
      asset, sha256: createHash('sha256').update(content, 'utf8').digest('hex')});
  }
  const manifestUrl = new URL('assets/licenses/sources.json', root);
  if (check) {
    assert.deepEqual(JSON.parse(readFileSync(manifestUrl, 'utf8')), sources,
      'License source versions or content hashes changed; regenerate supplemental notices');
  } else {
    writeFileSync(manifestUrl, `${JSON.stringify(sources, null, 2)}\n`, 'utf8');
  }
  return sources;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const check = process.argv.includes('--check');
  const sources = syncThirdPartyLicenses(undefined, {check});
  console.log(`追加ライセンス: ${sources.map((entry) => `${entry.package} ${entry.version}`).join(', ')} ${check ? '照合済み' : '同期済み'}`);
}
