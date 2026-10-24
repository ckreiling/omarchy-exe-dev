const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const manifest = JSON.parse(read('manifest.json'));

test('manifest declares a complete, installable bar widget', () => {
  assert.equal(manifest.schemaVersion, 1);
  for (const key of ['id', 'name', 'version', 'author', 'description', 'license']) {
    assert.equal(typeof manifest[key], 'string', key);
    assert.ok(manifest[key].trim(), key);
  }
  assert.match(manifest.id, /^[a-z0-9][a-z0-9._-]*$/);
  assert.ok(!manifest.id.startsWith('omarchy.') && !manifest.id.includes('..'));
  assert.equal(manifest.id, 'cmk.exe-dev');
  assert.match(manifest.version, /^\d+\.\d+\.\d+$/);
  assert.deepEqual(manifest.kinds, ['bar-widget']);
  assert.equal(manifest.license, 'MIT');
  assert.ok(['left', 'center', 'right'].includes(manifest.barWidget.defaultSection));
  assert.equal(manifest.barWidget.allowMultiple, false);
  assert.equal(typeof manifest.entryPoints.barWidget, 'string');
  for (const entry of Object.values(manifest.entryPoints)) {
    assert.ok(entry && !path.isAbsolute(entry) && !entry.includes('..'));
    assert.ok(!entry.includes('\n') && !entry.includes('\\'));
    assert.ok(fs.statSync(path.join(root, entry)).isFile());
  }
  const widget = read(manifest.entryPoints.barWidget);
  assert.ok(widget.includes('moduleName: "' + manifest.id + '"'));
  assert.ok(widget.includes('ipcTarget: "' + manifest.id + '"'));
  assert.ok(widget.includes('VmNavigation {'));
  assert.ok(read('VmNavigation.qml').includes('Model.listRows(filteredVms, query)'));
  assert.equal(manifest.barWidget.defaults.clickAction, 'ssh');
  const clickSetting = manifest.barWidget.schema.find(field => field.key === 'clickAction');
  assert.equal(clickSetting.type, 'enum');
  assert.deepEqual(clickSetting.options, ['ssh', 'browser', 'details']);
  assert.equal(clickSetting.defaultValue, 'ssh');
});

test('plugin tree contains no symlinks outside Git internals', () => {
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
      if (entry.name === '.git') continue;
      assert.ok(!entry.isSymbolicLink(), path.relative(root, path.join(dir, entry.name)));
      if (entry.isDirectory()) walk(path.join(dir, entry.name));
    }
  }
  walk(root);
});

test('release documentation and local links exist', () => {
  const readme = read('README.md');
  assert.ok(readme.includes('omarchy plugin add https://github.com/ckreiling/omarchy-exe-dev.git --enable'));
  assert.ok(readme.includes('omarchy plugin update ' + manifest.id));
  assert.ok(readme.includes('omarchy plugin remove ' + manifest.id));
  assert.ok(!readme.includes('install.sh'));
  assert.match(read('LICENSE'), /MIT License/);
  assert.ok(read('CHANGELOG.md').includes('## ' + manifest.version));
  for (const match of readme.matchAll(/\]\(([A-Z][A-Z_.]*\.md|LICENSE)\)/g)) {
    assert.ok(fs.statSync(path.join(root, match[1])).isFile(), match[1]);
  }
});

test('CI uses immutable actions without privileged PR execution', () => {
  const workflow = read('.github/workflows/ci.yml');
  assert.ok(workflow.includes('contents: read'));
  assert.ok(workflow.includes('persist-credentials: false'));
  assert.ok(!workflow.includes('pull_request_target'));
  assert.ok(!/secrets\s*[.[]/.test(workflow));
  assert.ok(!/:\s*write\b/.test(workflow));
  const actions = [...workflow.matchAll(/uses:\s*([^\s#]+)/g)];
  assert.ok(actions.length > 0);
  for (const [, action] of actions) assert.match(action, /^[\w.-]+\/[\w.-]+@[a-f0-9]{40}$/);
});
