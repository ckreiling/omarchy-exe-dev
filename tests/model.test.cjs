const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const model = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../Model.js'), 'utf8')
  .replace(/^\.pragma library\s*/, ''), model);
const vms = [
  {name: 'alpha-dev', group: 'work', comment: 'production', tags: ['work']},
  {name: 'beta-prod', group: 'work', comment: 'alpha', tags: ['work']},
  {name: 'gamma-dev', group: 'Untagged', comment: '', tags: []},
];
const names = list => Array.from(list, item => item.name);
const find = (list, query) => names(model.filterVms(list, query));
assert.deepEqual(find(vms, ''), names(vms));
assert.deepEqual(find(vms, '  '), names(vms));
assert.deepEqual(find(vms, ' DEV '), ['alpha-dev', 'gamma-dev']);
assert.deepEqual(find(vms, 'alpha'), ['alpha-dev']);
assert.deepEqual(find(vms, 'work'), []); // No tag/description matching.
assert.deepEqual(find(vms, 'nonexistent'), []);
assert.deepEqual(find([], 'dev'), []);
assert.deepEqual(find(vms, 'APDV'), ['alpha-dev']);
assert.deepEqual(find(vms, 'dvap'), []); // Character order is required.

assert.ok(Number.isFinite(model.fuzzyScore('my-dev-box', 'mdb')));
assert.equal(model.fuzzyScore('my-dev-box', 'mbd'), -Infinity);
assert.equal(model.fuzzyScore('my-dev-box', ' MDB '), model.fuzzyScore('my-dev-box', 'mdb'));
assert.equal(model.fuzzyScore('ab', 'aab'), -Infinity); // Cannot reuse a character.
assert.equal(model.fuzzyScore('', 'x'), -Infinity);
assert.equal(model.fuzzyScore('anything', ''), 0);
assert.ok(Number.isFinite(model.fuzzyScore('a'.repeat(63), 'a'.repeat(62))));

// Rank tiers override input order and tag grouping.
const ranked = [
  {name: 'my-dev-box', group: 'first'},
  {name: 'x-mdb', group: 'first'},
  {name: 'mdb-server', group: 'last'},
  {name: 'mdb', group: 'last'},
];
const originalOrder = names(ranked);
assert.deepEqual(find(ranked, 'mdb'), ['mdb', 'mdb-server', 'x-mdb', 'my-dev-box']);
assert.deepEqual(names(ranked), originalOrder); // No mutation of service data.
assert.deepEqual(find([{name: 'dev-b'}, {name: 'dev-a'}], 'dev'), ['dev-a', 'dev-b']);
assert.ok(model.fuzzyScore('a-b-c', 'abc') > model.fuzzyScore('axbxc', 'abc'));
assert.ok(model.fuzzyScore('ab-x-c', 'abc') > model.fuzzyScore('ax-b-c', 'abc'));
assert.ok(model.fuzzyScore('a-b-c', 'abc') > model.fuzzyScore('x-a-b-c', 'abc'));

const filtered = model.filterVms(vms, 'dev');
const grouped = model.listRows(filtered, '');
assert.deepEqual(Array.from(grouped, row => row.kind), ['group', 'vm', 'group', 'vm']);
assert.deepEqual(Array.from(grouped.filter(row => row.vm), row => row.vmIndex), [0, 1]);
assert.deepEqual(Array.from(grouped.filter(row => !row.vm), row => row.count), [1, 1]);
assert.deepEqual(Array.from(model.listRows(vms, '  '), row => row.kind),
  Array.from(model.groupedRows(vms), row => row.kind));
const results = model.filterVms(ranked, 'mdb');
const flat = model.listRows(results, 'mdb');
assert.deepEqual(Array.from(flat, row => row.kind), ['vm', 'vm', 'vm', 'vm']);
assert.deepEqual(Array.from(flat, row => row.vmIndex), [0, 1, 2, 3]);
flat.forEach((row, i) => assert.equal(row.vm, results[i]));
assert.equal(model.listRows([], 'missing').length, 0);
assert.equal(vms.length, 3);
assert.equal(filtered[0], vms[0]);

// Exhaustively enumerate alignments as an independent oracle for the DP.
function bruteScore(name, query) {
  if (name === query) return 1000000;
  if (name.startsWith(query)) return 100000 - name.length;
  const at = name.indexOf(query);
  if (at >= 0) return 10000 - at * 2 - name.length;
  let best = -Infinity;
  function visit(i, last, score) {
    if (i === query.length) { best = Math.max(best, score); return; }
    for (let j = last + 1; j < name.length; j++) {
      if (name[j] !== query[i]) continue;
      const reward = 10 + (j === 0 || name[j - 1] === '-' ? 8 : 0);
      const gap = j - last - 1;
      visit(i + 1, j, score + reward + (i === 0 ? -j : (gap === 0 ? 12 : -gap)));
    }
  }
  visit(0, -1, 0);
  return best;
}
function strings(alphabet, length, prefix = '') {
  if (!length) return [prefix];
  return [...alphabet].flatMap(char => strings(alphabet, length - 1, prefix + char));
}
for (const middle of strings('ab-', 4)) {
  const name = 'a' + middle + 'b';
  for (const query of strings('ab', 3)) {
    assert.equal(model.fuzzyScore(name, query), bruteScore(name, query), `${name} / ${query}`);
  }
}
console.log('PASS: fuzzy matching, ranking, case folding, flat/grouped rows, navigation indices, and 648 exhaustive alignment checks');
