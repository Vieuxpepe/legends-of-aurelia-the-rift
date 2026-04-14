extends RefCounted
class_name BeastiaryIntelRegistry

## Central list of gated Field Notes lines (id, unit_data_paths, body_bbcode per row).
## Emphasis uses [color] (not [b]) so the catalogue font stays readable.

const INTEL_EMPHASIS_COLOR := "#d8b456"
const INTEL_POPUP_HEADER_COLOR := "#a8c8e8"


static func _all_entries() -> Array:
	var em := INTEL_EMPHASIS_COLOR
	return [
		{
			"id": "intel_damage_type_readout",
			"unit_data_paths": PackedStringArray([]),
			"body_bbcode": "Elara now fills in [color=%s]weaknesses and resistances[/color] on each entry’s [color=%s]Stats[/color] tab — only the damage types that matter, with the × value next to each. ×1.0 is normal; lower means they take less, higher means they take more." % [em, em],
		},
		{
			"id": "undead_blunt_bone_pile",
			"unit_data_paths": PackedStringArray([
				"res://Resources/Units/Skeleton.tres",
				"res://Resources/Units/SkeletonHealer.tres",
				"res://Resources/Units/SkeletonVeteran.tres",
			]),
			"body_bbcode": "These risen soldiers can [color=%s]reform from a bone pile[/color] after they fall—unless a killing blow comes from a [color=%s]bludgeoning[/color] weapon, which shatters the remains and stops them from coming back. In melee they can also leave [color=%s]bone toxin[/color] on a struck foe: lingering harm each enemy phase until it runs its course. Magic-wise they are [color=%s]vulnerable to fire and divine[/color] channels, but [color=%s]resist necrotic[/color] energy that would rot living flesh." % [em, em, em, em, em],
		},
		{
			"id": "boss_lady_vespera",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L18_LadyVespera.tres",
			]),
			"body_bbcode": "The archmage of rupture. Lady Vespera uses [color=%s]Cataclysmic Locus[/color], warping the reality of the map. Her devastating magical resistance demands extreme [color=%s]physical pressure[/color]." % [em, em],
		},
		{
			"id": "boss_vespera_apparition",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L01_LadyVespera_Apparition.tres",
			]),
			"body_bbcode": "A terrifying phantom. It uses [color=%s]Cataclysmic Locus[/color] to control space. Do not attempt to defeat her attrition; [color=%s]flee or outmaneuver her[/color]!" % [em, em],
		},
		{
			"id": "boss_vespera_ascendant",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L19_VesperaAscendant.tres",
			]),
			"body_bbcode": "Ascended beyond humanity. The [color=%s]Cataclysmic Locus[/color] is permanent. [color=%s]Overwhelming magical power[/color] and unmatched speed. Do not cluster your units." % [em, em],
		},
		{
			"id": "boss_master_enric",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L15_MasterEnric.tres",
			]),
			"body_bbcode": "A clinical necromancer. Enric's [color=%s]Dissertation of Rot[/color] continually resurrects fallen forces. Target him with [color=%s]high-mobility assassins[/color] before the swamp consumes your frontline." % [em, em],
		},
		{
			"id": "boss_captain_selene",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L13_CaptainSelene.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L18_CaptainSelene.tres",
			]),
			"body_bbcode": "The shadowblade commander. Her [color=%s]Umbra Step[/color] makes her lethal against our backline. Bind her down with [color=%s]heavy armor[/color] to restrict her assassinations." % [em, em],
		},
		{
			"id": "boss_ephrem",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L03_EphremTheZealot.tres",
			]),
			"body_bbcode": "A fanatical Valeron purist. He wields [color=%s]Mark of Cinder[/color] to buff zealots around him. Separate him from his flock or overwhelm his [color=%s]low physical defense[/color]." % [em, em],
		},
		{
			"id": "boss_caldris",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L02_MotherCaldrisVein.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L10_MotherCaldrisVein.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L17_MotherCaldrisVein.tres",
			]),
			"body_bbcode": "Inquisitor Mother Vein. Her [color=%s]Litany of Restraint[/color] silences mages and cuts off healing. Attack her with [color=%s]ranged physical[/color] volleys." % [em, em],
		},
		{
			"id": "boss_rhex",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L04_PortMasterRhexValcero.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L05_PortMasterRhexValcero.tres",
			]),
			"body_bbcode": "A corrupt logistics baron. Rhex utilizes [color=%s]Bought Time[/color] to summon endless reinforcements. His armor is heavy; melt him with [color=%s]magic[/color]." % [em, em],
		},
		{
			"id": "boss_mortivar",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L06_MortivarHale.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L14_MortivarHale.tres",
			]),
			"body_bbcode": "The Grave Marshal. [color=%s]Grave Muster[/color] rallies the undead effortlessly. His physical resilience is immense; [color=%s]focus fire with magic[/color] and holy weapons." % [em, em],
		},
		{
			"id": "boss_cassian",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L09A_PreceptorCassianVow.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L17_PreceptorCassianVow.tres",
			]),
			"body_bbcode": "The manipulative Preceptor. His [color=%s]False Accord[/color] bends the rules of engagement. He has high Resistance but [color=%s]low Defense[/color]." % [em, em],
		},
		{
			"id": "boss_nerez",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L09B_AuditorNerezSable.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L11_AuditorNerezSable.tres",
				"res://Resources/EnemyUnitData/Bosses/Boss_L17_AuditorNerezSable.tres",
			]),
			"body_bbcode": "The Auditor. [color=%s]Collateral Clause[/color] locks down our valuable units. Do not let him approach your most [color=%s]vulnerable backliners[/color]." % [em, em],
		},
		{
			"id": "boss_juno",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L05_JunoKest.tres",
			]),
			"body_bbcode": "The Bell Ringer. [color=%s]Alarm Net[/color] punishes slow movement. She is exceptionally agile and evasive; use [color=%s]guaranteed hits or magic[/color]." % [em, em],
		},
		{
			"id": "boss_septen",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L07_LordSeptenHarrow.tres",
			]),
			"body_bbcode": "A parasite lord. Septen's [color=%s]Hoardfire[/color] heavily armored stature forces us to rely on [color=%s]armor-piercing or magical[/color] destruction." % [em, em],
		},
		{
			"id": "boss_edda",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L08_ThornCaptainEddaFen.tres",
			]),
			"body_bbcode": "The Thorn-Captain. [color=%s]Timberline Snare[/color] disrupts our traversal in the woods. Her axe strikes are brutal against [color=%s]lightly armored[/color] allies." % [em, em],
		},
		{
			"id": "boss_halwen",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L10_JusticarHalwenSerast.tres",
			]),
			"body_bbcode": "The Justicar. Driven by spectacle, [color=%s]Verdict of Flame[/color] punishes clustering. High physical stats; exploit his [color=%s]lower Magical Resistance[/color]." % [em, em],
		},
		{
			"id": "boss_noemi",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L11_NoemiVeyr.tres",
			]),
			"body_bbcode": "The Fifth Mask. Her [color=%s]Fifth Mask[/color] ability allows deadly infiltrations. Use extreme caution and [color=%s]ward your flanks[/color]." % [em, em],
		},
		{
			"id": "boss_serik",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L12_ProvostSerikQuill.tres",
			]),
			"body_bbcode": "The Censor. [color=%s]Archive Lock[/color] shuts down magic and movement. Engage him carefully with solid [color=%s]physical hitters[/color]." % [em, em],
		},
		{
			"id": "boss_roen",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L14_RoenHalbrecht.tres",
			]),
			"body_bbcode": "The Broken Castellan. Wielding [color=%s]Betrayers Lever[/color], his immense defenses demand careful setup. Shatter his form with [color=%s]heavy axes or magic[/color]." % [em, em],
		},
		{
			"id": "boss_ash_adj",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L16_AshAdjudicator.tres",
			]),
			"body_bbcode": "A spectral verdict. [color=%s]Trial Mirror[/color] reflects our actions. Despite being spectral, he bears the armor of a Dreadnought; [color=%s]magic and anti-armor[/color] are essential." % [em, em],
		},
		{
			"id": "boss_alric",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L17_DukeAlricThornmere.tres",
			]),
			"body_bbcode": "The Duke. [color=%s]Banner Break[/color] initiates devastating cavalry charges. Break his charge with [color=%s]pikemen or heavy knights[/color]." % [em, em],
		},
		{
			"id": "boss_naeva",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L18_NaevaMarrowSeer.tres",
			]),
			"body_bbcode": "The Marrow-Seer. [color=%s]Marrow Hymn[/color] alters the battlefield violently with Void magic. [color=%s]Silence her or overwhelm her[/color] with physical strikes rapidly." % [em, em],
		},
		{
			"id": "boss_witness",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Bosses/Boss_L19_WitnessWithoutEyes.tres",
			]),
			"body_bbcode": "An entity of cosmic scale. [color=%s]Unmake the Grid[/color] literally erases the map. It has no physical weakness; rely entirely on [color=%s]Ascended abilities and overwhelming power[/color]." % [em, em],
		},
		{
			"id": "gen_dark_tide",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_TideThrall_T2.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_VoidAcolyte_T3.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_AbyssLancer_T3.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_NullChoir_T3.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_RiftStalker_T3.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_AnchorGuardian_T3.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_TendrilSpawn_T3.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_UnmadeHorror_T4.tres",
				"res://Resources/EnemyUnitData/Generic/DarkTide/Generic_DarkTide_GlyphBreaker_T4.tres",
			]),
			"body_bbcode": "Horrors of the Dark Tide. Their forms writhe with [color=%s]immense Magical power[/color], but their flesh is often unwarded. Target them with [color=%s]relentless physical strikes[/color] before their spells complete." % [em, em],
		},
		{
			"id": "gen_undead_greyspire",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_BonePikeman_T2.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_Graveblade_T2.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_CryptArcher_T2.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_MournfulHusk_T1.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_DeathAcolyte_T2.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_RevenantRider_T3.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_RotBinder_T3.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_DrownedArcher_T3.tres",
				"res://Resources/EnemyUnitData/Generic/UndeadGreyspire/Generic_UndeadGreyspire_MireHexer_T3.tres",
			]),
			"body_bbcode": "The risen forces of Greyspire. Slow and inevitable, their bones are hardened against standard slashing attacks. Use [color=%s]Magic or heavy blunt trauma[/color] to break their [color=%s]high Physical Defense[/color]." % [em, em],
		},
		{
			"id": "gen_obsidian_circle",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_AshCultist_T1.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_PyreDisciple_T1.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_SoulReaver_T1.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_CinderArcher_T1.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_RiftHound_T1.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_RitualAdept_T2.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_VoidTouchedElite_T3.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_BlackCoastRaider_T3.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_TideArcher_T3.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_ShadowbladeSkirmisher_T3.tres",
				"res://Resources/EnemyUnitData/Generic/ObsidianCircle/Generic_ObsidianCircle_SiegeCrew_T3.tres",
			]),
			"body_bbcode": "The Obsidian Circle integrates brutal frontline warriors with devastating pyromancers. Beware their [color=%s]mixed damage output[/color], and exploit their lack of heavy armor with [color=%s]agile skirmishers[/color]." % [em, em],
		},
		{
			"id": "gen_valeron_purifiers",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_PurifierAcolyte_T1.tres",
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_TempleGuard_T1.tres",
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_SunArcher_T1.tres",
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_CenserCleric_T1.tres",
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_DoctrineBlade_T2.tres",
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_AshenTemplar_T2.tres",
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_InquisitorAdept_T2.tres",
				"res://Resources/EnemyUnitData/Generic/Valeron/Generic_Valeron_ArenaTemplar_T3.tres",
			]),
			"body_bbcode": "Valeron's Purifiers. Fanatical and heavily warded, they boast extremely [color=%s]high Resistance[/color] to magic. You must crack their lines with [color=%s]heavy physical onslaughts[/color]." % [em, em],
		},
		{
			"id": "gen_league_mercs",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_DockThug_T1.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_WatchCrossbowman_T1.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_RooftopKnife_T1.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_ContractGuard_T2.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_BellRigger_T1.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_PowderGunner_T2.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_AccountantDuelist_T2.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_SewerSmuggler_T1.tres",
				"res://Resources/EnemyUnitData/Generic/League/Generic_League_LeagueMarshal_T2.tres",
			]),
			"body_bbcode": "League Mercenaries. Funded by the merchants, they deploy dirty back-alley tactics and deadly ranged weapons. Expect [color=%s]high Speed and Agility[/color], but their [color=%s]Resistance to magic is notably poor[/color]." % [em, em],
		},
		{
			"id": "gen_college_order",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_ArchiveWarden_T2.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_ScriptorMage_T1.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_BarrierAdept_T1.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_StairDuelist_T2.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_LampRunner_T1.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_Sealkeeper_T2.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_Oathshade_T3.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_DawnSentinel_T3.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_TrialArcher_T3.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_ChapelEcho_T2.tres",
				"res://Resources/EnemyUnitData/Generic/CollegeAndOrder/Generic_CollegeAndOrder_MirrorJudge_T3.tres",
			]),
			"body_bbcode": "Defenders of the College & Order. A disciplined blend of wards and steel. Their formation relies on supportive magic and [color=%s]defensive buffs[/color]. Use [color=%s]assassins or burst damage[/color] to shatter their backline casters." % [em, em],
		},
		{
			"id": "gen_edranor_forces",
			"unit_data_paths": PackedStringArray([
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_GranaryGuard_T2.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_LevySpearman_T1.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_TaxArcher_T1.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_MountedRetainer_T2.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_RoadBailiff_T2.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_Houndmaster_T2.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_AxebarkRaider_T2.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_RoadWarden_T2.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_Trapkeeper_T1.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_CliffSkirmisher_T2.tres",
				"res://Resources/EnemyUnitData/Generic/EdranorAndForest/Generic_EdranorAndForest_TotemKeeper_T2.tres",
			]),
			"body_bbcode": "Edranor Frontier Forces. Accustomed to harsh terrain, they dominate the woods with beastmasters and archers. Control the [color=%s]chokepoints[/color] and avoid fighting them in [color=%s]thick forests[/color]." % [em, em],
		},
	]


