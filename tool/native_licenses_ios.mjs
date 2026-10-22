import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

// Run on macOS after pod install, before flutter build ipa.
const root = new URL('../', import.meta.url);
const decode = (value) => value.replace(/&(lt|gt|quot|apos|amp|#\d+|#x[0-9a-fA-F]+);/g, (_, entity) => {
  if (entity.startsWith('#x')) return String.fromCodePoint(parseInt(entity.slice(2), 16));
  if (entity.startsWith('#')) return String.fromCodePoint(parseInt(entity.slice(1), 10));
  return {lt: '<', gt: '>', quot: '"', apos: "'", amp: '&'}[entity];
});
const field = (dict, key) => decode(dict.match(new RegExp(`<key>${key}</key>\\s*<string>([\\s\\S]*?)</string>`))?.[1] ?? '');
export function parseAcknowledgements(plist) {
  assert.match(plist, /<plist\b/, 'Use an XML CocoaPods acknowledgements plist');
  // CocoaPods emits flat dictionaries inside PreferenceSpecifiers.
  const sections = [...plist.matchAll(/<dict>([\s\S]*?)<\/dict>/g)]
    .map((match) => ({title: field(match[1], 'Title'), text: field(match[1], 'FooterText')}))
    .filter((entry) => entry.text.trim());
  assert.ok(sections.length > 1, 'No dependency acknowledgements found; inspect the CocoaPods output');
  return sections;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const source = process.argv[2] ?? new URL('ios/Pods/Target Support Files/Pods-Runner/Pods-Runner-acknowledgements.plist', root);
  const sections = parseAcknowledgements(readFileSync(source, 'utf8'));
  const lock = readFileSync(new URL('ios/Podfile.lock', root), 'utf8');
  const output = ['Apple native SDK acknowledgements', 'Source: CocoaPods generated acknowledgements; retain LICENSE/NOTICE files not included by podspecs separately.',
    'Resolved Podfile.lock:', lock, ...sections.map((entry) => `===== ${entry.title} =====\n${entry.text}`)].join('\n\n');
  writeFileSync(new URL('assets/licenses/ios_native.txt', root), `${output}\n`);
  console.log(`Apple native: ${sections.length} acknowledgement sections written.`);
}
