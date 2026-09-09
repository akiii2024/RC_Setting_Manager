// Browser regression test. Requires Playwright and its Chromium browser.
// PLAYWRIGHT_MODULE_PATH can point to an existing Playwright installation.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {indexUrl, loaders} from './firebase_csp.mjs';

const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_MODULE_PATH || 'playwright');
const csp = readFileSync(indexUrl, 'utf8')
    .match(/http-equiv="Content-Security-Policy" content="([^"]+)"/)[1];
const browser = await chromium.launch({
  headless: true,
  channel: process.env.PLAYWRIGHT_CHANNEL || undefined,
});
try {
  for (const fixed of [false, true]) {
    const page = await browser.newPage();
    const policy = fixed ? csp : csp.replace(/ 'sha256-[^']+'/g, '');
    await page.route('https://www.gstatic.com/firebasejs/**', (route) =>
      route.fulfill({contentType: 'text/javascript',
        headers: {'Access-Control-Allow-Origin': '*'},
        body: 'export const loaded = true;'}));
    await page.route('https://csp-test.invalid/', (route) => route.fulfill({
      contentType: 'text/html',
      body: `<meta http-equiv="Content-Security-Policy" content="${policy}">`,
    }));
    await page.goto('https://csp-test.invalid/');
    for (const body of loaders) {
      const result = await page.evaluate(async (text) => {
        const trigger = text.match(/window\.(ff_trigger_\w+)/)[1];
        delete window[trigger];
        const script = document.createElement('script');
        script.type = 'text/javascript';
        script.text = text;
        document.head.appendChild(script);
        if (typeof window[trigger] !== 'function') return 'loader-blocked';
        return new Promise((resolve) => {
          window[trigger]((module) => resolve(module.loaded ? 'loaded' : 'failed'));
        });
      }, body);
      assert.equal(result, fixed ? 'loaded' : 'loader-blocked');
    }
    // The fix must still block arbitrary inline JavaScript.
    assert.equal(await page.evaluate(() => {
      const script = document.createElement('script');
      script.text = 'window.unapprovedScriptRan = true;';
      document.head.appendChild(script);
      return window.unapprovedScriptRan === true;
    }), false);
    console.log(`${fixed ? 'Fixed' : 'Original'} CSP: ${loaders.length} SDK loader cases passed; arbitrary inline script blocked.`);
    await page.close();
  }
} finally {
  await browser.close();
}
