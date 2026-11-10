// Read route coordinates from the same resources exported into the game.
const fs = require('node:fs');
const path = require('node:path');
module.exports = function loadLevel(name) {
 const source = fs.readFileSync(path.join(__dirname, '../game/levels', name + '.tres'), 'utf8');
 const vectors = key => {
  const value = source.match(new RegExp('(?:^|\\n)' + key + ' = ([\\s\\S]*?)(?=\\n[a-z_]+ = |$)'))[1];
  return [...value.matchAll(/Vector3\(([^)]+)\)/g)].map(m => m[1].split(',').map(Number));
 };
 return {pads: vectors('pads').map(p => p.slice(0, 2)), flag: vectors('flag_position')[0].filter((_, i) => i !== 1),
  fireflies: vectors('fireflies').map(p => [p[0], p[2]]),
  frogs: (source.match(/^frog_pads = Array\[int\]\(\[([^\]]*)\]/m)?.[1] || '').split(',').filter(Boolean).map(Number)};
};
