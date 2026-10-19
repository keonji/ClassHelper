import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const statNames = {
  Strength: 'STRENGTH', Agility: 'AGILITY', Stamina: 'STAMINA', Intellect: 'INTELLECT', Spirit: 'SPIRIT',
  SpellPower: 'SPELL_POWER', AttackPower: 'ATTACK_POWER', RangedAttackPower: 'RANGED_ATTACK_POWER',
  FeralAttackPower: 'FERAL_ATTACK_POWER', MP5: 'MANA_REGENERATION', Expertise: 'EXPERTISE_RATING',
  ArmorPenetration: 'ARMOR_PENETRATION_RATING', Defense: 'DEFENSE_SKILL_RATING', Dodge: 'DODGE_RATING',
  Parry: 'PARRY_RATING', Block: 'BLOCK_RATING', BlockValue: 'BLOCK_VALUE', Resilience: 'RESILIENCE_RATING',
  Health: 'HEALTH', Mana: 'MANA', MeleeHit: 'HIT_RATING', SpellHit: 'HIT_RATING',
  MeleeCrit: 'CRIT_RATING', SpellCrit: 'CRIT_RATING', MeleeHaste: 'HASTE_RATING', SpellHaste: 'HASTE_RATING',
};

export function extractWeights(source) {
  const block = source.match(/epWeights:\s*Stats\.fromMap\(\{([\s\S]*?)\}/)?.[1];
  if (!block) throw new Error('Missing literal epWeights map');
  const stats = {}, unmapped = [];
  const entries = block.replace(/\/\/[^\n]*/g, '').split(',').map(x => x.trim()).filter(Boolean);
  for (const entry of entries) {
    const match = entry.match(/^\[Stat\.(Stat\w+)\]:\s*(-?\d+(?:\.\d+)?)$/);
    if (!match) throw new Error('Expected numeric stat weight: ' + entry);
    const [, key, literal] = match, value = Number(literal), name = key.slice(4);
    const token = name === 'Armor' ? 'RESISTANCE0_NAME' : statNames[name] && 'ITEM_MOD_' + statNames[name] + '_SHORT';
    if (!token) { if (value !== 0) unmapped.push(key); continue; }
    stats[token] = (stats[token] || 0) + value;
  }
  if (stats.ITEM_MOD_RANGED_ATTACK_POWER_SHORT) {
    stats.ITEM_MOD_ATTACK_POWER_SHORT = (stats.ITEM_MOD_ATTACK_POWER_SHORT || 0) + stats.ITEM_MOD_RANGED_ATTACK_POWER_SHORT;
  }
  return { stats, unmapped };
}

const sources = {
  wrath: { repo: 'wowsims/wotlk', revision: '563e4a08cb15729f1fdcbcf68e6d68224553bfef' },
  tbc: { repo: 'wowsims/tbc', revision: '3301fca59306a747e521274c36e073e69acc7b77' },
};
const bindings = {
  WARRIOR: { Arms: 'warrior', Fury: 'warrior', Protection: 'protection_warrior' },
  PALADIN: { Holy: 'holy_paladin', Protection: 'protection_paladin', Retribution: 'retribution_paladin' },
  HUNTER: { 'Beast mastery': 'hunter', Marksmanship: 'hunter', Survival: 'hunter' },
  ROGUE: { Assassination: 'rogue', Combat: 'rogue', Subtlety: 'rogue' },
  PRIEST: { Discipline: 'healing_priest', Holy: 'healing_priest', Shadow: 'shadow_priest' },
  DEATHKNIGHT: { 'Blood dps': 'deathknight', 'Blood tank': 'tank_deathknight', Frost: 'deathknight', Unholy: 'deathknight' },
  SHAMAN: { Elemental: 'elemental_shaman', Enhancement: 'enhancement_shaman', Restoration: 'restoration_shaman' },
  MAGE: { Arcane: 'mage', Fire: 'mage', 'Fire FFB': 'mage', Frost: 'mage' },
  WARLOCK: { Affliction: 'warlock', Demonology: 'warlock', Destruction: 'warlock' },
  DRUID: { Balance: 'balance_druid', 'Feral dps': 'feral_druid', 'Feral tank': 'feral_tank_druid', Restoration: 'restoration_druid' },
};
const tbcMissing = new Set(['holy_paladin', 'healing_priest', 'deathknight', 'tank_deathknight', 'restoration_shaman', 'restoration_druid']);
function lua(value) {
  if (typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return '{' + value.map(lua).join(',') + '}';
  return '{' + Object.entries(value).map(([key, item]) => '[' + JSON.stringify(key) + ']=' + lua(item)).join(',') + '}';
}

async function build() {
  const result = {};
  for (const [era, upstream] of Object.entries(sources)) {
    result[era] = {};
    for (const [classToken, specs] of Object.entries(bindings)) {
      for (const [spec, family] of Object.entries(specs)) {
        if (era === 'tbc' && tbcMissing.has(family)) continue;
        const path = `ui/${family}/sim.ts`, file = `.runtime/upstream-weights/${era}/${path.replaceAll('/', '_')}`;
        const url = `https://raw.githubusercontent.com/${upstream.repo}/${upstream.revision}/${path}`;
        if (process.argv.includes('--download')) {
          mkdirSync(`.runtime/upstream-weights/${era}`, { recursive: true });
          const response = await fetch(url);
          if (!response.ok) throw new Error('Download failed: ' + url);
          writeFileSync(file, await response.text());
        }
        const source = readFileSync(file, 'utf8');
        result[era][classToken] ||= {};
        result[era][classToken][spec] = { ...extractWeights(source), source: `${upstream.repo} / ${family}`,
          revision: upstream.revision, sha256: createHash('sha256').update(source).digest('hex'),
          historical: era !== 'wrath' };
      }
    }
  }
  writeFileSync('Data/ItemWeights.lua', 'local _, ns = ...\nns.ItemWeights = ' + lua(result) + '\n');
  process.stdout.write('Imported era-specific reference weights\n');
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await build();
