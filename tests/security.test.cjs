const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const model = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../Model.js'), 'utf8')
  .replace(/^\.pragma library\s*/, ''), model);
const plain = value => JSON.parse(JSON.stringify(value));

test('normalization accepts direct and username-routed destinations', () => {
  const direct = model.normalizeVm({vm_name: 'demo-vm'});
  assert.equal(direct.sshDest, 'demo-vm.exe.xyz');
  assert.equal(direct.url, 'https://demo-vm.exe.xyz/');
  const routed = model.normalizeVm({
    vm_name: 'demo-vm', ssh_dest: 'user+demo@demo-vm.exe.xyz',
    tags: ['work', '', null], access: {shell: false, web: false},
    ssh_command: 'untrusted command that must never be evaluated',
  });
  assert.equal(routed.sshDest, 'user+demo@demo-vm.exe.xyz');
  assert.deepEqual(plain(routed.tags), ['work']);
  assert.equal(routed.shellAllowed, false);
  assert.equal(routed.webAllowed, false);
});

test('invalid VM names cannot reach a launch command', () => {
  for (const name of ['', '-oProxyCommand=x', 'bad;touch-x', 'bad/name',
    'bad name', 'bad\nname', 'bad.exe.xyz', 'https://demo', 'UPPER', 'a'.repeat(64)]) {
    assert.throws(() => model.normalizeVm({vm_name: name}), /Invalid VM name/);
    assert.throws(() => model.browserCommand({name}), /Invalid VM name/);
    assert.throws(() => model.sshCommand({name, sshDest: 'demo.exe.xyz'}), /Invalid VM name/);
  }
  assert.equal(model.normalizeVm({vm_name: 'a'.repeat(63)}).name.length, 63);
});

test('SSH destinations reject options, shell syntax, ports and external hosts', () => {
  for (const dest of ['', '-oProxyCommand=evil', 'demo.exe.xyz;evil',
    'demo.exe.xyz evil', 'demo.exe.xyz\nevil', 'demo.exe.xyz:22',
    'ssh://demo.exe.xyz', 'demo.example.org', 'demo.exe.xyz.evil.org',
    'user@evil.org', 'user@demo.exe.xyz/command', '$(evil).exe.xyz']) {
    assert.throws(() => model.normalizeVm({vm_name: 'demo', ssh_dest: dest}),
      /Invalid SSH destination/);
    assert.throws(() => model.sshCommand({name: 'demo', sshDest: dest}),
      /Invalid SSH destination/);
  }
});

test('launch arguments are canonical arrays, not server-supplied commands or URLs', () => {
  const record = model.normalizeVm({
    vm_name: 'demo', ssh_dest: 'user@demo.exe.xyz',
    ssh_command: 'evil', url: 'javascript:evil()', comment: '<b>plain text</b>',
  });
  assert.deepEqual(plain(model.sshCommand(record)),
    ['omarchy-launch-terminal', 'ssh', '--', 'user@demo.exe.xyz']);
  assert.deepEqual(plain(model.browserCommand(record)),
    ['omarchy-launch-browser', 'https://demo.exe.xyz/']);
  assert.equal(record.comment, '<b>plain text</b>');
});

test('VM parsing rejects malformed responses, duplicates, and invalid records', () => {
  for (const text of ['{', 'null', '{}', '{"vms":{}}', '{"vms":[null]}',
    '{"vms":[{"vm_name":"demo"},{"vm_name":"demo"}]}']) {
    assert.throws(() => model.parseVms(text));
  }
  assert.throws(() => model.parseVms('{"error":"test failure"}'), /test failure/);
  assert.deepEqual(plain(model.parseVms('{"vms":[]}')), []);
  const list = model.parseVms(JSON.stringify({vms: [
    {vm_name: 'z', tags: ['work']},
    {vm_name: 'a', tags: ['work']},
    {vm_name: 'b', tags: ['home']},
  ]}));
  assert.deepEqual(Array.from(list, item => item.name), ['b', 'a', 'z']);
});
