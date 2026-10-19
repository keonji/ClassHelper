import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export function parseSQL(sql) {
  const fields = [...sql.matchAll(/^  `([^`]+)`/gm)].map(match => match[1]);
  if (!fields.length) throw new Error('SQL table schema is missing');
  const rows = [];
  for (const raw of sql.split('\n')) {
    const line = raw.trim();
    if (/^(?:INSERT|REPLACE)\b/i.test(line) && !/^INSERT INTO `[^`]+` VALUES$/i.test(line)) {
      throw new Error('SQL layout unsupported: expected INSERT header followed by one tuple per line');
    }
    if (!line.startsWith('(')) continue;
    const values = [];
    let value = '', quoted = false, wasQuoted = false, closed = false;
    for (let index = 1; index < line.length; index++) {
      const char = line[index];
      if (quoted && char === '\\') {
        const next = line[++index];
        value += ({ n: '\n', r: '\r', t: '\t', 0: '\0' })[next] ?? next;
      } else if (char === "'") {
        if (quoted && line[index + 1] === "'") { value += "'"; index++; }
        else { quoted = !quoted; wasQuoted = true; }
      } else if (!quoted && (char === ',' || char === ')')) {
        const token = value.trim();
        if (!wasQuoted && token !== 'NULL' && (!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(token) || !Number.isFinite(Number(token)))) {
          throw new Error('SQL numeric token is invalid');
        }
        values.push(wasQuoted ? value : token === 'NULL' ? null : Number(token));
        value = ''; wasQuoted = false;
        if (char === ')') {
          if (!/^[,;]?$/.test(line.slice(index + 1).trim())) throw new Error('SQL layout unsupported: expected one tuple per line');
          closed = true;
          break;
        }
      } else value += char;
    }
    if (!closed || quoted || values.length !== fields.length) throw new Error('SQL row does not match table schema');
    rows.push(Object.fromEntries(fields.map((key, index) => [key, values[index]])));
  }
  return rows;
}

const slots = { HEAD: [1], NECK: [2], SHOULDER: [3], CLOAK: [16], CHEST: [5, 20], WRIST: [9],
  HANDS: [10], WAIST: [6], LEGS: [7], FEET: [8], FINGER: [11], TRINKET: [12],
  ONEHANDED: [13, 21], TWOHANDED: [17], OFFHAND: [23], RANGED: [26], RELIC: [28] };
const classes = { PALADIN: 2, MAGE: 128 };
const races = { HUMAN: 1 };

function indexRows(rows, key) {
  const result = new Map();
  for (const row of rows) {
    if (!result.has(row[key])) result.set(row[key], []);
    result.get(row[key]).push(row);
  }
  return result;
}

export function traceCreatureSources(database, wanted) {
  const loot = indexRows(database.creatureLoot, 'Entry');
  const references = indexRows(database.references, 'Entry');
  const spawnMaps = new Map();
  for (const spawn of database.spawns) {
    for (const id of [spawn.id1, spawn.id2, spawn.id3]) {
      if (!id) continue;
      if (!spawnMaps.has(id)) spawnMaps.set(id, new Set());
      spawnMaps.get(id).add(spawn.map);
    }
  }
  const locations = new Map();
  for (const creature of database.creatures) {
    const maps = spawnMaps.get(creature.entry);
    if (!maps) continue;
    locations.set(creature.entry, [...maps].map(mapID => ({ creatureID: creature.entry, mapID, difficultyIndex: 0 })));
    for (let index = 1; index <= 3; index++) {
      const id = creature['difficulty_entry_' + index];
      if (id) locations.set(id, [...maps].map(mapID => ({ creatureID: id, mapID, difficultyIndex: index })));
    }
  }
  const memo = new Map();
  function expand(rows, active = new Set()) {
    const found = new Set();
    for (const row of rows || []) {
      if (row.Reference) {
        const reference = Math.abs(row.Reference);
        if (active.has(reference)) throw new Error('Cyclic loot reference: ' + reference);
        if (!references.has(reference)) throw new Error('Missing loot reference: ' + reference);
        if (!memo.has(reference)) memo.set(reference, expand(references.get(reference), new Set([...active, reference])));
        for (const id of memo.get(reference)) found.add(id);
      } else if (wanted.has(row.Item)) found.add(row.Item);
    }
    return found;
  }
  const sources = new Map();
  for (const creature of database.creatures) {
    if (!creature.lootid) continue;
    for (const id of expand(loot.get(creature.lootid))) {
      if (!sources.has(id)) sources.set(id, []);
      sources.get(id).push(...(locations.get(creature.entry) || [{ creatureID: creature.entry }]));
    }
  }
  return sources;
}

const mapStages = {
  409: 'classic_molten_core', 469: 'classic_blackwing_lair', 309: 'classic_zulgurub',
  509: 'classic_aq20', 531: 'classic_aq40', 532: 'tbc_karazhan', 565: 'tbc_gruul_magtheridon',
  544: 'tbc_gruul_magtheridon', 548: 'tbc_serpentshrine', 550: 'tbc_tempest_keep',
  534: 'tbc_hyjal', 564: 'tbc_black_temple', 568: 'tbc_zulaman', 585: 'tbc_isle', 580: 'tbc_sunwell',
  533: 'wrath_tier_7', 615: 'wrath_tier_7', 616: 'wrath_tier_7', 603: 'wrath_ulduar',
  649: 'wrath_crusaders_coliseum', 650: 'wrath_crusaders_coliseum', 631: 'wrath_icecrown',
  632: 'wrath_icecrown', 658: 'wrath_icecrown', 668: 'wrath_icecrown', 724: 'wrath_ruby_sanctum',
};
const wrathDungeons = new Set([619, 574, 575, 576, 578, 595, 599, 600, 601, 602, 604, 608]);

