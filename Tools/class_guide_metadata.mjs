import { readFileSync } from 'node:fs';
import { parseSQL } from './audit_items.mjs';

export function readDBC(path) {
  const bytes = readFileSync(path);
  if (bytes.toString('ascii', 0, 4) !== 'WDBC') throw new Error('Not a WDBC file: ' + path);
  const count = bytes.readUInt32LE(4), fields = bytes.readUInt32LE(8), size = bytes.readUInt32LE(12);
  const strings = 20 + count * size;
  if (size !== fields * 4 || strings + bytes.readUInt32LE(16) !== bytes.length) throw new Error('Invalid DBC size: ' + path);
  return { count, fields, get(row, field) {
    if (row < 0 || row >= count || field < 0 || field >= fields) throw new Error('DBC field out of bounds');
    return bytes.readUInt32LE(20 + row * size + field * 4);
  }, text(offset) {
    if (offset === 0) return '';
    const end = bytes.indexOf(0, strings + offset);
    if (end < strings) throw new Error('Invalid DBC string');
    return bytes.toString('utf8', strings + offset, end);
  } };
}

export function validateBuild(build, levelCap, metadata) {
  const errors = [], trees = metadata.trees[build.classToken];
  const codes = build.talentsString.split('-');
  let points = 0;
  const allocations = [];
  if (!trees || codes.length > 3 || !/^[0-5-]*$/.test(build.talentsString)) return { valid: false, errors: ['Invalid talent code'] };
  for (let treeIndex = 0; treeIndex < 3; treeIndex++) {
    const tree = trees[treeIndex], code = codes[treeIndex] || '', chosen = new Map();
    if (code.length > tree.length) errors.push('Talent code too long');
    for (let i = 0; i < code.length; i++) if (Number(code[i])) chosen.set(tree[i]?.id, Number(code[i]));
    for (let i = 0; i < code.length; i++) {
      const rank = Number(code[i]), talent = tree[i];
      if (!rank || !talent) continue;
      points += rank;
      if (rank > talent.maxRank) errors.push('Talent rank exceeds maximum: ' + talent.id);
      const lower = tree.reduce((sum, t) => sum + (t.row < talent.row ? chosen.get(t.id) || 0 : 0), 0);
      if (lower < talent.row * 5) errors.push('Talent tier is locked: ' + talent.id);
      if (talent.dependsOn && (chosen.get(talent.dependsOn) || 0) < talent.dependsOnRank) errors.push('Missing talent prerequisite: ' + talent.id);
      allocations.push({ talentID: talent.id, rank, spellID: talent.spells[rank - 1], tree: treeIndex + 1,
        minLevel: 10 + talent.row * 5, maxRank: talent.maxRank });
    }
  }
  if (points > Math.max(0, levelCap - 9)) errors.push('Too many talent points for level ' + levelCap);
  const counts = { major: 0, minor: 0 }, seen = new Set();
  for (const itemID of build.glyphs || []) {
    const glyph = metadata.glyphs[itemID];
    if (!glyph) { errors.push('Unknown 3.3.5 glyph: ' + itemID); continue; }
    if (seen.has(itemID)) errors.push('Duplicate glyph: ' + itemID);
    seen.add(itemID);
    if (glyph.classToken !== build.classToken) errors.push('Wrong glyph class: ' + itemID);
    if (glyph.minLevel > levelCap) errors.push('Glyph level requirement: ' + itemID);
    counts[glyph.category]++;
  }
  const majorSlots = levelCap >= 80 ? 3 : levelCap >= 30 ? 2 : levelCap >= 15 ? 1 : 0;
  const minorSlots = levelCap >= 70 ? 3 : levelCap >= 50 ? 2 : levelCap >= 15 ? 1 : 0;
  if (counts.major > majorSlots || counts.minor > minorSlots) errors.push('Glyph slots are locked');
  return { valid: errors.length === 0, errors, points, allocations };
}

