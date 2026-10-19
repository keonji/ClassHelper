import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { parseSQL } from './audit_items.mjs';

const classTokens = { 'Death knight': 'DEATHKNIGHT', Druid: 'DRUID', Hunter: 'HUNTER', Mage: 'MAGE',
  Paladin: 'PALADIN', Priest: 'PRIEST', Rogue: 'ROGUE', Shaman: 'SHAMAN', Warlock: 'WARLOCK', Warrior: 'WARRIOR' };
const classicSlots = { 1: 'HEAD', 2: 'NECK', 3: 'SHOULDER', 4: 'SHIRT', 5: 'CHEST', 6: 'WAIST', 7: 'LEGS',
  8: 'FEET', 9: 'WRIST', 10: 'HANDS', 11: 'FINGER', 12: 'FINGER', 13: 'TRINKET', 14: 'TRINKET',
  15: 'CLOAK', 16: 'ONEHANDED', 17: 'OFFHAND', 18: 'RANGED', 23: 'BAG' };
const slots = { Head: 'HEAD', Neck: 'NECK', Shoulder: 'SHOULDER', Shoulders: 'SHOULDER', Back: 'CLOAK', Chest: 'CHEST',
  Wrist: 'WRIST', Hands: 'HANDS', Waist: 'WAIST', Legs: 'LEGS', Feet: 'FEET', Finger: 'FINGER', Trinket: 'TRINKET',
  Weapon: 'ONEHANDED', 'Main hand': 'ONEHANDED', 'Off hand': 'OFFHAND', Ranged: 'RANGED', Relic: 'RELIC' };
const tbcSlots = { head: 'HEAD', neck: 'NECK', shoulder: 'SHOULDER', back: 'CLOAK', chest: 'CHEST', wrist: 'WRIST',
  hands: 'HANDS', waist: 'WAIST', legs: 'LEGS', feet: 'FEET', ring1: 'FINGER', ring2: 'FINGER',
  trinket1: 'TRINKET', trinket2: 'TRINKET', mainhand: 'ONEHANDED', offhand: 'OFFHAND', ranged: 'RANGED' };

function validID(id) { return Number.isInteger(id) && id > 0; }

export function normalizeClassic(links, items) {
  return links.map(link => {
    const item = items[link.ItemId];
    if (!item) throw new Error('missing item ' + link.ItemId);
    const slot = link.OffHand ? 'OFFHAND' : item.TwoHands ? 'TWOHANDED' : classicSlots[item.Slot];
    if (!slot || !validID(link.ItemId) || !validID(link.Priority)) throw new Error('invalid Classic recommendation');
    return { classID: link.ClassId, specID: link.SpecId, itemID: link.ItemId, rank: link.Priority,
      races: link.Races, suffixID: link.SuffixId || 0, phase: item.Phase, slot,
      raid: !!item.Raid, worldBoss: !!item.WorldBoss, pvp: !!item.PvP,
      ...(item.Faction ? { factions: item.Faction } : {}) };
  });
}

export function normalizeTBC(database) {
  const result = {};
  for (const [classToken, specs] of Object.entries(database)) {
    result[classToken] = {};
    for (const [spec, phases] of Object.entries(specs)) {
      result[classToken][spec] = {};
      for (const [phase, groups] of Object.entries(phases)) {
        if (!['prebis', 'phase1', 'phase2', 'phase3', 'phase4', 'phase5'].includes(phase)) continue;
        const rows = [];
        for (const [group, entries] of Object.entries(groups)) {
          if (!tbcSlots[group]) throw new Error('unknown TBC slot ' + group);
          for (const [index, item] of entries.entries()) {
            if (!validID(item.id)) throw new Error('invalid TBC item');
            rows.push({ itemID: item.id, slot: tbcSlots[group], rank: index + 1,
              position: /[12]$/.test(group) ? Number(group.slice(-1)) : 1,
              sourceText: item.source || '', sourceType: item.sourceType || '', sourceNote: item.note || '' });
          }
        }
        if (rows.length) result[classToken][spec][phase] = rows;
      }
    }
  }
  return result;
}

