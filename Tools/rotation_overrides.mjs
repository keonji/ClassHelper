export const rotationOverrides = {
  'MAGE:Fire': { kind: 'priority', steps: [
    [55360, 'Обновляйте после взрыва бомбы.', 'Refresh after the bomb explodes.'],
    [42859, 'Только если группе нужен эффект улучшенного ожога.', 'Only if the raid needs Improved Scorch.'],
    [42891, 'Мгновенно при проке «Путь огня».', 'Instant cast with Hot Streak.'],
    [42833, 'Заполнитель между обновлениями и проками.', 'Filler between refreshes and procs.'],
  ] },
  'MAGE:Frost': { kind: 'combo', steps: [
    [42842, 'Комбинация под проком «Ледяные пальцы».', 'Combo during Fingers of Frost.'],
    [42842, 'Вторая ледяная стрела под тем же проком.', 'Second Frostbolt during the same proc.'],
    [44572, 'Сразу после второй стрелы; не универсальный цикл.', 'Immediately after the second Frostbolt; not a universal cycle.'],
  ] },
  'ROGUE:Assassination': { kind: 'cycle', steps: [
    [48666, 'При 1-3 приёмах набирайте приёмы; сохраняйте усиления.', 'Build combo points at 1-3 points; maintain buffs.'],
    [57993, 'При 4-5 приёмах после открытия боя.', 'At 4-5 combo points after the opener.'],
  ] },
  'ROGUE:Combat': { kind: 'priority', steps: [
    [6774, 'Поддерживайте мясорубку; нужны приёмы.', 'Maintain Slice and Dice; requires combo points.'],
    [48672, 'Поддерживайте кровотечение, учитывая число приёмов.', 'Maintain Rupture, considering available combo points.'],
    [48638, 'Набор приёмов, когда поддерживаемые эффекты не требуют обновления.', 'Build combo points when maintained effects need no refresh.'],
    [48668, 'Свободные приёмы, когда не нужно обновлять разрыв.', 'Spare combo points when Rupture needs no refresh.'],
  ] },
  'ROGUE:Subtlety': { kind: 'priority', steps: [
    [8647, 'Если ослабление брони не обеспечивает другой игрок.', 'If another player is not providing the armor debuff.'],
    [6774, 'Поддерживайте усиление; нужны приёмы.', 'Maintain the buff; requires combo points.'],
    [36554, 'Перед наложением разрыва.', 'Before applying Rupture.'],
    [48672, 'Поддерживайте кровотечение.', 'Maintain the bleed.'],
    [48668, 'Только свободные приёмы.', 'Only with spare combo points.'],
    [48660, 'Расход энергии, если завершающий приём сейчас не нужен.', 'Spend energy when no finisher is needed.'],
  ] },
  'PALADIN:Holy': { kind: 'decision', steps: [
    [53563, 'Поддерживайте частицу света на нужной цели.', 'Maintain Beacon of Light on the appropriate target.'],
    [53601, 'Поддерживайте священный щит.', 'Maintain Sacred Shield.'],
    [48825, 'Мгновенное лечение при перемещении или срочной необходимости.', 'Instant healing while moving or for urgent needs.'],
    [48782, 'Основное сильное лечение по получаемому урону.', 'Main large heal according to incoming damage.'],
    [48785, 'Более лёгкое лечение по ситуации и выбранному билду.', 'Lighter healing according to the situation and selected build.'],
  ] },
  'DEATHKNIGHT:Blood dps': { kind: 'priority', steps: [
    [49909, 'Если нет озноба.', 'If Frost Fever is missing.'],
    [49921, 'Если нет кровавой чумы.', 'If Blood Plague is missing.'],
    [50842, 'Обновление болезней только с соответствующим символом.', 'Refresh diseases only with the appropriate glyph.'],
    [49924, 'При доступных рунах и с учётом усилений комплекта.', 'With available runes, considering set effects.'],
    [55262, 'Основной расход кровавых рун.', 'Main Blood rune spender.'],
    [49895, 'Сброс силы рун, не мешающий окну танцующего оружия.', 'Runic-power dump without disrupting Dancing Rune Weapon.'],
  ] },
};
