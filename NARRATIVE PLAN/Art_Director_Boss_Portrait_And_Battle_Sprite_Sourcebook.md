# Legends of Aurelia — Art Director Sourcebook (Boss Portraits + Battle Sprites)

**Single file for art direction and prompts.** Named bosses only (no generic enemies).  
**Scope:** UI / dialogue portraits and full-body tactical battle sprites.

**How to use (3 steps)**

1. Read **Global art direction** and **Faction colors** below.
2. Open the boss’s section. Check **Delivery status** (skip or replace if already shipped).
3. **Portrait:** copy the **Master portrait block**, then copy that boss’s **Portrait — paste after master** line(s).  
   **Battle sprite:** copy the **Master battle sprite block**, then copy **Battle sprite — paste after master**.

**Export paths (Godot):** portraits `res://Assets/Portraits/<filename>.png` · battle sprites `res://Assets/Sprites/<filename>.png`

**Maintenance:** This book merges content from `Gemini_Boss_Enemy_Prompt_Bible.txt` and `Boss_Artstyle_Production_Sheet.txt`. Prefer updating **this** file for boss portrait/sprite work; keep the other two in sync when you change prompts or pillars.

---

## Delivery status (already on disk)

| Boss | Portrait | Battle sprite |
|------|----------|----------------|
| The Ash Adjudicator | `Ash Adjudicator Portrait.png` | `Ash Adjudicator Battle Sprite.png` |
| Mortivar Hale | `Mortivar Hale Portrait.png` | `Mortivar Hale Battle Sprite.png` |
| Mother Caldris Vein | `Mother Caldris Vein Portrait.png` | `Mother Caldris Vein Battle Sprite.png` |
| Noemi Veyr | `Noemi Veyr Portrait.png` | `Noemi Veyr Battle sprite.png` |
| Port-Master Rhex Valcero | `Port-Master Rhex Valcero Portrait.png` | `Port-Master Rhex Valcero Battle Sprite.png` |

**Lady Vespera:** narrative expression portraits exist (`vespera.png`, `vespera_smirk.png`, …) — not the same as a paired **tactical** portrait + battle sprite for combat UI.

Shipped assets still must match **global pillars** and that boss’s **art direction** if you revise or variant them.

---

## Global art direction

### Visual pillars

- Base style: gritty dark-fantasy **pixel art** with crisp readability at tactical zoom.
- Rendering feel: high-contrast shadows, controlled palette, grounded materials.
- Silhouettes may be dramatic; gear stays physically plausible unless intentionally cosmic/aberrant.
- Weapon, stance, and threat type identifiable at a glance.
- Each boss: at least one unique silhouette trait + one unique VFX language.

### Tier hierarchy

- **Chapter boss:** strong single-theme silhouette + one map-identity VFX cue.
- **Recurring rival:** stable core design; escalate corruption/ornament each return.
- **Endgame / cosmic:** may break normal human readability; keep gameplay legibility.

### Faction color languages

- **Valeron hardline / purifiers:** ivory, silver, deep blue, sanctified gold accents.
- **Merchant League predator elite:** lacquer black, deep burgundy, coin-gold, polished steel.
- **Obsidian Circle / void occult:** ash black, bruise-violet, sickly green, bone-white accents.
- **Frontier warlords / opportunists:** weathered iron, mud-leather, smoke brown, worn heraldic remnants.
- **Cosmic manifestation:** bone / void-glass / parchment-flesh hybrids; anti-human highlight logic.

### Production gate (readability)

- Boss archetype identifiable in under ~1 second at tactical zoom?
- Silhouette unique in grayscale?
- Boss VFX language not shared by fodder?
- Weapon/ability identity readable without UI text?
- Chapter progression shows visible escalation?

---

## World tone (optional prefix for generators)

Late-medieval / early-Renaissance fantasy realm at war. Factions: militant church-state (Valeron), predatory merchant league, occult rift cultists (Obsidian Circle), frontier loggers and wardens, drowning cosmic forces (Dark Tide).

---

## Master portrait block

Copy this **first** for every portrait.