export function normalizeWrath(base, overrides = {}) {
  const result = {};
  for (const [className, specs] of Object.entries(base)) {
    const classToken = classTokens[className];
    if (!classToken) throw new Error('unknown Wrath class ' + className);
    result[classToken] = {};
    for (const [spec, phases] of Object.entries(specs)) {
      const target = result[classToken][spec] = { ALLIANCE: {}, HORDE: {} };
      for (const [phase, groups] of Object.entries(phases)) {
        for (const faction of ['ALLIANCE', 'HORDE']) {
          const rows = [];
          for (const [index, baseGroup] of Object.entries(groups)) {
            const luaIndex = Array.isArray(groups) ? Number(index) + 1 : Number(index);
            const replacement = overrides[className]?.[spec]?.[phase];
            const override = Array.isArray(replacement) ? replacement[luaIndex - 1] : replacement?.[luaIndex];
            const group = faction === 'HORDE' ? override || baseGroup : baseGroup;
            const slot = slots[group.slot_name];
            if (!slot) throw new Error('unknown Wrath slot ' + group.slot_name);
            for (let rank = 1; rank <= 6; rank++) {
              const id = group[rank];
              if (id === undefined || id === -1 || id === 0) continue;
              if (!validID(id)) throw new Error('invalid Wrath item');
              rows.push({ itemID: id, slot, rank, position: 1 });
            }
          }
          if (rows.length) target[faction][phase] = rows;
        }
      }
    }
  }
  return result;
}

export const sources = {
  classic: { repository: 'Warkdev/BestInSlotClassic', revision: '302ab4ecca0c86b43441710dab840af5edd3ca3e', license: 'GPL-2.0', name: 'BestInSlotClassic' },
  tbc: { repository: 'mazarelo/tbc-bis-tracker', revision: 'ebb38d1dd723ff1796c3d3c01d7d832438ad762a', license: 'MIT', name: 'TBC BiS Tracker' },
  wrath: { repository: 'Xidiuss/Bistooltip', revision: '07c1321bfd07428168630aaf07389c2263e8f9a8', license: 'MIT', name: 'BiSTooltip / WoWSimsBP' },
};

const snapshots = [
  ['classic', 'data/bis_data.lua', 'classic-links.lua', '87118ae75497eac6f7445db2fb154072d4723fcea2d93e015d4cdc2d88dee4bc'],
  ['classic', 'data/items.lua', 'classic-items.lua', 'dac3de3960c86febf36ea2a4bc05c1000aa9cc20aaab1ea824d36b1d4a7a83db'],
  ['classic', 'LICENSE.txt', 'classic-LICENSE', '488b93d9162db9953bdec3ae4f35e3573424a649b4cc7a5b43fd1448f5ad16a9'],
  ['tbc', 'web/public/data/database.json', 'tbc.json', '9fede268d8db7b65524ee65f34f7886ec9dd7123096f03ffaaf0298f4d3c3b1a'],
  ['tbc', 'LICENSE', 'tbc-LICENSE', '2dad5a863d202e66f739194b5140de7b048150d1a9f573166676f9e3a578491f'],
  ['wrath', 'Bistooltip/Bistooltip_WoWSimsBP_final.lua', 'wrath.lua', '3733f26cb272a96e7c558d8a2316d0900046ee653f480172323c137b32351526'],
  ['wrath', 'Bistooltip/LICENSE', 'wrath-LICENSE', 'c0c8462948681a294688a6198609c27385536fe38a988a68b5c9423fbe361fdf'],
];

function lua(value) {
  if (value === null || value === undefined) return 'nil';
  if (typeof value === 'string') return JSON.stringify(value).replace(/\\u([0-9a-f]{4})/gi, (_, code) => String.fromCharCode(parseInt(code, 16)));
  if (typeof value !== 'object') return String(value);
  const entries = Array.isArray(value) ? value.map(v => lua(v)) : Object.entries(value).map(([k, v]) => `[${/^\d+$/.test(k) ? k : lua(k)}]=${lua(v)}`);
  return '{' + entries.join(',') + '}';
}

