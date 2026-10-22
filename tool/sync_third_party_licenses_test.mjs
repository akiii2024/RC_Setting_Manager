import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {basename, dirname, join} from 'node:path';
import {pathToFileURL} from 'node:url';
import test from 'node:test';

import {syncThirdPartyLicenses} from './sync_third_party_licenses.mjs';

const packages = [
  ['image', '1.2.3'],
  ['archive', '4.5.6'],
];
const licenseText = 'Copyright 2026 Fixture Authors.\n\nLicense terms.\n';

function removeFixture(root) {
  const target = realpathSync(root);
  assert.equal(dirname(target), realpathSync(tmpdir()));
  assert.match(basename(target), /^sync-third-party-licenses-[a-zA-Z0-9]+$/);
  rmSync(target, {recursive: true, force: true});
}

function writeFixture(cacheEol, bundledEol) {
  const root = mkdtempSync(join(tmpdir(), 'sync-third-party-licenses-'));
  mkdirSync(join(root, '.dart_tool'), {recursive: true});
  for (const [name] of packages) {
    mkdirSync(join(root, 'cache', name), {recursive: true});
    writeFileSync(
      join(root, 'cache', name, 'LICENSE-other.md'),
      licenseText.replaceAll('\n', cacheEol),
    );
  }
  const packageConfig = {
    configVersion: 2,
    packages: packages.map(([name]) => ({
      name,
      rootUri: `../cache/${name}/`,
      packageUri: 'lib/',
      languageVersion: '3.0',
    })),
  };
  const packageGraph = {
    packages: packages.map(([name, version]) => ({name, version})),
  };
  writeFileSync(
    join(root, '.dart_tool', 'package_config.json'),
    JSON.stringify(packageConfig),
  );
  writeFileSync(
    join(root, '.dart_tool', 'package_graph.json'),
    JSON.stringify(packageGraph),
  );
  mkdirSync(join(root, 'assets', 'licenses'), {recursive: true});
  for (const [name] of packages) {
    writeFileSync(
      join(root, 'assets', 'licenses', `${name}-LICENSE-other.md`),
      licenseText.replaceAll('\n', bundledEol),
    );
  }
  return root;
}

function rootUrl(root) {
  return pathToFileURL(
    `${root}${root.endsWith('\\') || root.endsWith('/') ? '' : '/'}`,
  ).toString();
}

function runFixture(cacheEol, bundledEol) {
  const root = writeFixture(cacheEol, bundledEol);
  try {
    const sources = syncThirdPartyLicenses(rootUrl(root));
    assert.equal(sources.length, 2);
    for (const source of sources) {
      assert.equal(source.sha256, createHash('sha256').update(licenseText).digest('hex'));
    }
    const output = packages.map(([name]) =>
      readFileSync(join(root, 'assets', 'licenses', `${name}-LICENSE-other.md`)),
    );
    const manifest = readFileSync(
      join(root, 'assets', 'licenses', 'sources.json'),
      'utf8',
    );
    assert.equal(manifest, `${JSON.stringify(sources, null, 2)}\n`);
    assert.deepEqual(output, [Buffer.from(licenseText), Buffer.from(licenseText)]);
    // Emulate Git checkout rewriting the bundle/manifest after generation.
    for (const [name] of packages) {
      writeFileSync(join(root, 'assets', 'licenses', `${name}-LICENSE-other.md`),
        licenseText.replaceAll('\n', bundledEol));
    }
    writeFileSync(join(root, 'assets', 'licenses', 'sources.json'), manifest.replaceAll('\n', bundledEol));
    assert.deepEqual(syncThirdPartyLicenses(rootUrl(root), {check: true}), sources);
    return {root, output, manifest};
  } catch (error) {
    removeFixture(root);
    throw error;
  }
}

test('sync and check normalize cache and bundled CRLF/LF combinations', () => {
  const lf = runFixture('\n', '\n');
  const crlfCache = runFixture('\r\n', '\n');
  const crlfBundled = runFixture('\n', '\r\n');
  try {
    assert.deepEqual(crlfCache.output, lf.output);
    assert.deepEqual(crlfBundled.output, lf.output);
    assert.equal(crlfCache.manifest, lf.manifest);
    assert.equal(crlfBundled.manifest, lf.manifest);
  } finally {
    for (const fixture of [lf, crlfCache, crlfBundled]) {
      removeFixture(fixture.root);
    }
  }
});

test('check rejects modified license text', () => {
  const root = writeFixture('\r\n', '\n');
  try {
    syncThirdPartyLicenses(rootUrl(root));
    writeFileSync(
      join(root, 'assets', 'licenses', 'image-LICENSE-other.md'),
      'Copyright 2026 Changed Authors.\n\nLicense terms.\n',
    );
    assert.throws(
      () => syncThirdPartyLicenses(rootUrl(root), {check: true}),
      /Stale assets\/licenses\/image-LICENSE-other\.md/,
    );
  } finally {
    removeFixture(root);
  }
});

test('check rejects manifest version or hash changes', () => {
  for (const mutate of [
    (manifest) => manifest.replace('"version": "1.2.3"', '"version": "9.9.9"'),
    (manifest) => manifest.replace(/"sha256": "[^"]+"/, '"sha256": "deadbeef"'),
  ]) {
    const root = writeFixture('\n', '\r\n');
    try {
      syncThirdPartyLicenses(rootUrl(root));
      const manifestPath = join(root, 'assets', 'licenses', 'sources.json');
      writeFileSync(manifestPath, mutate(readFileSync(manifestPath, 'utf8')));
      assert.throws(
        () => syncThirdPartyLicenses(rootUrl(root), {check: true}),
        /License source versions or content hashes changed/,
      );
    } finally {
      removeFixture(root);
    }
  }
});