Dark fantasy **character portrait**. Chest-up or waist-up, centered composition; face clearly readable at small UI scale (~35–45% of frame height). Slight three-quarter turn OK. High-contrast lighting on face and eyes, grounded materials (metal, cloth, leather, ritual details). Painterly or high-quality illustration for concepting; final in-game target remains **readable dark-fantasy pixel** per pillars above. NOT chibi, NOT gacha, NOT Fortnite, NOT photorealistic stock photo. No modern clothing, logos, or sci-fi tech. Serious adult tone. Hands only if simple (book edge, staff rest). Clean background or soft abstract mood (smoke, sigils, bokeh) — not busy scenery. No text or watermarks.

---

## Master battle sprite block

Copy this **first** for every battle sprite.

Dark fantasy **full-body tactical battle illustration**. Entire figure head to toe; strong readable silhouette; weapon and armor role obvious at a glance. Dynamic combat-ready or commanding stance; feet planted; believable weight. Simple ground plane or subtle shadow; optional faint hex-grid or stone floor — **no UI frames, no stat text**. Slight isometric-friendly or three-quarter front (JRPG battle convention OK). Grounded materials; controlled palette; in-game target **pixel-readable** per pillars. NOT chibi, NOT gacha, NOT Fortnite. No modern items. No text or watermarks.

---

## Negative prompt add-on (optional tail for generators)

text, watermark, logo, modern clothing, smartphone, sci-fi visor, low quality, deformed hands, extra fingers, blurry face, childlike proportions, chibi, gacha, Fortnite style, oversaturated neon, comic slapstick.

---

## Boss index (canonical display names — match game data)

| # | Name |
|---|------|
| 01 | Lady Vespera |
| 02 | Vespera Ascendant |
| 03 | Master Enric |
| 04 | Captain Selene |
| 05 | Ephrem the Zealot |
| 06 | Mother Caldris Vein |
| 07 | Port-Master Rhex Valcero |
| 08 | Mortivar Hale |
| 09 | Preceptor Cassian Vow |
| 10 | Auditor Nerez Sable |
| 11 | Juno Kest |
| 12 | Lord Septen Harrow |
| 13 | Thorn-Captain Edda Fen |
| 14 | Justicar Halwen Serast |
| 15 | Noemi Veyr |
| 16 | Provost Serik Quill |
| 17 | Roen Halbrecht |
| 18 | The Ash Adjudicator |
| 19 | Duke Alric Thornmere |
| 20 | Naeva, Marrow-Seer of the Dark Tide |
| 21 | The Witness Without Eyes |

---

## 01 — Lady Vespera

**Delivery:** Tactical portrait + battle sprite **not** in the “finished pairs” table; narrative `vespera*.png` portraits exist separately.

**Art direction:** Obsidian Circle · Levels 1, 18, 19 · Silhouette: ceremonial high-collar authority, occult asymmetry as she escalates · Materials: void-weave cloth, ritual metal, fractured relic · Palette: black-violet, blood-red accents, cold lunar edge light · VFX: rift bloom, ash, altar pulses · Motion: priestly stillness → burst violence · Avoid: generic “evil sorceress” glamour without gravitas.

**Portrait — paste after master:** Lady Vespera, formidable antagonist priestess of a rift cult. High ceremonial collar, asymmetrical occult detail, void-weave fabrics, fractured ritual metal at shoulders or throat. Palette: black-violet, controlled blood-red accents, cold lunar rim light on face. Expression: intelligent, patient cruelty; eyes that judge. Faint ash and rift bloom at frame edges only.

**Battle sprite — paste after master:** Lady Vespera full body, ritual caster stance: one hand on open Rift Rite Tome, other hand raised with gathering void flame. Long ceremonial layers with asymmetrical occult trim; hem and sleeves readable in silhouette. Black-violet and ember accent; ash particles minimal. Ground shadow only; commanding, still-before-storm posture.

**Avoid (prompt):** generic “sexy sorceress”, pin-up, cartoon evil queen, Sauron pastiche.

**Notes:** Apparition = softer, more translucent; late game = sharper armor, harder light.

---

## 02 — Vespera Ascendant

**Delivery:** Not in finished pairs table (tactical set still follows this card if needed).

