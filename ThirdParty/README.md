# Imported recommendations

These are third-party data snapshots, not ClassHelper-authored BiS ratings.
Full license texts accompany the datasets; preserve them on redistribution.

## Class guides

Data/Imported/ClassGuides.lua contains concise summaries and talent/glyph
recommendations from [Icy Veins WotLK guides](https://www.icy-veins.com/wotlk-classic/class-guides),
©2011–2026 VEDATIS S.A.S., captured2026-10-19. The FAQ attribution conditions
described below apply; each record retains original URLs, dates and snapshot
hashes. Guide text is not relabeled MIT. Classic-only glyph changes are filtered
against the original3.3.5a client metadata. Talent and glyph pages are
level80 references only; equipment browsing remains available at60/70/80.

The Blood DPS talent/glyph preset comes from WoWSims WotLK revision
563e4a08cb15729f1fdcbcf68e6d68224553bfef, ui/deathknight/presets.ts,
under MIT (wowsims-weights-LICENSE.txt). Its priority summary references
ui/deathknight/apls/blood_dps.apl.json at the same revision.
Rebuild with `node Tools/import_class_guides.mjs` using the private source
snapshots and client DBCs documented in knowledge_base. No upstream
JavaScript or simulator code executes in the addon.

| Dataset | Source revision | License |
| --- | --- | --- |
| Classic60 | [Warkdev/BestInSlotClassic](https://github.com/Warkdev/BestInSlotClassic/tree/302ab4ecca0c86b43441710dab840af5edd3ca3e) | GPL-2.0, classic-LICENSE.txt |
| TBC70 | [mazarelo/tbc-bis-tracker](https://github.com/mazarelo/tbc-bis-tracker/tree/ebb38d1dd723ff1796c3d3c01d7d832438ad762a) | MIT, ©2024mazarelo, tbc-LICENSE.txt |
| Wrath80 | [Xidiuss/Bistooltip](https://github.com/Xidiuss/Bistooltip/tree/07c1321bfd07428168630aaf07389c2263e8f9a8) | MIT, ©2023Hellixoid, wrath-LICENSE.txt |

Classic data is derived from data/bis_data.lua and data/items.lua. The upstream
project credits class-community theorycrafters and their spreadsheets in its
[README](https://github.com/Warkdev/BestInSlotClassic/tree/302ab4ecca0c86b43441710dab840af5edd3ca3e#credits).
Its GPL notice applies to the derived Classic dataset; it is not relabeled MIT.

TBC data comes from the project's published database.json, which attributes its
rankings to Wowhead TBC Classic guides and some Icy Veins guides. Shared source
lists and absent source specializations are not independently recalculated.

Wrath uses the bundled WoWSimsBP snapshot, retaining the backport lineage
credited by upstream: Silver/DisruptionAuras, disruption01, ExoJdi and Divian.
No third-party addon executable code or libraries are loaded by ClassHelper.

Eligibility metadata contains only required level, class/race/faction masks and
inventory type for referenced IDs, derived from AzerothCore item_template at
4d9d1d4b5723e819c5c390f6ca1177283dbfb8e3. It is not a local item-stat database
and does not calculate gear rankings. Item names/icons still use the client.

Rebuild with `node Tools/import_bis.mjs --download` from the project root.
Downloads are pinned to revisions and checked against SHA256 before decoding.
Later rebuilds can use `node Tools/import_bis.mjs` with the local cache only.
Node and LuaJIT are development tools, not runtime addon dependencies.

## PvP gear selections

Data/Imported/PvP.lua contains gear selections copied from Icy Veins,
©2011–2026 VEDATIS S.A.S., captured on2026-10-19. Each build retains its
original page URL, heading and SHA256 of the compact DOM snapshot. The source
URL is displayed in the addon; preserve attribution and source links.
[Icy Veins FAQ](https://www.icy-veins.com/faq) permits copying with clear
attribution and a visible link to the original page. This is not an MIT
license or a claim of open-source licensing for the website's material.

Source hubs: [Classic](https://www.icy-veins.com/wow-classic/wow-classic-pvp-guides),
[TBC](https://www.icy-veins.com/tbc-classic/pvp-guides),
[Wrath](https://www.icy-veins.com/wotlk-classic/pvp-guides).
Only gear IDs, source labels and table headings are imported, not guide prose.
These are source recommendations, not per-item ranks or personal simulations.
Shared class guides are disclosed; missing seasons are not reconstructed.
Rebuild using `node Tools/import_pvp.mjs` with compact DOM snapshots in
.runtime/upstream-pvp and the existing pinned AzerothCore item SQL.
Warcraft Tavern content is not included.

## Default stat weights

Data/ItemWeights.lua adapts the published default gear-picker EP weights from
[wowsims/wotlk](https://github.com/wowsims/wotlk/tree/563e4a08cb15729f1fdcbcf68e6d68224553bfef),
revision563e4a08cb15729f1fdcbcf68e6d68224553bfef, under MIT
(©2022wowsims team; wowsims-weights-LICENSE.txt).
Sources: ui/retribution_paladin/sim.ts defaults.epWeights and
ui/mage/sim.ts defaults.epWeights (Fire preset). Shared Ret hit/crit/haste
ratings sum their melee and spell contributions once. Weapon DPS weights
are not used: weapons, trinkets and relics retain published source ranking.
These are fixed reference weights, not personal simulations or DPS gains.

The expanded importer `node Tools/import_weights.mjs` reads cached pinned
class-page default EP maps for all33Wrath spec identities. The default map
of a shared class page is explicitly a shared reference, not a separately
simulated scale for each specialization. Source path/revision/content SHA256
are retained in each runtime record. Local cache hashes are recorded, not
validated against a separate manifest.

TBC reference maps (24identities) are from wowsims/tbc revision
3301fca59306a747e521274c36e073e69acc7b77, ui/<class-page>/sim.ts,
under the accompanying wowsims-tbc-weights-LICENSE.txt. They are marked
historical and not automatically scored on the3.3.5a client. In particular,
historical flat armor penetration is not equivalent to Wrath rating.
Classic/SoD weights are not substituted for Vanilla. Unsupported mappings
(including separate bonus armor) retain published BiS source highlighting.
Use `--download` to fetch immutable source URLs before rebuilding.
