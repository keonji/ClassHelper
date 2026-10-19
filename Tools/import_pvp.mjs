import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseSQL } from './audit_items.mjs';

const slots = { helm: 'HEAD', head: 'HEAD', neck: 'NECK', shoulders: 'SHOULDER', shoulder: 'SHOULDER', back: 'CLOAK',
  chest: 'CHEST', wrists: 'WRIST', wrist: 'WRIST', hands: 'HANDS', gloves: 'HANDS', waist: 'WAIST', belt: 'WAIST',
  legs: 'LEGS', feet: 'FEET', rings: 'FINGER', ring: 'FINGER', finger: 'FINGER', trinkets: 'TRINKET', trinket: 'TRINKET',
  weapon: 'ONEHANDED', 'melee weapon': 'ONEHANDED', 'main hand': 'ONEHANDED', 'main-hand': 'ONEHANDED', 'one-hand': 'ONEHANDED',
  'two-hand': 'TWOHANDED', 'two-handed weapon': 'TWOHANDED', 'off-hand': 'OFFHAND', 'off hand': 'OFFHAND', shield: 'OFFHAND',
  'ranged weapon': 'RANGED', ranged: 'RANGED', relic: 'RELIC', libram: 'RELIC', idol: 'RELIC', totem: 'RELIC' };
const inventorySlots = { 1: 'HEAD', 2: 'NECK', 3: 'SHOULDER', 5: 'CHEST', 6: 'WAIST', 7: 'LEGS', 8: 'FEET',
  9: 'WRIST', 10: 'HANDS', 11: 'FINGER', 12: 'TRINKET', 13: 'ONEHANDED', 14: 'OFFHAND', 15: 'RANGED',
  16: 'CLOAK', 17: 'TWOHANDED', 20: 'CHEST', 21: 'ONEHANDED', 22: 'OFFHAND', 23: 'OFFHAND', 25: 'RANGED', 26: 'RANGED', 28: 'RELIC' };
Object.assign(slots, { cloak: 'CLOAK', boots: 'FEET', weapons: 'ONEHANDED', 'melee weapons': 'ONEHANDED',
  staffs: 'TWOHANDED', staves: 'TWOHANDED', relics: 'RELIC', 'off-hands': 'OFFHAND',
  'main-hand weapon': 'ONEHANDED', 'off-hand weapon': 'OFFHAND', bracer: 'WRIST',
  idols: 'RELIC', librams: 'RELIC', wand: 'RANGED', wands: 'RANGED', thrown: 'RANGED',
  'standard trinkets': 'TRINKET', 'ring 1': 'FINGER', 'ring 2': 'FINGER',
  'trinket 1': 'TRINKET', 'trinket 2': 'TRINKET', swords: 'ONEHANDED', daggers: 'ONEHANDED',
  'main-hand / off-hand': 'ONEHANDED', quivers: 'BAG', arrows: 'AMMO' });
inventorySlots[18] = 'BAG';
inventorySlots[24] = 'AMMO';

export function parsePvPTables(snapshot, eligibility) {
  const builds = [];
  let heading = '';
  for (const block of snapshot.blocks) {
    if (block.type === 'heading') { heading = block.text; continue; }
    if (/enchant|gem|switch|consumable/i.test(heading)) continue;
    const rows = block.rows;
    if (rows?.[0]?.[0]?.text === 'Slot' && !/^Item$/i.test(rows[0][1]?.text)) continue;
    if (!rows?.some(row => /^(helm|head)$/i.test(row[0]?.text))) continue;
    if (!rows.some(row => /^(feet|legs)$/i.test(row[0]?.text))) {
      if (!/^(slot)$/i.test(rows[0]?.[0]?.text)) continue;
    }
    const items = [];
    const seen = new Set();
    for (const row of rows) {
      if (!row.length) continue;
      const label = row[0]?.text.trim().toLowerCase();
      if (label === 'slot') continue;
      const expected = slots[label];
      if (!expected) throw new Error(`Unknown PvP slot ${label} at ${snapshot.url}`);
      const links = row[1]?.links || [];
      const rowStart = items.length;
      if (/non-human/i.test(row[1]?.text || '')) throw new Error(`Conditional Non-Human layout needs review at ${snapshot.url}`);
      const humanLine = row[1]?.text.split(/\n/).find(line => /\(if Human\)/i.test(line));
      let position = 0;
      for (const link of links) {
        const id = Number(link.href.match(/(?:item[=/])(\d+)/)?.[1]);
        if (!id) continue;
        const meta = eligibility[id];
        if (!meta) throw new Error(`Missing item metadata ${id} at ${snapshot.url}`);
        let slot = inventorySlots[meta.inventoryType];
        if (slot === 'ONEHANDED' && expected === 'OFFHAND' && meta.inventoryType === 13) slot = 'OFFHAND';
        if (!slot) continue;
        if (slot !== expected && !(expected === 'ONEHANDED' && ['TWOHANDED', 'OFFHAND'].includes(slot))) {
          throw new Error(`Item ${id} slot ${slot} does not match ${expected} at ${snapshot.url}`);
        }
        const identity = `${slot}:${id}`;
        if (seen.has(identity)) continue;
        seen.add(identity);
        position++;
        items.push({ itemID: id, slot, position: ['FINGER', 'TRINKET'].includes(slot) ? Number(label.match(/\d$/)?.[0]) || position : 1,
          sourceText: row[2]?.text || '', sourceURL: snapshot.url,
          ...(humanLine && link.text && humanLine.includes(link.text.trim()) ? { onlyRace: 'HUMAN' } : {}) });
      }
      if (!items.some(item => item.slot === expected || (expected === 'ONEHANDED' && ['TWOHANDED', 'OFFHAND'].includes(item.slot)))) {
        throw new Error(`No gear links for ${label} at ${snapshot.url}`);
      }
      const added = items.slice(rowStart);
      if (added.length > 1) {
        for (const item of added) item.sourceGrouped = 1;
      }
      if (['FINGER', 'TRINKET'].includes(expected) && added.length > 2) {
        for (const item of added) { item.position = 1; item.pooled = 1; }
      }
    }
    const season = heading.match(/season\s+(\d+)/i);
    const phase = heading.match(/phase\s+(\d+)/i);
    builds.push({ phase: season ? `s${season[1]}` : phase ? `p${phase[1]}` : 'reference', title: heading, items });
  }
  return builds;
}