**Art direction:** Same faction language as Lady Vespera (Obsidian Circle / void); treat as **endgame escalation**: cosmic asymmetry, void stride, tragic ambition. Align with § Tier hierarchy “endgame/cosmic” while keeping face/figure readable.

**Portrait — paste after master:** Vespera Ascendant, void-touched woman: ecstasy and terror in the same expression; pale skin; unnatural highlight under eyes and cheekbones. Hair and ritual collar disturbed by invisible wind. Subtle geometry fracture or void crack **only at edges** of frame. Black-violet core light on face; keep facial anatomy clear.

**Battle sprite — paste after master:** Vespera Ascendant full body, ascendant mage-warrior: fused ritual robes and armored panels, torn elegance, tome chained or fused to belt. Rift energy at hands and spine silhouette; cloth lifting unnaturally. Strong asymmetric silhouette; void particles; feet visible, aggressive float-step or lunging cast pose. Epic tragic, not generic monster.

**Avoid (prompt):** pure silhouette blob; anime aura-only body; lose material texture.

---

## 03 — Master Enric

**Art direction:** Obsidian Circle · Level 15 · Silhouette: scholar-necromancer, burdened frame, ritual apparatus · Materials: damp rot fabrics, bindings, tools · Palette: marsh green, dead brown, corpse-grey · VFX: rot spores, husk trails, mire rings · Motion: precise, economical; puppetry over brute force · Avoid: cartoon plague wizard.

**Portrait — paste after master:** Master Enric, male scholar-necromancer: slight stooped burden, damp stained robes, old strap bindings at collar. Face: fascinated, clinical calm; tired eyes. Marsh green and corpse-grey palette; soft underlight like corpse-candle; faint spore motes **not** obscuring face.

**Battle sprite — paste after master:** Master Enric full body, hunched scholar stance: clutching Grave Thesis tome in both hands or one hand extended with rot mire effect from fingers. Robes weighted with damp hem, tool belt with ritual implements. Boots in mud splash; green-brown-grey palette; precise small gesture, not brawler.

**Avoid (prompt):** cartoon plague doctor; silly slime; oversized WoW shoulders.

---

## 04 — Captain Selene

**Art direction:** Vespera-aligned elite · Levels 13, 18 · Silhouette: elite duelist/commander; sharp cape and blade · Materials: refined plate, field wear, insignia · Palette: steel, midnight blue, restrained crimson accent · VFX: clean slash arcs, command flashes · Motion: fast, minimal waste · Avoid: over-ornament hiding role.

**Portrait — paste after master:** Captain Selene, female elite commander: sharp jaw, cold focus; short or tied-back hair; midnight blue and steel palette. Fitted high collar or gorget; hint of twin knife hilts at shoulders. Restrained crimson accent **one element only**. Expression: unimpressed, lethal patience.

**Battle sprite — paste after master:** Captain Selene full body, low combat stance, twin shadowglass knives forward, cape or half-cape as **sharp diagonal** silhouette. Sleek dark armor panels; weight on front foot; arena-neutral floor. Minimal motion blur — readability first. Steel, midnight blue, one crimson edge light.

**Avoid (prompt):** armor so ornate it hides pose; clutter; twin daggers lost in busy FX.

---

## 05 — Ephrem the Zealot

**Art direction:** Fallen Valeron · Level 3 · Silhouette: austere executioner; rigid icon profile · Materials: liturgical armor, cinder-marked cloth · Palette: sanctified ivory scorched by ember orange · VFX: cinder brands, devotion flare · Motion: prayer windup → violent strikes · Avoid: comic fanatic.

**Portrait — paste after master:** Ephrem the Zealot, male militant monk: austere face, shaved or severe hair; cinder-scorch marks on ivory liturgical cloth at neck. Ember-orange catch light in eyes; optional faint brand glow at brow. Expression: fanatic clarity, calm not frothing.

**Battle sprite — paste after master:** Ephrem full body, wide martial stance, censer rod or chain-censer swung ready; scorched white-and-ember robes over light armor. Feet wide; ash falling; ember motes at hands. Silhouette: vertical monk-warrior, readable weapon arc.

**Avoid (prompt):** comical preacher; clown face; cartoon fire beard.