export function loadMetadata(root = '.runtime/wow-art/DBFilesClient') {
  const classes = { 1: 'WARRIOR', 2: 'PALADIN', 3: 'HUNTER', 4: 'ROGUE', 5: 'PRIEST', 6: 'DEATHKNIGHT',
    7: 'SHAMAN', 8: 'MAGE', 9: 'WARLOCK', 11: 'DRUID' };
  const tabs = readDBC(root + '/TalentTab.dbc'), talents = readDBC(root + '/Talent.dbc');
  const spellDBC = readDBC(root + '/Spell.dbc'), glyphDBC = readDBC(root + '/GlyphProperties.dbc');
  const iconDBC = readDBC(root + '/SpellIcon.dbc'), icons = {};
  for (let i = 0; i < iconDBC.count; i++) icons[iconDBC.get(i, 0)] = iconDBC.text(iconDBC.get(i, 1));
  const displayDBC = readDBC(root + '/ItemDisplayInfo.dbc'), itemIcons = {};
  for (let i = 0; i < displayDBC.count; i++) itemIcons[displayDBC.get(i, 0)] = displayDBC.text(displayDBC.get(i, 5));
  const trees = {}, treeDetails = {}, tabMap = {}, spells = {}, properties = {}, glyphs = {};
  for (let i = 0; i < tabs.count; i++) {
    const classID = Object.keys(classes).find(id => tabs.get(i, 20) === 2 ** (Number(id) - 1));
    if (!classID) continue;
    const classToken = classes[classID], page = tabs.get(i, 22);
    if (page > 2) throw new Error('Invalid talent tab index');
    trees[classToken] ||= [[], [], []];
    treeDetails[classToken] ||= [];
    treeDetails[classToken][page] = { name: tabs.text(tabs.get(i, 1)), nameRu: tabs.text(tabs.get(i, 9) || tabs.get(i, 1)),
      background: tabs.text(tabs.get(i, 23)) };
    tabMap[tabs.get(i, 0)] = { classToken, page };
  }
  for (let i = 0; i < talents.count; i++) {
    const tab = tabMap[talents.get(i, 1)];
    if (!tab) continue;
    const ranks = Array.from({ length: 5 }, (_, rank) => talents.get(i, 4 + rank)).filter(Boolean);
    trees[tab.classToken][tab.page].push({ id: talents.get(i, 0), row: talents.get(i, 2), col: talents.get(i, 3),
      maxRank: ranks.length, spells: ranks, dependsOn: talents.get(i, 13), dependsOnRank: talents.get(i, 16) + 1 });
  }
  const talentIDs = new Set(Array.from({ length: talents.count }, (_, i) => talents.get(i, 0)));
  for (const classTrees of Object.values(trees)) for (const tree of classTrees) {
    tree.sort((a, b) => a.row - b.row || a.col - b.col);
    // AzerothCore ignores a prerequisite when the referenced Talent.dbc row no longer exists.
    for (const talent of tree) if (!talentIDs.has(talent.dependsOn)) talent.dependsOn = 0;
  }
  for (let i = 0; i < spellDBC.count; i++) {
    spells[spellDBC.get(i, 0)] = { minLevel: spellDBC.get(i, 39),
      passive: Boolean(spellDBC.get(i, 4) & 64),
      icon: icons[spellDBC.get(i, 133)],
      nameEn: spellDBC.text(spellDBC.get(i, 136)),
      name: spellDBC.text(spellDBC.get(i, 144) || spellDBC.get(i, 136)),
      effects: [0, 1, 2].map(j => ({ type: spellDBC.get(i, 71 + j), misc: spellDBC.get(i, 110 + j) })) };
  }
  for (let i = 0; i < glyphDBC.count; i++) properties[glyphDBC.get(i, 0)] = { spellID: glyphDBC.get(i, 1), category: glyphDBC.get(i, 2) & 1 ? 'minor' : 'major' };
  for (const item of parseSQL(readFileSync('.runtime/upstream-item-template.sql', 'utf8'))) {
    if (item.class !== 16 || !classes[item.subclass]) continue;
    const effect = spells[item.spellid_1]?.effects.find(e => e.type === 74);
    const glyph = properties[effect?.misc];
    if (glyph) glyphs[item.entry] = { ...glyph, icon: itemIcons[item.displayid] && ('Interface\\Icons\\' + itemIcons[item.displayid]),
      classToken: classes[item.subclass], minLevel: item.RequiredLevel, name: item.name };
  }
  return { trees, treeDetails, spells, glyphs };
}
