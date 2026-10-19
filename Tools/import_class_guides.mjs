import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { loadMetadata, validateBuild } from './class_guide_metadata.mjs';
import { summaries, pvpSummaries } from './class_guide_summaries.mjs';
import { diagramFromSnapshot } from './rotation_diagrams.mjs';
import { rotationOverrides } from './rotation_overrides.mjs';
import { pvpDiagram } from './pvp_diagrams.mjs';

const root = '.runtime/upstream-class-guides/';
const metadata = loadMetadata();
const records = {}, report = [];
const digest = raw => createHash('sha256').update(raw).digest('hex');
const norm = text => text.toLowerCase().replace(/[’‘]/g, "'").replace(/\s+/g, ' ').trim();
const glyphNames = new Map(Object.entries(metadata.glyphs).map(([id, g]) => [norm(g.name), Number(id)]));
// The published DK enum identifies the minor glyph; SQL also retains an obsolete namesake.
glyphNames.set('glyph of raise dead', 43673);
function identify(url) {
  const slug = url.split('/').at(-1);
  const token = ['death-knight', 'warrior', 'paladin', 'hunter', 'rogue', 'priest', 'shaman', 'mage', 'warlock', 'druid'].find(x => slug.includes(x));
  const classToken = token.replace('-', '').toUpperCase();
  const names = { blood: 'Blood tank', frost: 'Frost', unholy: 'Unholy', balance: 'Balance', feral: slug.includes('-tank-') ? 'Feral tank' : 'Feral dps',
    restoration: 'Restoration', 'beast-mastery': 'Beast mastery', marksmanship: 'Marksmanship', survival: 'Survival', arcane: 'Arcane', fire: 'Fire',
    holy: 'Holy', protection: 'Protection', retribution: 'Retribution', discipline: 'Discipline', shadow: 'Shadow', assassination: 'Assassination',
    combat: 'Combat', subtlety: 'Subtlety', elemental: 'Elemental', enhancement: 'Enhancement', affliction: 'Affliction', demonology: 'Demonology',
    destruction: 'Destruction', arms: 'Arms', fury: 'Fury' };
  const spec = Object.keys(names).find(x => slug.startsWith(x + '-'));
  if (!spec) throw new Error('Unknown spec: ' + url);
  return { classToken, sourceSpec: names[spec] };
}
function source(file) {
  const raw = readFileSync(root + file, 'utf8');
  const snapshot = JSON.parse(raw);
  return { snapshot, reference: { url: snapshot.url, sha256: digest(raw), date: '2026-10-19' } };
}
function excerpt(text, words = 60) { return text.replace(/\s+/g, ' ').trim().split(' ').slice(0, words).join(' '); }
function overview(snapshot) {
  let heading = '', lists = [];
  for (const block of snapshot.blocks) {
    if (/^H/.test(block.type)) heading = block.text;
    else if (/strength.*weakness/i.test(heading) && block.type === 'UL') lists.push(excerpt(block.text, 40));
  }
  const paragraph = snapshot.blocks.find(b => b.type === 'P' && b.text.length > 100 && !/On this page|Welcome|Last updated|Pages in/.test(b.text));
  return [paragraph ? excerpt(paragraph.text, 45) : '', lists[0] || '', lists[1] || ''];
}
for (const entry of JSON.parse(readFileSync(root + 'pve-index.json', 'utf8'))) {
  const { snapshot, reference } = source(entry.file);
  const identity = identify(entry.url), key = identity.classToken + ':' + identity.sourceSpec;
  records[key] = { ...identity, role: /-healer-/.test(entry.url) ? 'healer' : /-tank-/.test(entry.url) ? 'tank' : ['HUNTER', 'MAGE', 'PRIEST', 'WARLOCK'].includes(identity.classToken) || identity.sourceSpec === 'Balance' || identity.sourceSpec === 'Elemental' ? 'ranged' : 'melee',
    pve: { overview: { ruRU: summaries[key]?.slice(0, 3) || [], enUS: overview(snapshot) }, rotation: { ruRU: summaries[key]?.[3] || '', enUS: '' }, builds: [], sources: [reference] } };
}
for (const [indexFile, mode] of [['detail-index.json', 'pve'], ['pvp-index.json', 'pvp']]) {
  for (const entry of JSON.parse(readFileSync(root + indexFile, 'utf8'))) {
    const { snapshot, reference } = source(entry.file);
    const identity = identify(entry.url), key = identity.classToken + ':' + identity.sourceSpec;
    const record = records[key];
    if (!record) throw new Error('Missing overview: ' + key);
    record[mode] ||= { overview: { ruRU: pvpSummaries[key]?.slice(0, 3) || [], enUS: overview(snapshot) },
      rotation: { ruRU: pvpSummaries[key]?.[3] || '', enUS: '' }, builds: [], sources: [] };
    const target = record[mode];
    target.sources.push(reference);
    if (/rotation/.test(entry.url) || mode === 'pvp') {
      target.rotationDiagram = mode === 'pve' ? diagramFromSnapshot(snapshot, metadata) : pvpDiagram(key, snapshot, metadata);
      let heading = '';
      const sections = [];
      for (const block of snapshot.blocks) {
        if (/^H/.test(block.type)) heading = block.text;
        else if (/rotation|priority|dealing damage|playstyle|single.target/i.test(heading) && ['OL', 'UL', 'P'].includes(block.type)
          && block.text.length > 60 && !/\/cast|#showtooltip|Pages in|Welcome to|We recommend|We will be presenting/.test(block.text)) {
          sections.push(block.text);
        }
      }
      target.rotation.enUS = excerpt(sections.join(' '), 140);
    }
    for (const [i, build] of (snapshot.builds || []).entries()) {
      if (build.trees?.length !== 3 || build.trees.some((tree, t) => tree.talents.length !== metadata.trees[identity.classToken][t].length
        || tree.talents.some((talent, j) => talent.max !== metadata.trees[identity.classToken][t][j].maxRank))) {
        report.push({ key, mode, url: entry.url, variant: i, errors: ['Talent tree shape mismatch'] }); continue;
      }
      const talentsString = build.trees.map(t => t.talents.map(x => x.rank).join('').replace(/0+$/, '')).join('-');
      const validation = validateBuild({ ...identity, talentsString, glyphs: [] }, 80, metadata);
      let selectedGlyphs = build.glyphNames || [];
      if (key === 'PALADIN:Retribution' && mode === 'pve') {
        const minorNames = [...glyphNames.keys()].filter(name => metadata.glyphs[glyphNames.get(name)].category === 'minor'
          && snapshot.blocks.some(b => b.type === 'P' && norm(b.text).startsWith(name + ' ')));
        selectedGlyphs = [...new Set([...selectedGlyphs, ...minorNames.map(name => metadata.glyphs[glyphNames.get(name)].name)])];
      }
      if (mode === 'pvp' && identity.classToken === 'PALADIN') {
        const paragraph = snapshot.blocks.find(b => b.type === 'P' && /^For [Gg]lyphs/.test(b.text));
        if (paragraph) selectedGlyphs = [...glyphNames.keys()].filter(name => norm(paragraph.text).includes(name))
          .map(name => metadata.glyphs[glyphNames.get(name)].name);
      }
      const ids = selectedGlyphs.map(name => glyphNames.get(norm(name)));
      const glyphIssues = selectedGlyphs.filter((_, j) => !ids[j]);
      if (!validation.valid) { report.push({ key, mode, url: entry.url, variant: i, errors: validation.errors }); continue; }
      const glyphs = ids.filter(Boolean).map(id => ({ itemID: id, ...metadata.glyphs[id], nameRu: metadata.spells[metadata.glyphs[id].spellID]?.name }));
      const glyphValidation = validateBuild({ ...identity, talentsString, glyphs: ids.filter(Boolean) }, 80, metadata);
      if (!glyphValidation.valid) glyphIssues.push(...glyphValidation.errors);
      const allocations = validation.allocations.map(a => ({ ...a,
        name: build.trees[a.tree - 1].talents[metadata.trees[identity.classToken][a.tree - 1].findIndex(t => t.id === a.talentID)].name,
        nameRu: metadata.spells[a.spellID]?.name }));
      const treePoints = build.trees.map(t => t.talents.reduce((sum, talent) => sum + talent.rank, 0)).join('/');
      let title = (build.title || 'Source build') + ' (' + treePoints + ')', titleRu, notes;
      if (key === 'PALADIN:Retribution' && mode === 'pve') {
        const mastery = allocations.some(a => a.spellID === 31821);
        title = mastery ? 'Personal damage + Aura Mastery' : 'Raid utility + Divine Sacrifice';
        titleRu = mastery ? 'Личный урон + Мастер аур' : 'Защита рейда + Божественная жертва';
        notes = { ruRU: mastery ? 'Источник: очки в Свете усиливают личный урон и дают Мастера аур.'
          : 'Источник: очки в Защите дают Божественную жертву ценой личного урона. Выбор зависит от потребностей рейда.',
          enUS: mastery ? 'Holy investment favors personal damage while retaining Aura Mastery.'
          : 'Protection investment trades personal damage for Divine Sacrifice; choose according to raid needs.' };
      }
      target.builds.push({ key: mode + '_' + target.builds.length, title, titleRu, notes, talentsString,
        targetLevel: 80, points: validation.points, allocations, glyphs: glyphValidation.valid ? glyphs : [], glyphIssues,
        trees: build.trees.map(t => t.name), source: reference.url, calculator: build.link || reference.url });
    }
  }
}
const fire = structuredClone(records['MAGE:Fire']);
fire.sourceSpec = 'Fire FFB';
fire.pve.overview.ruRU[0] = 'Вариант огненного мага со стрелой ледяного огня; выбор билда должен соответствовать основному заклинанию.';
fire.pve.rotation.ruRU = fire.pve.rotation.ruRU.replace('огненный шар', 'стрела ледяного огня');
fire.pve.builds = fire.pve.builds.filter(b => b.talentsString.split('-')[2].split('').reduce((n, x) => n + Number(x), 0) >= 17);
delete fire.pvp;
records['MAGE:Fire FFB'] = fire;
const bloodFile = '.runtime/upstream-weights/wrath/ui_deathknight_presets.ts';
const bloodRaw = readFileSync(bloodFile, 'utf8');
const bloodPreset = bloodRaw.match(/export const BloodTalents[\s\S]*?\n};/)[0];
const bloodCode = bloodPreset.match(/talentsString: '([^']+)'/)[1];
const bloodNames = [...bloodPreset.matchAll(/Deathknight(?:Major|Minor)Glyph\.GlyphOf(\w+)/g)]
  .map(match => 'Glyph of ' + match[1].replace(/([a-z])([A-Z])/g, '$1 $2'));
