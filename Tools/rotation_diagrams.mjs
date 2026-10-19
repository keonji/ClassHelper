export function diagramFromSnapshot(snapshot, metadata) {
  let heading = '';
  for (const block of snapshot.blocks) {
    if (/^H/.test(block.type)) { heading = block.text; continue; }
    if (block.type !== 'OL' || !/single.target|spell priority/i.test(heading) || /aoe|multi.target/i.test(heading)) continue;
    if (/pre-?pot|precast|before (the )?pull/i.test(block.text)) continue;
    const links = block.links.map(link => ({ ...link, spellID: Number(link.href.match(/spell[\/=](\d+)/)?.[1]) }));
    const steps = [];
    for (const line of block.text.split('\n')) {
      const actionText = line.replace(/^After [^,]+,\s*/i, '');
      const action = links.filter(link => actionText.includes(link.text) && metadata.spells[link.spellID]
        && !metadata.spells[link.spellID].passive
        && link.spellID !== 62124).sort((a, b) => actionText.indexOf(a.text) - actionText.indexOf(b.text))[0];
      if (!action) continue;
      steps.push({ spellID: action.spellID, name: action.text, icon: metadata.spells[action.spellID].icon, condition: line });
    }
    if (steps.length > 1) return { kind: 'priority', heading, steps };
  }
}
