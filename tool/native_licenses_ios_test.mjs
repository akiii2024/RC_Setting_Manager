import assert from 'node:assert/strict';
import {test} from 'node:test';
import {parseAcknowledgements} from './native_licenses_ios.mjs';

test('preserves CocoaPods license text and XML entities without double decoding', () => {
  const plist = `<?xml version="1.0"?><plist version="1.0"><dict>
    <key>PreferenceSpecifiers</key><array>
    <dict><key>Title</key><string>Acknowledgements</string></dict>
    <dict><key>Title</key><string>SDK A</string><key>FooterText</key><string>Copyright A &amp; B\n&lt;notice&gt; &#169; &amp;lt;</string></dict>
    <dict><key>Title</key><string>SDK B</string><key>FooterText</key><string>Permission is granted.\nAS IS.</string></dict>
    </array></dict></plist>`;
  assert.deepEqual(parseAcknowledgements(plist), [
    {title: 'SDK A', text: 'Copyright A & B\n<notice> © &lt;'},
    {title: 'SDK B', text: 'Permission is granted.\nAS IS.'},
  ]);
});

test('rejects binary or empty acknowledgements instead of publishing empty notices', () => {
  assert.throws(() => parseAcknowledgements('bplist00'));
  assert.throws(() => parseAcknowledgements('<plist><dict></dict></plist>'));
});