const bloodIDs = bloodNames.map(name => glyphNames.get(norm(name)));
const bloodValid = validateBuild({ classToken: 'DEATHKNIGHT', talentsString: bloodCode, glyphs: bloodIDs }, 80, metadata);
if (!bloodValid.valid) throw new Error('Blood DPS preset: ' + bloodValid.errors.join('; '));
const bloodSource = 'https://github.com/wowsims/wotlk/blob/563e4a08cb15729f1fdcbcf68e6d68224553bfef/ui/deathknight/presets.ts';
const bloodRotation = 'https://github.com/wowsims/wotlk/blob/563e4a08cb15729f1fdcbcf68e6d68224553bfef/ui/deathknight/apls/blood_dps.apl.json';
records['DEATHKNIGHT:Blood dps'] = {
  classToken: 'DEATHKNIGHT', sourceSpec: 'Blood dps', role: 'melee', pve: {
    overview: {
      ruRU: ['Кровь — вариант рыцаря смерти для урона в ближнем бою. Здесь готовый DPS-пресет WoWSims, не танковый билд.',
        'Удар в сердце, удар смерти и отдельное окно урона с танцующим руническим оружием.',
        'Требует контроля болезней, рун и силы рун. Пресет не доказывает превосходство над другими специализациями; стартовые задания DK влияют на доступные очки.'],
      enUS: ['Blood melee DPS using the published WoWSims preset, not a tank build.',
        'Heart Strike, Death Strike and a Dancing Rune Weapon damage window.',
        'Requires disease, rune and runic-power management. This preset does not establish superiority over other specs; DK starting quests affect available points.'],
    },
    rotation: {
      ruRU: 'Поддерживайте обе болезни. Обновляйте их мором с соответствующим символом; используйте удар смерти и удар в сердце, не теряйте силу рун у предела. Согласуйте истерию, вурдалака и танцующее руническое оружие с усилениями. Лик смерти — расход силы рун, когда основные руны восстанавливаются. Точные условия и особенности комплекта смотрите в APL источника.',
      enUS: 'Maintain both diseases and refresh with glyphed Pestilence. Use Death Strike and Heart Strike while avoiding runic-power waste. Coordinate Hysteria, Raise Dead and Dancing Rune Weapon with buffs; use Death Coil during rune downtime. See the source APL for precise conditions and set-specific behavior.',
    },
    sources: [{ url: bloodSource, sha256: digest(bloodRaw), date: '2026-10-19' }, { url: bloodRotation, date: '2026-10-19' }],
    builds: [{ key: 'pve_blood_dps', title: 'Blood DPS', titleRu: 'Кровь - урон', targetLevel: 80, talentsString: bloodCode, points: bloodValid.points,
      allocations: bloodValid.allocations.map(a => ({ ...a, name: metadata.spells[a.spellID].nameEn, nameRu: metadata.spells[a.spellID].name })),
      glyphs: bloodIDs.map(id => ({ itemID: id, ...metadata.glyphs[id], nameRu: metadata.spells[metadata.glyphs[id].spellID].name })),
      glyphIssues: [], trees: ['Blood', 'Frost', 'Unholy'], source: bloodSource, calculator: bloodSource }],
  },
};
for (const [identity, definition] of Object.entries(rotationOverrides)) {
  const target = records[identity]?.pve;
  if (!target || target.rotationDiagram) continue;
  target.rotationDiagram = { kind: definition.kind, steps: definition.steps.map(([spellID, ruRU, enUS]) => {
    const spell = metadata.spells[spellID];
    if (!spell || spell.passive || !spell.icon) throw new Error('Invalid rotation spell: ' + spellID);
    return { spellID, name: spell.nameEn || spell.name, icon: spell.icon, condition: enUS, conditionRu: ruRU,
      ffbIcon: spellID === 42833 ? metadata.spells[47610].icon : undefined };
  }) };
}
if (records['MAGE:Fire'].pve.rotationDiagram) {
  const ffbDiagram = structuredClone(records['MAGE:Fire'].pve.rotationDiagram);
  for (const step of ffbDiagram.steps) if (step.spellID === 42833) Object.assign(step,
    { spellID: 47610, icon: metadata.spells[47610].icon, name: metadata.spells[47610].nameEn });
  records['MAGE:Fire FFB'].pve.rotationDiagram = ffbDiagram;
}
function lua(value) {
  if (value === null || value === undefined) return 'nil';
  if (typeof value === 'string') return JSON.stringify(value).replace(/\\u([0-9a-f]{4})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return '{' + value.map(lua).join(',') + '}';
  return '{' + Object.entries(value).filter(([, v]) => v !== undefined).map(([k, v]) => `[${lua(k)}]=${lua(v)}`).join(',') + '}';
}
const catalog = Object.fromEntries(Object.entries(metadata.trees).map(([classToken, trees]) => [classToken,
  trees.map((talents, index) => ({ ...metadata.treeDetails[classToken][index],
    name: Object.values(records).find(r => r.classToken === classToken)?.pve.builds[0]?.trees[index] || metadata.treeDetails[classToken][index].nameRu,
    talents: talents.map(t => ({ ...t,
    name: metadata.spells[t.spells[0]]?.nameEn, nameRu: metadata.spells[t.spells[0]]?.name, icon: metadata.spells[t.spells[0]]?.icon })) }))]));
writeFileSync('Data/Imported/ClassGuides.lua', 'local _, ns = ...\nns.ClassGuideData=' + lua(records) + '\nns.TalentCatalog=' + lua(catalog) + '\n');
writeFileSync('.runtime/class-guides-validation.json', JSON.stringify({ records: Object.keys(records).length, rejected: report,
  coverage: Object.entries(records).map(([key, r]) => ({ key, pve: r.pve?.builds.length || 0, pvp: r.pvp?.builds.length || 0 })) }, null, 2));
console.log(JSON.stringify({ records: Object.keys(records).length, acceptedBuilds: Object.values(records).reduce((n, r) => n + (r.pve?.builds.length || 0) + (r.pvp?.builds.length || 0), 0), rejected: report.length }));
writeFileSync('.runtime/rotation-icons.json', JSON.stringify([...new Set(Object.values(records).flatMap(r => ['pve', 'pvp'].flatMap(mode => r[mode]?.rotationDiagram?.steps.map(s => s.icon) || [])))]));