async function main() {
  const cache = resolve('.runtime/upstream-bis');
  mkdirSync(cache, { recursive: true });
  const inputs = snapshots.map(([era, path, name, hash]) => ({
    path: cache + '/' + name, hash,
    url: `https://raw.githubusercontent.com/${sources[era].repository}/${sources[era].revision}/${path}`,
  }));
  inputs.push({ path: resolve('.runtime/upstream-item-template.sql'), hash: 'bd4859be01946ca1521f7896f558f665e1e1d98890757a3df30e717b62768cc6',
    url: 'https://raw.githubusercontent.com/azerothcore/azerothcore-wotlk/4d9d1d4b5723e819c5c390f6ca1177283dbfb8e3/data/sql/base/db_world/item_template.sql' });
  for (const input of inputs) {
    if (process.argv.includes('--download')) {
      const response = await fetch(input.url, { signal: AbortSignal.timeout(30000) });
      if (!response.ok) throw new Error('download failed: ' + input.url);
      const body = Buffer.from(await response.arrayBuffer());
      if (createHash('sha256').update(body).digest('hex') !== input.hash) throw new Error('snapshot checksum mismatch: ' + input.url);
      writeFileSync(input.path, body);
    }
    if (createHash('sha256').update(readFileSync(input.path)).digest('hex') !== input.hash) throw new Error('cached snapshot checksum mismatch: ' + input.path);
  }
  const decode = (...paths) => JSON.parse(execFileSync(process.env.CLASSHELPER_LUA || 'luajit', ['Tools/decode_bis.lua', ...paths.map(p => cache + '/' + p)], { maxBuffer: 32 * 1024 * 1024, encoding: 'utf8' }));
  const classic = decode('classic-links.lua', 'classic-items.lua');
  const wrath = decode('wrath.lua');
  const data = {
    classic: normalizeClassic(classic.BIS_LINKS, classic.BIS_ITEMS),
    tbc: normalizeTBC(JSON.parse(readFileSync(cache + '/tbc.json', 'utf8'))),
    wrath: normalizeWrath(wrath.Bistooltip_wowsims_final, wrath.Bistooltip_wowsims_horde_overrides),
  };
  const ids = new Set();
  function collect(value) {
    if (!value || typeof value !== 'object') return;
    if (value.itemID) ids.add(value.itemID);
    for (const child of Object.values(value)) collect(child);
  }
  collect(data);
  const eligibility = {};
  for (const item of parseSQL(readFileSync('.runtime/upstream-item-template.sql', 'utf8'))) {
    if (ids.has(item.entry)) eligibility[item.entry] = { raceMask: item.AllowableRace, classMask: item.AllowableClass,
      level: item.RequiredLevel, factionFlags: item.FlagsExtra, inventoryType: item.InventoryType };
  }
  mkdirSync('Data/Imported', { recursive: true });
  mkdirSync('ThirdParty', { recursive: true });
  writeFileSync('Data/Imported/Eligibility.lua', 'local _, ns = ...\nns.BISData.eligibility=' + lua(eligibility) + '\n');
  for (const [era, payload] of Object.entries(data)) {
    const source = sources[era];
    const licensePath = era === 'classic' ? 'LICENSE.txt' : era === 'tbc' ? 'LICENSE' : 'Bistooltip/LICENSE';
    const license = readFileSync(cache + '/' + era + '-LICENSE', 'utf8');
    writeFileSync('ThirdParty/' + era + '-LICENSE.txt', license);
    const notice = `-- Derived data: https://github.com/${source.repository}/tree/${source.revision}\n-- ${source.license}; see ThirdParty/${era}-LICENSE.txt.\n`;
    writeFileSync('Data/Imported/' + era + '.lua', notice + 'local _, ns = ...\nns.BISData = ns.BISData or {}\nns.BISData.' + era + '=' + lua(payload) + '\n');
    console.log(era, Buffer.byteLength(lua(payload)), 'bytes', source.revision, licensePath);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(error => { console.error(error.message); process.exitCode = 1; });