---

## 06 — Mother Caldris Vein

**Delivery:** **DONE** — see Delivery status table.

**Art direction:** Valeron Purifiers · Levels 2, 10, 17 · Silhouette: severe ecclesial authority, weaponized sanctity · Materials: pristine holy regalia, punitive iconography · Palette: white/gold over cold steel, controlled blood-red punish accents · VFX: judgment sigils, restraint circles, cleansing flares · Motion: tribunal composure → punishment · Avoid: soft healer read.

**Portrait — paste after master:** Mother Caldris Vein, severe matriarch inquisitor: pristine white-gold regalia with punitive iconography (chains, nails motif — symbolic not gore). Cold courtroom top light; steel at throat. Expression: calm surgical moral authority; eyes that sentence.

**Battle sprite — paste after master:** Mother Caldris full body, upright tribunal stance, Silence Staff vertical before her or thrust to command; long punitive vestments over armored skirt/plates; white-gold-cold-steel palette; faint restraint-circle suggestion on ground (abstract). Heavy vertical silhouette.

**Avoid (prompt):** warm motherly healer; soft pastel saint.

---

## 07 — Port-Master Rhex Valcero

**Delivery:** **DONE** — see Delivery status table.

**Art direction:** Merchant League · Levels 4, 5 · Silhouette: broad mercantile warlord · Materials: naval coat over armored core, coin-chain · Palette: tar black, brass gold, dock-rust red · VFX: alarm/net, paid reinforcements, ballistic sparks · Motion: command beats, heavy firearm actions · Avoid: pirate caricature.

**Portrait — paste after master:** Port-Master Rhex Valcero, imposing male dock magnate: expensive naval greatcoat collar and brass buttons; coin or seal chain at chest; weathered confident face; smiling predator eyes. Tar black, brass gold, rust-red accents. Soft harbor fog background blur.

**Battle sprite — paste after master:** Rhex full body, wide planted stance, Broker’s Handgonne raised in one hand, other hand on coat lapel or belt of seals. Heavy coat tails readable in silhouette; armored core under coat; dock plank or rope-shadow ground. Broad “merchant warlord” read.

**Avoid (prompt):** pirate Halloween; Jack Sparrow.

---

## 08 — Mortivar Hale

**Delivery:** **DONE** — see Delivery status table.

**Art direction:** Obsidian Circle military · Levels 6, 14 · Silhouette: grave-knight commander, death-parade authority · Materials: funerary plate, ossified trim · Palette: iron-black, bone ash, gravefire cyan · VFX: muster circles, revenant wake, tomb-light · Motion: marching inevitability · Avoid: generic skeleton lord.

**Portrait — paste after master:** Mortivar Hale, male death-marshal: funerary plate helm **partially open** or visor up so face is visible — grey skin or deathly pallor, piercing tired command. Ossified trim on pauldrons; cyan gravefire reflection in eye sockets or cheek. Iron-black and bone-ash palette.

**Battle sprite — paste after master:** Mortivar Hale full body in funerary full plate, tattered parade cloak, blackened lance held in command point or brace for charge. Cyan accent glow at joints/eyesocket; heavy vertical knight silhouette; mist at boots. Parade-ground or ash field ground shadow.

**Avoid (prompt):** skeleton king cliché; skull pile throne.

---

## 09 — Preceptor Cassian Vow

**Art direction:** Valeron hardliners · Levels 9A, 17 · Silhouette: tall doctrinal inquisitor · Materials: armor-cloth hybrid, legal-seal motifs · Palette: ivory/blue, cold gold · VFX: silence fields, restraint lines, sanction flashes · Motion: cold legalistic gestures · Avoid: flamboyant paladin.

**Portrait — paste after master:** Preceptor Cassian Vow, tall severe male inquisitor: ceremonial armor-cloth hybrid at shoulders; legal seal brooch; edict staff top visible at frame edge. Ivory, deep blue, cold gold. Expression: polite menace, frozen smile or no smile.

**Battle sprite — paste after master:** Cassian full body, formal stance, Edict Staff in both hands or one hand driving staff butt to ground; long doctrinal coat layers; tall vertical silhouette; tent or column suggested only as soft background. Cold palette; staff head a clear readable shape.