export function auditSourceStages(sets, sources) {
  const order = new Map(sets.map(set => [set.stageKey, set.displayOrder]));
  const selected = new Set(sets.flatMap(set => set.items.map(item => item.itemID)));
  const earliest = new Map();
  for (const id of selected) {
    for (const source of sources.get(id) || []) {
      const key = wrathDungeons.has(source.mapID)
        ? (source.difficultyIndex ? 'wrath_heroic_dungeons' : 'wrath_normal_dungeons') : mapStages[source.mapID];
      if (key && order.has(key) && (!earliest.has(id) || order.get(key) < order.get(earliest.get(id)))) earliest.set(id, key);
    }
  }
  const warnings = [];
  for (const set of sets) {
    for (const entry of set.items) {
      const firstStage = earliest.get(entry.itemID);
      if (firstStage && order.get(firstStage) > set.displayOrder) warnings.push({ code: 'later_creature_source',
        guideKey: set.guideKey, stageKey: set.stageKey, itemID: entry.itemID, firstStage });
    }
  }
  return { mappedItems: earliest.size, unmappedItemIDs: [...selected].filter(id => !earliest.has(id)), warnings };
}

export function auditSets(sets, database) {
  const items = new Map(database.items.map(item => [Number(item.entry), item]));
  const result = { sets: sets.length, recommendations: 0, uniqueItems: 0, errors: [], warnings: [] };
  const unique = new Set();
  for (const set of sets) {
    if (!classes[set.classToken] || !races[set.raceToken]) throw new Error('Unsupported audit profile');
    const counts = new Map();
    const report = (code, id, extra = {}) => ({ code, guideKey: set.guideKey, stageKey: set.stageKey, itemID: id, ...extra });
    for (const entry of set.items) {
      const id = Number(entry.itemID), item = items.get(id);
      result.recommendations++; unique.add(id);
      if (!item) { result.errors.push(report('missing_item', id)); continue; }
      const error = code => result.errors.push(report(code, id));
      if (Number(item.RequiredLevel) > set.levelCap) error('level');
      if (Number(item.AllowableClass) !== -1 && !(Number(item.AllowableClass) & classes[set.classToken])) error('class');
      if (Number(item.AllowableRace) !== -1 && !(Number(item.AllowableRace) & races[set.raceToken])) error('race');
      if ((!set.kind || set.kind === 'gear') && !slots[entry.slot]?.includes(Number(item.InventoryType))) error('slot');
      if (Number(item.FlagsExtra) & 1) error('faction');
      const requirements = entry.requirements || {};
      if (Number(item.RequiredSkill) && (requirements.skillID !== Number(item.RequiredSkill)
          || requirements.skillRank !== Number(item.RequiredSkillRank))) error('skill_requirement');
      if (Number(item.requiredspell) && requirements.spellID !== Number(item.requiredspell)) error('spell_requirement');
      if (Number(item.RequiredReputationFaction) && (requirements.factionID !== Number(item.RequiredReputationFaction)
          || requirements.reputationRank !== Number(item.RequiredReputationRank))) error('reputation_requirement');
      const count = (counts.get(id) || 0) + 1;
      counts.set(id, count);
      if ((!set.kind || set.kind === 'gear') && ((count > 1 && (Number(item.Flags) & 524288))
          || (Number(item.maxcount) > 0 && count > Number(item.maxcount)))) error('unique_item');
    }
    const selected = new Set(set.items.map(item => Number(item.itemID)));
    for (const quest of database.quests || []) {
      if (Number(quest.Flags) & (4096 | 32768)) continue;
      if (Number(quest.SpecialFlags) & 1) continue;
      const choices = [...new Set(Array.from({ length: 6 }, (_, index) => Number(quest['RewardChoiceItemID' + (index + 1)])))]
        .filter(id => id && selected.has(id) && Number(items.get(id)?.Bonding) === 1);
      if (choices.length > 1) result.warnings.push(report('quest_choice', choices[0], { questID: Number(quest.ID), itemIDs: choices }));
    }
  }
  result.uniqueItems = unique.size;
  return result;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const index = process.argv.indexOf('--sql-dir');
  const directory = index >= 0 && process.argv[index + 1];
  if (!directory) {
    process.stderr.write('Usage: node Tools/audit_items.mjs --sql-dir .runtime\n');
    process.exitCode = 2;
  } else {
    try {
      const root = fileURLToPath(new URL('../', import.meta.url));
      const exported = JSON.parse(execFileSync(process.env.CLASSHELPER_LUA || 'luajit', ['Tools/export_items.lua'], { cwd: root, encoding: 'utf8' }));
      const load = name => parseSQL(readFileSync(join(directory, 'upstream-' + name + '.sql'), 'utf8'));
      const database = { items: load('item-template'), quests: load('quest-template') };
      const report = auditSets(exported.sets, database);
      report.auxiliary = auditSets(exported.auxiliarySets, database);
      if (process.argv.includes('--sources')) {
        const wanted = new Set(exported.sets.flatMap(set => set.items.map(item => item.itemID)));
        const sources = traceCreatureSources({ creatures: load('creature-template'), spawns: load('creature'),
          creatureLoot: load('creature-loot'), references: load('reference-loot') }, wanted);
        report.acquisition = auditSourceStages(exported.sets, sources);
      }
      process.stdout.write(JSON.stringify(report, null, 2) + '\n');
      if (report.errors.length || report.auxiliary.errors.length) process.exitCode = 1;
    } catch (error) {
      process.stderr.write('Item audit failed: ' + error.message + '\n');
      process.exitCode = 2;
    }
  }
}