function lua(value) {
  if (typeof value === 'string') return JSON.stringify(value).replace(/\\u([0-9a-f]{4})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
  if (typeof value === 'number') return String(value);
  if (Array.isArray(value)) return '{' + value.map(lua).join(',') + '}';
  return '{' + Object.entries(value).map(([key, item]) => `[${lua(/^\d+$/.test(key) ? Number(key) : key)}]=${lua(item)}`).join(',') + '}';
}

function identity(url) {
  const slug = url.split('/').at(-1);
  const className = ['death-knight', 'warrior', 'paladin', 'hunter', 'rogue', 'priest', 'shaman', 'mage', 'warlock', 'druid'].find(x => slug.includes(x));
  const classToken = className?.replace('-', '').toUpperCase();
  const map = { unholy: 'Unholy', arms: 'Arms', protection: 'Protection', retribution: 'Retribution', holy: 'Holy',
    discipline: 'Discipline', shadow: 'Shadow', elemental: 'Elemental', enhancement: 'Enhancement', restoration: 'Restoration',
    feral: 'Feral dps', balance: 'Balance', 'beast-mastery': 'Beast mastery', marksmanship: 'Marksmanship', survival: 'Survival',
    arcane: 'Arcane', fire: 'Fire', frost: 'Frost', subtlety: 'Subtlety', affliction: 'Affliction', destruction: 'Destruction' };
  let spec = Object.keys(map).find(x => slug.startsWith(x + '-'));
  if (!spec && /healer/.test(slug)) spec = className === 'priest' || className === 'paladin' ? 'holy' : 'restoration';
  const common = { HUNTER: ['Beast mastery', 'Marksmanship', 'Survival'], MAGE: ['Arcane', 'Fire', 'Frost'],
    ROGUE: ['Assassination', 'Combat', 'Subtlety'], WARLOCK: ['Affliction', 'Demonology', 'Destruction'], WARRIOR: ['Arms'] };
  return { classToken, specs: spec ? [map[spec]] : common[classToken], shared: spec ? 0 : 1 };
}

function main() {
  const root = '.runtime/upstream-pvp/';
  const eligibility = {};
  for (const item of parseSQL(readFileSync('.runtime/upstream-item-template.sql', 'utf8'))) {
    eligibility[item.entry] = { raceMask: item.AllowableRace, classMask: item.AllowableClass,
      level: item.RequiredLevel, factionFlags: item.FlagsExtra, inventoryType: item.InventoryType };
  }
  const data = [], report = [];
  for (const source of JSON.parse(readFileSync(root + 'snapshots.json', 'utf8'))) {
    const raw = readFileSync(root + source.file, 'utf8');
    const snapshot = JSON.parse(raw);
    const era = source.url.includes('/wow-classic/') ? 'classic' : source.url.includes('/tbc-classic/') ? 'tbc' : 'wrath';
    try {
      const builds = parsePvPTables(snapshot, eligibility);
      const profile = identity(source.url);
      if (!profile.classToken) throw new Error('Unrecognized class');
      if (!profile.specs) throw new Error('Shared class table needs explicit specialization review');
      for (const build of builds) {
        data.push({ ...build, ...profile, era, url: source.url, sha256: createHash('sha256').update(raw).digest('hex'), date: '2026-10-19' });
      }
      report.push({ ...source, builds: builds.length });
    } catch (error) { report.push({ ...source, error: error.message }); }
  }
  const used = new Set(data.flatMap(x => x.items.map(item => item.itemID)));
  const meta = Object.fromEntries([...used].map(id => [id, eligibility[id]]));
  writeFileSync('Data/Imported/PvP.lua', 'local _, ns = ...\nns.PvPData=' + lua({ builds: data, eligibility: meta }) + '\n');
  writeFileSync('.runtime/pvp-import-report.json', JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ builds: data.length, items: used.size, skipped: report.filter(x => x.error) }, null, 2));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