**Avoid (prompt):** flamboyant golden paladin; radiant hero halo.

---

## 10 — Auditor Nerez Sable

**Art direction:** Luminous Table / Vharian elite · Levels 9B, 11, 17 · Silhouette: predatory aristocrat-accountant, knife-like · Materials: luxury textiles, concealed armor, ledger/seal · Palette: burgundy-black, coin gold · VFX: debt marks, extraction lines, contractual sigils · Motion: restrained, then sudden speed · Avoid: generic rogue.

**Portrait — paste after master:** Auditor Nerez Sable, aristocratic enforcer: burgundy-black tailored coat, high collar; thin needle blade barely visible at lower frame or held still at shoulder height; seal/ledger motif on glove or pin. Pale precise face; small knowing smile. Coin-gold trim accents.

**Battle sprite — paste after master:** Nerez full body, poised duelist stance, Ledger Needle extended forward; coattails and slim silhouette; one foot forward; concealed armor panels at ribs visible at joints. Elite duelist readability — not street thug. Deep wine, black, gold.

**Avoid (prompt):** generic hooded rogue; must feel **institutional elite**.

---

## 11 — Juno Kest

**Art direction:** Vharian dock security · Level 5 · Silhouette: compact alarm-master, signal gear · Materials: dock guard kit, bell/siren rigging · Palette: weathered navy, brass, signal red · VFX: alarm net, tower signals, crossfire markers · Motion: quick trigger-and-disengage · Avoid: losing “tempo boss” readability.

**Portrait — paste after master:** Juno Kest, wiry professional enforcer: weathered navy uniform collar, brass buttons, small bell-hook tool or knife hilt at belt visible. Signal-red scarf or armband **one accent**. Face: tired, owns the clock; sharp eyes.

**Battle sprite — paste after master:** Juno full body, compact agile stance, bellhook knife forward low, other hand on bell-rope coil or signal whistle at hip. Reinforced guard kit; rope rigging suggested in silhouette; feet on stone tower step. Quick “tempo boss” silhouette.

**Avoid (prompt):** pirate bell comedy; clockpunk clutter.

---

## 12 — Lord Septen Harrow

**Art direction:** Edranor opportunists · Level 7 · Silhouette: famine logistics tyrant; guarded bulk · Materials: noble armor, ration-hoard protections · Palette: muted crimson, grain ash, tarnished gold · VFX: hoardfire, convoy stress · Motion: slow command dominance · Avoid: glam villain detached from starvation.

**Portrait — paste after master:** Lord Septen Harrow, heavy noble male lord: mixed plate and fur-lined collar; halberd shaft crossing behind shoulders **or** halberd head visible top of frame. Muted crimson, grain-ash grey, tarnished gold. Face: contemptuous, well-fed hardness; cold eyes.

**Battle sprite — paste after master:** Septen full body, planted wide, halberd as vertical authority — butt on ground or sweeping guard stance. Ration-pouch or granary-key motif on belt; hoardfire orange **subtle** at feet or distant wagon silhouette. Heavy silhouette, grounded weight.

**Avoid (prompt):** cartoon glutton noble; must feel competent and dangerous.

---

## 13 — Thorn-Captain Edda Fen

**Art direction:** Frontier militarization · Level 8 · Silhouette: ranger-captain, practical predator · Materials: thorned leather, field metal, campaign gear · Palette: pine-dark, mud brown, poison moss accents · VFX: traps, pursuit, thorn burst · Motion: hunter precision · Avoid: generic druid caster.

**Portrait — paste after master:** Thorn-Captain Edda Fen, female frontier captain: weathered face, practical braid or short hair; thorned leather collar; mud and pine-green palette; steel axe haft along shoulder line. Expression: defiant, no romance.

**Battle sprite — paste after master:** Edda full body, wide stance, steel axe two-handed ready or over shoulder; thorned leather and field plate mix; boots in mud; **stumps or corduroy road** suggested in minimal background. Strong triangular silhouette.

**Avoid (prompt):** druid gown; Disney forest spirit.

---

## 14 — Justicar Halwen Serast

