const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const model = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../Model.js'), 'utf8')
  .replace(/^\.pragma library\s*/, ''), model);
const plain = value => JSON.parse(JSON.stringify(value));

test('creation age uses human units and handles missing or future timestamps', () => {
  const now = Date.parse('2026-10-24T12:00:00Z');
  const age = seconds => model.createdAgo(new Date(now - seconds * 1000).toISOString(), now);
  assert.equal(age(0), 'Created just now');
  assert.equal(age(59), 'Created just now');
  assert.equal(age(60), 'Created 1 minute ago');
  assert.equal(age(120), 'Created 2 minutes ago');
  assert.equal(age(3600), 'Created 1 hour ago');
  assert.equal(age(7200), 'Created 2 hours ago');
  assert.equal(age(86400), 'Created 1 day ago');
  assert.equal(age(86400 * 10), 'Created 10 days ago');
  assert.equal(age(-60), 'Created just now');
  assert.equal(model.createdAgo('', now), '');
  assert.equal(model.createdAgo('invalid date', now), '');
});

test('management requires explicit administration access and allowlisted verbs', () => {
  for (const access of [undefined, {}, {admin: false}, {admin: 'true'}]) {
    const record = model.normalizeVm({vm_name: 'demo', access});
    assert.equal(record.adminAllowed, false);
    assert.throws(() => model.managementCommand(record, 'restart'), /not allowed/);
  }
  const record = model.normalizeVm({vm_name: 'demo', access: {admin: true}});
  for (const action of ['restart', 'pause', 'resume', 'copy']) {
    const command = plain(model.managementCommand(record, action));
    assert.deepEqual(command.slice(-4), ['exe.dev', action === 'copy' ? 'cp' : action, 'demo', '--json']);
    assert.deepEqual(command.slice(0, 4), ['timeout', '--kill-after=2s', '120s', 'ssh']);
    assert.ok(command.includes('BatchMode=yes'));
    assert.ok(command.includes('StrictHostKeyChecking=yes'));
  }
  for (const action of ['rm', 'delete', 'restart;evil', 'cp', '', null]) {
    assert.throws(() => model.managementCommand(record, action), /Unsupported/);
  }
  for (const name of ['-option', 'demo;evil', 'demo name', 'demo\nevil']) {
    assert.throws(() => model.managementCommand({name, adminAllowed: true}, 'copy'), /Invalid VM name/);
  }
});

test('REPL opens a new terminal with the stock floating app-id and fixed SSH host', () => {
  assert.deepEqual(plain(model.replCommand()), [
    'omarchy-launch-terminal', '--app-id=org.omarchy.terminal',
    '--title=exe.dev', 'ssh', 'exe.dev',
  ]);
});
