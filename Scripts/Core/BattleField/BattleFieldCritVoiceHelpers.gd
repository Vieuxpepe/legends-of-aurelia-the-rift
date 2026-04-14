extends RefCounted

## Extra layer under CritSound for crit strikes on field units. Uses [member Unit.voice_gender] / [member UnitData.voice_gender] (0 = male, 1 = female).
const VOICE_GENDER_FEMALE := 1

const _GRUNT_MALE_1: AudioStream = preload("res://Assets/Voices/human_male_voice long grunt 1.mp3")
const _GRUNT_MALE_2: AudioStream = preload("res://Assets/Voices/human_male_voice long grunt 2.mp3")
const _GRUNT_MALE_3: AudioStream = preload("res://Assets/Voices/human_male_voice long grunt 3.mp3")
const _FEMALE_EPIC_ATTACK: AudioStream = preload("res://Assets/Voices/HumanFemaleEpicAttack.mp3")

const _MALE_GRUNTS: Array[AudioStream] = [_GRUNT_MALE_1, _GRUNT_MALE_2, _GRUNT_MALE_3]

const CRIT_GRUNT_VOLUME_DB := -4.5
const CRIT_GRUNT_PITCH_JITTER_MIN := 0.93
const CRIT_GRUNT_PITCH_JITTER_MAX := 1.07


static func _is_field_combat_unit(field, unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var p: Node = unit.get_parent()
	if p == null:
		return false
	return p == field.player_container or p == field.ally_container or p == field.enemy_container


static func _voice_gender_from_unit(unit: Node2D) -> int:
	if unit == null:
		return 0
	if unit.get("voice_gender") != null:
		return clampi(int(unit.voice_gender), 0, 1)
	if unit.get("gender") != null:
		var g = unit.gender
		if g is String:
			var gs := String(g).strip_edges().to_lower()
			if gs in ["f", "female", "woman", "w", "girl"]:
				return VOICE_GENDER_FEMALE
	return 0


static func _pick_grunt_stream(unit: Node2D) -> AudioStream:
	var g: int = _voice_gender_from_unit(unit)
	if g == VOICE_GENDER_FEMALE:
		return _FEMALE_EPIC_ATTACK
	return _MALE_GRUNTS[randi() % _MALE_GRUNTS.size()]


static func play_crit_striker_voice_grunt(field, striker: Node2D) -> void:
	if field == null or not is_instance_valid(field):
		return
	if not _is_field_combat_unit(field, striker):
		return
	var stream: AudioStream = _pick_grunt_stream(striker)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = CRIT_GRUNT_VOLUME_DB
	p.pitch_scale = randf_range(CRIT_GRUNT_PITCH_JITTER_MIN, CRIT_GRUNT_PITCH_JITTER_MAX)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