**Art direction:** Valeron militant tribunal · Level 10 · Silhouette: formal martial judge, vertical · Materials: tribunal plate, execution-textile layers · Palette: cold white/steel, punitive orange · VFX: verdict arcs, condemnation seals · Motion: ritualized sentencing · Avoid: hero-paladin glow.

**Portrait — paste after master:** Justicar Halwen Serast, imposing martial judge: tribunal helm open or crested; execution textile layer at neck; punitive orange rim light on cheek. Cold white-steel armor reflection. Expression: charismatic terror — arena performer of law.

**Battle sprite — paste after master:** Halwen full body, vertical imposing stance, Judgment Pike held high or driving downward; layered tribunal plate and tabard; cape as clean diagonal; punitive orange edge highlights on armor rims; arena sand or stone floor shadow only.

**Avoid (prompt):** golden hero paladin; warm smile.

---

## 15 — Noemi Veyr

**Delivery:** **DONE** — see Delivery status table.

**Art direction:** League-linked assassin · Level 11 · Silhouette: elegant, interchangeable social profiles · Materials: mask motifs, gloves, hidden blades · Palette: porcelain, black silk, jewel accents · VFX: mask shimmer, identity-swap afterimages · Motion: dancer precision, deceptive rhythm · Avoid: clown/jester coding.

**Portrait — paste after master:** Noemi Veyr, elegant female assassin: porcelain half-mask or held mask at chin; black silk and one jewel-tone accent (emerald or amethyst); thin needle weapon visible at hand **simple hold**. Playful menace in eyes; festival bokeh **soft** behind.

**Battle sprite — paste after master:** Noemi full body, dancer-off-balance combat pose, masquerade needle extended; layered skirts or coat tails for motion silhouette; mask on face or pushed to forehead; light feet, one leg extended. Readable “assassin performer” shape.

**Avoid (prompt):** harlequin clown; jester.

---

## 16 — Provost Serik Quill

**Art direction:** College censor-technologist · Level 12 · Silhouette: severe scholar-warden, angular · Materials: robes, locking seals, lenswork, runic hardware · Palette: ink black, parchment tan, brass glow · VFX: lock glyphs, suppression grids · Motion: measured procedural · Avoid: steampunk clutter.

**Portrait — paste after master:** Provost Serik Quill, severe male scholar: angular dark robes, brass locking seals at throat; monocle or lens; chain-key staff head peeking into frame. Ink black, parchment skin tone, brass glint. Face: insulted intellect, thin lips.

**Battle sprite — paste after master:** Serik full body, staff vertical with chain-keys radiating **simple geometric** lock sigils; robes with sharp vertical folds; slightly hunched forward aggressive scholar pose; feet visible on archive stone. Readable staff silhouette — not steampunk explosion.

**Avoid (prompt):** gear clutter hiding body line.

---

## 17 — Roen Halbrecht

**Art direction:** Traitor castellan · Level 14 · Silhouette: tired veteran, still competent · Materials: repaired armor, worn straps, grime · Palette: weathered steel, faded heraldry, fatigue grey · VFX: collapsing defense, failure sparks · Motion: hesitation under pressure · Avoid: cartoon villain posture.

**Portrait — paste after master:** Roen Halbrecht, exhausted male officer: cracked heraldic collar, dirt and sweat, five o’clock shadow or lined face. Eyes: shame + defiance. Weathered steel and faded heraldry colors; distant fire orange on cheek **subtle**.

**Battle sprite — paste after master:** Roen full body, slumped but ready guard, Pike of Valor held across body defensively; repaired mismatched armor plates; cracked keep floor; fatigue in shoulders — still competent soldier silhouette. Human tragedy, not villain pose.

**Avoid (prompt):** twirling mustache villain.

---

## 18 — The Ash Adjudicator

**Delivery:** **DONE** — see Delivery status table.

**Art direction:** Spectral Order vestige · Level 16 · Silhouette: iconographic ghost-judge · Materials: burnt-white ash cloak, cracked heraldry, hollow visor light · Palette: ash white, charcoal, solemn ember · VFX: cinder drift, verdict rings · Motion: ritualized inevitability · Avoid: generic floaty ghost knight.

