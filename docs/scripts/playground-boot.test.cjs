const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const web = path.resolve(__dirname, '../../playground/web');
const html = readFileSync(path.join(web, 'index.html'), 'utf8');
const bootstrap = readFileSync(path.join(web, 'flutter_bootstrap.js'), 'utf8')
  .replace(/\{\{flutter_js\}\}|\{\{flutter_build_config\}\}/g, '');

test('engine host starts empty so engine initialization cannot remove recovery UI', () => {
  const host = html.match(/<div id="flutter-host">([\s\S]*?)<\/div>/);
  assert.ok(host, 'An embedded engine host is required');
  assert.equal(host[1].trim(), '', 'Keep the boot card outside the engine-owned host');
  assert.match(html, /position:\s*fixed/);
  // The loader ignores hostElement in this Flutter version and appends
  // <flutter-view> to <body>; without this rule the app covers the nav.
  assert.match(html, /flutter-view\s*\{[^}]*top:\s*48px/);
});

test('engine startup failure and timeout retain the recovery message and navigation', async () => {
  let loadOptions;
  let timeout;
  const classes = [];
  const boot = {classList: {add: value => classes.push(value)}};
  const status = {textContent: ''};
  const host = {};
  const context = {
    document: {getElementById: id => ({boot, 'boot-status': status, 'flutter-host': host})[id]},
    window: {
      addEventListener() {},
      setTimeout(callback) { timeout = callback; return 1; },
      clearTimeout() {},
    },
    _flutter: {loader: {load(options) {
      loadOptions = options;
      return Promise.resolve().then(() => options.onEntrypointLoaded({
        initializeEngine: async () => { throw new Error('Engine initialization failed'); },
      }));
    }}},
  };
  vm.runInNewContext(bootstrap, context);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(loadOptions.config.hostElement, host);
  assert.match(status.textContent, /failed to start/);
  assert.ok(classes.includes('boot-error'));
  timeout();
  assert.match(status.textContent, /longer than expected/);
  assert.match(html, /<nav[^>]*aria-label="Project"/);
  assert.match(html, /href="\/docs\/"/);
});
