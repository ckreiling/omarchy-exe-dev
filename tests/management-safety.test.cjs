const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const source = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
const model = {};
vm.runInNewContext(source('Model.js').replace(/^\.pragma library\s*/, ''), model);

// Exercise the actual JavaScript handlers without loading a desktop or spawning
// any SSH processes. This is not a substitute for manual QML focus testing.
function handler(text, pattern, context) {
  const match = text.match(pattern);
  assert.ok(match, 'expected QML handler must exist');
  return vm.runInNewContext('(function(event) {' + match[1] + '\n})', context);
}

test('management transport failures retain unknown-outcome and copy retry guidance', () => {
  for (const code of [124, 137, 143, 255, -1]) {
    const failure = model.managementFailure(code, 'connection detail');
    assert.equal(failure.uncertain, true);
    assert.match(failure.message, /may have completed remotely/);
    assert.match(failure.message, /inventory before retrying/);
    assert.match(failure.message, /another copy/);
    assert.match(failure.message, /connection detail/);
  }
  const rejected = model.managementFailure(1, 'Permission denied');
  assert.equal(rejected.uncertain, false);
  assert.equal(rejected.message, 'Permission denied');
  assert.ok(model.managementFailure(255, 'x'.repeat(1000)).message.length <= 500);
  for (const signal of [0, 9, 15]) {
    assert.equal(model.managementFailure(signal, '', 1).uncertain, true);
  }
});

test('QML confirmation ignores autorepeat and accepts a fresh deliberate keypress', () => {
  let confirmed = 0, cancelled = 0;
  const Qt = {Key_Escape: 1, Key_Return: 2, Key_Enter: 3};
  const press = handler(source('VmDetail.qml'), /Keys\.onPressed: function\(event\) \{([\s\S]*?)\n    \}\n    Text \{/, {
    Qt, root: {confirmPending() { confirmed++; }, cancelPending() { cancelled++; }},
  });
  for (const key of [Qt.Key_Return, Qt.Key_Enter]) {
    const held = {key, isAutoRepeat: true, accepted: false};
    press(held);
    assert.equal(held.accepted, true);
    assert.equal(confirmed, key === Qt.Key_Return ? 0 : 1);
    press({key, isAutoRepeat: false});
  }
  assert.equal(confirmed, 2);
  press({key: Qt.Key_Escape, isAutoRepeat: false});
  assert.equal(cancelled, 1);
  assert.match(source('Widget.qml'), /blocked: filterField\.activeFocus \|\| detailView\.confirming/);
});

test('an in-flight stale inventory cannot unlock an uncertain management outcome', () => {
  const text = source('VmService.qml');
  const queued = [];
  const root = {
    managementAwaitingRefresh: true, listReconcilesManagement: false,
    refreshPending: false, lastError: '',
    readList(code, status) { this.lastError = code === 0 && status === 0 ? '' : 'failed'; },
  };
  const listProcess = {running: true};
  const context = {root, listProcess, Qt: {callLater(fn) { queued.push(fn); }}};
  // QML exposes root properties unqualified inside its own functions.
  for (const key of ['refreshPending', 'listReconcilesManagement', 'managementAwaitingRefresh']) {
    Object.defineProperty(context, key, {get() { return root[key]; }, set(value) { root[key] = value; }});
  }
  root.refresh = handler(text, /function refresh\(\) \{([\s\S]*?)\n  \}/, context);
  const exitedMatch = text.match(/id: listProcess[\s\S]*?onExited: function\(exitCode, exitStatus\) \{([\s\S]*?)\n    \}/);
  assert.ok(exitedMatch);
  const exited = vm.runInNewContext('(function(exitCode, exitStatus) {' + exitedMatch[1] + '\n})', context);
  root.refresh();
  assert.equal(root.refreshPending, true);
  assert.equal(root.listReconcilesManagement, false);
  listProcess.running = false;
  exited(0, 0); // Earlier request succeeds, but it predates the uncertain command.
  assert.equal(root.managementAwaitingRefresh, true);
  queued.shift()(); // The coalesced request starts after the command.
  assert.equal(root.listReconcilesManagement, true);
  listProcess.running = false;
  exited(1, 0); // A failed reconciliation must not unlock management.
  assert.equal(root.managementAwaitingRefresh, true);
  root.refresh();
  listProcess.running = false;
  exited(0, 1); // Even exit code zero cannot reconcile a crashed query.
  assert.equal(root.managementAwaitingRefresh, true);
  root.refresh();
  listProcess.running = false;
  exited(0, 0);
  assert.equal(root.managementAwaitingRefresh, false);
  assert.match(text, /readonly property bool managementBusy: managementProcess\.running \|\| managementAwaitingRefresh/);
  assert.match(text, /function manage\(vmName, action\) \{\s*if \(managementBusy\) return/);
});

test('actual management exit handler treats raw Qt CrashExit signals as uncertain', () => {
  const match = source('VmService.qml').match(/id: managementProcess[\s\S]*?onExited: function\(exitCode, exitStatus\) \{([\s\S]*?)\n    \}/);
  assert.ok(match);
  const queued = [];
  const root = {managementAction: 'copy', refresh() {}};
  const exited = vm.runInNewContext('(function(exitCode, exitStatus) {' + match[1] + '\n})', {
    root, Model: model,
    managementErrors: {text: ''}, managementOutput: {text: ''},
    Qt: {callLater(fn) { queued.push(fn); }},
  });
  for (const code of [0, 9, 15]) {
    root.managementAwaitingRefresh = false;
    exited(code, 1); // QProcess::CrashExit, including raw SIGKILL (9).
    assert.equal(root.managementError, true);
    assert.equal(root.managementAwaitingRefresh, true);
    assert.match(root.managementMessage, /may have completed remotely/);
    assert.match(root.managementMessage, /another copy/);
  }
  assert.equal(queued.length, 3);
  root.managementAwaitingRefresh = false;
  exited(0, 0); // A normal successful copy must not be reported as a crash.
  assert.equal(root.managementError, false);
  assert.equal(root.managementAwaitingRefresh, false);
  assert.match(root.managementMessage, /Copy created/);
});

test('actual inventory reader rejects CrashExit even with code zero and valid JSON', () => {
  const match = source('VmService.qml').match(/function readList\(exitCode, exitStatus\) \{([\s\S]*?)\n  \}/);
  assert.ok(match);
  const previous = [{name: 'previous'}];
  const context = {
    vms: previous, lastError: '', errors: {text: ''}, output: {text: '{"vms":[]}'},
    Model: model, Qt: {formatTime() { return '12:00:00'; }},
  };
  const read = vm.runInNewContext('(function(exitCode, exitStatus) {' + match[1] + '\n})', context);
  read(0, 1);
  assert.notEqual(context.lastError, '');
  assert.equal(context.vms, previous);
});