static func find_entry_by_intel_id(intel_id: String) -> Dictionary:
	var want: String = str(intel_id).strip_edges()
	if want.is_empty():
		return {}
	for e in _all_entries():
		if not (e is Dictionary):
			continue
		if str((e as Dictionary).get("id", "")).strip_edges() == want:
			return e as Dictionary
	return {}


## Strips simple BBCode tags for use in plain [Label] / combat floaters.
static func plain_text_from_bbcode(bbcode: String) -> String:
	var s: String = str(bbcode)
	if s.is_empty():
		return ""
	var rx := RegEx.new()
	if rx.compile("\\[\\/?[^\\]]+\\]") != OK:
		return s.strip_edges()
	s = rx.sub(s, "", true)
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s.strip_edges()


static func get_plain_lesson_for_intel_id(intel_id: String) -> String:
	var row: Dictionary = find_entry_by_intel_id(intel_id)
	if row.is_empty():
		return ""
	return plain_text_from_bbcode(str(row.get("body_bbcode", "")))


static func get_body_bbcode_for_intel_id(intel_id: String) -> String:
	var row: Dictionary = find_entry_by_intel_id(intel_id)
	if row.is_empty():
		return ""
	return str(row.get("body_bbcode", "")).strip_edges()


static func build_popup_bbcode_for_new_intel_ids(new_ids: PackedStringArray) -> String:
	var bodies: PackedStringArray = []
	for nid in new_ids:
		var body: String = get_body_bbcode_for_intel_id(nid)
		if body.is_empty():
			body = "[color=#bbbbbb](Recorded: %s — see Field Notes.)[/color]" % str(nid)
		bodies.append(body)
	var hdr: String = INTEL_POPUP_HEADER_COLOR
	var header: String = "[font_size=20][color=%s]Added to Field Notes[/color][/font_size]" % hdr
	if bodies.is_empty():
		return header
	return header + "\n\n" + "\n\n".join(bodies)


static func get_entries_for_unit_data_path(unit_data_path: String) -> Array:
	var p: String = unit_data_path.strip_edges()
	if p.is_empty():
		return []
	var out: Array = []
	for e in _all_entries():
		if not (e is Dictionary):
			continue
		var paths: Variant = e.get("unit_data_paths", null)
		if paths is PackedStringArray:
			if (paths as PackedStringArray).has(p):
				out.append(e)
	return out