**Portrait — paste after master:** The Ash Adjudicator **helmet / hollow visor close-up**: burnt-white ash mantle collar; cracked heraldic crest on brow; inner light in visor slit — **no normal face**. Charcoal and ember specks. Iconic, uncanny, still readable as “judge” silhouette at UI size.

**Battle sprite — paste after master:** Ash Adjudicator full body, towering armored judge: massive Verdict Blade grounded or two-handed ready; burnt-white ash cloak; cracked ancient heraldry on chest; hollow helm; cinder drifting; slow heavy stance; feet in ash circle. Broad dreadnought triangle silhouette.

**Avoid (prompt):** generic blob ghost; add **heraldic** ruin detail.

---

## 19 — Duke Alric Thornmere

**Art direction:** Edranor traditionalists · Level 17 · Silhouette: noble cavalry commander · Materials: aristocratic plate, riding cloak · Palette: family heraldry over martial steel · VFX: cavalry shock lines, formation signals · Motion: ducal precision · Avoid: cartoon decadent fop.

**Portrait — paste after master:** Duke Alric Thornmere, aristocratic male commander: rich heraldic gorget and mantle (thorn motif coherent with family colors); silver lance shaft diagonal behind head **or** gauntlet on chest. Sneer disciplined by martial bearing; misty field blur.

**Battle sprite — paste after master:** Alric full body, cavalry commander on foot **or** short rearing pose without full horse — if no horse, lance held as infantry brace in elite plate; heavy riding cloak sweep; thorn-heraldry on tabard; silver lance horizontal threat. Strong noble knight triangle.

**Avoid (prompt):** decadent cartoon fop; must read **soldier**.

---

## 20 — Naeva, Marrow-Seer of the Dark Tide

**Art direction:** Obsidian Circle / Dark Tide · Level 18 · Silhouette: half-priestess half-omen; fluid dark-water ceremonial shape · Materials: wet-shadow silk, shell/bone ornament, void markings · Palette: abyss teal, void black, marrow ivory · VFX: tide-like shadow, omen halos, marrow glyphs · Motion: calm devotional menace · Avoid: generic cultist sorceress.

**Portrait — paste after master:** Naeva, Marrow-Seer, female void-tide priestess: wet-shadow silk at neck and jaw; shell and bone jewelry framing face; subtle void markings on temples. Abyss teal and marrow ivory highlights in eyes. Expression: too calm, tragic beauty. Soft tide shadow **behind** head only.

**Battle sprite — paste after master:** Naeva full body, flowing stance, Dark Tide Grimoire open at chest height; free hand in ritual gesture; robes trailing like shallow water; bone ornaments catching teal light; feet bare or sandaled on wet stone; elongated graceful silhouette with **readable** book and hands.

**Avoid (prompt):** bikini armor; beach vacation; cheerful mood.

---

## 21 — The Witness Without Eyes

**Art direction:** Vel’golath manifestation · Level 19 · Silhouette: towering asymmetry; non-human but game-readable · Materials: bone, void-glass, parchment-flesh · Palette: anti-natural neutrals + invasive highlights · VFX: observation pressure, geometry warp, unmaking pulses · Motion: impossible but deliberate · Avoid: standard human proportions undermining cosmic scale.

**Portrait — paste after master:** The Witness Without Eyes — **abstract iconic crop**: fragment of alien “face” without eyes: bone plates, void-glass facets, parchment-flesh seams; wrong symmetry; invasive non-local highlight on one plane only. Oppressive scale hint (edge of something vast). Still square-safe for UI **omen slot** — not cute, not human.

**Battle sprite — paste after master:** The Witness full figure, towering asymmetric entity: multiple limbs or wing-plates **but one clear primary body mass**; Null Hymn as strange object-staff or folded geometry in hands; subtle bent perspective at feet; wrong neutrals palette; deliberate impossible posture; strong **readable** boss silhouette for tactical screen.

**Avoid (prompt):** generic horned demon; standard human proportions.

---

## Recurring bosses (same name, harder encounter)

Add to either portrait or battle prompt:

> More battle-worn / higher ritual corruption than earlier appearance.

---

*End of Art Director sourcebook.*
