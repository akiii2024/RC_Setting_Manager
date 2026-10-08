import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

// Verify the actual Pages artifact, including assets referenced by metadata.
const directory = resolve(process.argv[2] ?? 'build/web');
const read = (path) => readFileSync(resolve(directory, path));
const html = read('index.html').toString('utf8');
const meta = (attribute, name) => {
  const tag = html.match(new RegExp(`<meta\\s+${attribute}="${name}"\\s+content="([^"]+)"`));
  assert.ok(tag, `Missing metadata: ${name}`);
  return tag[1];
};
const name = 'RC Setting Manager';
const publicUrl = new URL('https://akiii2024.github.io/RC_Setting_Manager/');
assert.match(html, /<base href="\/RC_Setting_Manager\/">/);
assert.match(html, /<title>RC Setting Manager<\/title>/);
assert.equal(meta('name', 'application-name'), name);
assert.equal(meta('name', 'apple-mobile-web-app-title'), name);
assert.equal(meta('property', 'og:title'), name);
assert.equal(meta('property', 'og:type'), 'website');
assert.equal(meta('property', 'og:url'), publicUrl.href);
assert.ok(meta('name', 'description').includes('テレメトリー'));
assert.equal(meta('name', 'description'), meta('property', 'og:description'));

const imageUrl = new URL(meta('property', 'og:image'));
assert.equal(imageUrl.origin, publicUrl.origin);
assert.ok(imageUrl.pathname.startsWith(publicUrl.pathname));
const icon = read(imageUrl.pathname.slice(publicUrl.pathname.length));
assert.equal(icon.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
assert.equal(icon.readUInt32BE(16), Number(meta('property', 'og:image:width')));
assert.equal(icon.readUInt32BE(20), Number(meta('property', 'og:image:height')));

const manifest = JSON.parse(read('manifest.json'));
assert.equal(manifest.name, name);
assert.equal(manifest.short_name, name);
assert.equal(manifest.theme_color, meta('name', 'theme-color'));
for (const icon of manifest.icons) read(icon.src);

const policy = read('privacy.html').toString('utf8');
assert.match(policy, /<html lang="ja">/);
assert.match(policy, /<title>Privacy Policy \| RC Setting Manager<\/title>/);
assert.match(policy, /href="\.\/"/);
assert.doesNotMatch(policy, /<script\b/i);
assert.match(policy, /https:\/\/github.com\/akiii2024\/RC_Setting_Manager\/issues/);

const bundledPubspec = read('assets/pubspec.yaml').toString('utf8');
const sourcePubspec = readFileSync(new URL('../pubspec.yaml', import.meta.url), 'utf8');
const version = (text) => text.match(/^version:\s*(\S+)/m)?.[1];
assert.ok(version(sourcePubspec));
assert.equal(version(bundledPubspec), version(sourcePubspec));
console.log('公開Web成果物: metadata、OGP画像、Privacy Policy、バージョンアセットを確認しました。');
