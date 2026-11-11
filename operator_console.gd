extends Control

signal hacking_completed(outcome_type: String, final_affinity: int)

@export var available_missions: Array[MissionData] = []
@export var starting_mission_index: int = 0
@export var start_in_vn_mode: bool = false
@export var enable_crt_effect: bool = true
@export_range(0.0, 1.0, 0.05) var crt_intensity: float = 0.65

var embedded_in_vn_engine: bool = false
var embedded_in_3d_monitor: bool = false

# --- ESTADO DINÁMICO ---
var current_mission: MissionData
var bpm: int = 95
var max_bpm: int = 175
var affinity: int = 50
var time_left: int = 180
var game_active: bool = false
var pulse_phase: float = 0.0
var last_outcome_type: String = "mission" # "mission", "romance", "failure"

# --- ENERGÍA, TEMPERATURA Y HACKEOS DEL MONSTRUO ---
var power_energy: float = 100.0
var bunker_temperature: float = 24.0
const NORMAL_TEMP: float = 24.0
const CRITICAL_TEMP: float = 100.0
var temp_hacked_by_monster: bool = false
var light_hacked_by_monster: bool = false
var companion_pc_unlocked: bool = true

# --- TEMPORIZADORES INDEPENDIENTES Y AZAROSOS DE HACKEO ---
var next_light_hack_timer: float = 14.0
var next_cooling_hack_timer: float = 20.0
var next_pc_hack_timer: float = 26.0

# --- TEMPORIZADOR RANDOM AL CERRARLE LA PUERTA (0.0 A 10.0 SEGUNDOS) ---
var door_hold_timer: float = 0.0
var door_hold_target_time: float = -1.0

# --- ESTADO DE CONTENCIÓN DEL MONSTRUO (TOPOLOGÍA 3 - 2 - 2 - 1) ---
const TOTAL_SECURITY_LEVELS: int = 4
const TOTAL_DEFENSES_REQUIRED: int = 5
const CAM_NODE_IDS: Array[String] = ["1A", "1", "1B", "2A", "2B", "3A", "3B", "4"]
var monster_security_level: int = 1
var monster_branch: String = "B" # "A" = 1A (Arriba), "B" = 1 (Medio), "C" = 1B (Abajo)
var monster_spotted_on_cam: bool = false
var monster_attack_active: bool = false
var monster_cooldown_timer: float = 5.0
var monster_last_node_id: String = "1"
var monster_advance_on_next_wave: bool = false
var gates_closed_by_guard: int = 0
var door_node_states: Dictionary = {
	"1A": "OPEN",
	"1": "OPEN",
	"1B": "OPEN",
	"2A": "OPEN",
	"2B": "OPEN",
	"3A": "OPEN",
	"3B": "OPEN",
	"4": "OPEN"
}
var selected_cam_id: String = "1"
var cam_select_buttons: Dictionary = {}
var map_node_positions: Dictionary = {}
var monster_hack_progress: float = 0.0
var naomi_shield_charges: int = 1
var mia_prediction_ready: bool = true

# --- AUDIO PROCEDURAL DE LA TURBINA ---
var music_audio_player: AudioStreamPlayer
var music_audio_playback: AudioStreamGeneratorPlayback
var music_audio_phase: float = 0.0

# --- NODOS DEL PREVIZ 3D DE CÁMARAS DE SEGURIDAD ---
var previz_viewport: SubViewport
var previz_cam_3d: Camera3D
var previz_room_light: OmniLight3D
var previz_door_mesh: MeshInstance3D
var previz_monster_root: Node3D
var previz_monster_arm_l: Node3D
var previz_monster_arm_r: Node3D
var previz_monster_leg_l: Node3D
var previz_monster_leg_r: Node3D
var previz_monster_head: Node3D
var previz_walk_phase: float = 0.0
var lbl_previz_cam_title: Label
var lbl_previz_cam_alert: Label
var btn_seal_door_b: Button
var btn_seal_door_c: Button
var btn_open_all_doors: Button

# --- ESTADO DE VIDA Y PULSO DE LA COMPAÑERA ---
var mia_max_lives: int = 5
var mia_lives: int = 5
var mia_hp_percent: int = 100
var mia_bpm: int = 92
var mia_pulse_phase: float = 0.0
var mia_damage_flash: float = 0.0

# --- ESTADO DEL MOTOR DE NOVELA VISUAL (VN ENGINE) ---
var vn_layer: Control
var vn_active: bool = false
var vn_phase: String = "intro"
var vn_parsed_lines: Array[Dictionary] = []
var vn_line_index: int = 0
var vn_typing: bool = false
var vn_char_progress: float = 0.0
var vn_type_speed: float = 52.0
var vn_waiting_choice: bool = false
var vn_auto_mode: bool = false
var vn_auto_timer: float = 0.0
var vn_history_entries: Array[String] = []

var vn_bg_rect: TextureRect
var vn_grid_canvas: Control
var vn_portrait_frame: PanelContainer
var vn_portrait_style: StyleBoxFlat
var vn_portrait_rect: TextureRect
var vn_video_player: VideoStreamPlayer
var vn_speaker_badge: Label
var vn_dialogue_rtl: RichTextLabel
var vn_next_indicator: Label
var vn_choices_box: VBoxContainer
var vn_choice_btn_1: Button
var vn_choice_btn_2: Button
var vn_lbl_chapter: Label
var vn_lbl_affinity_chip: Label
var vn_btn_auto: Button
var vn_log_modal: PanelContainer
var vn_log_rtl: RichTextLabel

# --- ESTADO DE TAB 01: TURBINA DE REFRIGERACIÓN ---
var music_box_charge: float = 90.0
var music_box_pulse_grace: float = 0.0
var monster_is_moving: bool = true
var music_gear_angle: float = 0.0
var bar_music_box: ProgressBar
var lbl_music_status: Label
var lbl_music_beast_state: Label
var music_box_canvas: Control
var btn_wind_music: Button

# --- ESTADO DE TAB 02: LUZ DEL PASILLO + MINIJUEGO DE PERILLAS ---
const KNOB_COUNT: int = 4
const KNOB_MAX_STEPS: int = 8
var knob_Target_values: Array[int] = [2, 5, 1, 6]
var knob_Current_values: Array[int] = [2, 5, 1, 6]
var knob_canvases: Array[Control] = []
var knob_val_labels: Array[Label] = []
var dragging_knob_index: int = -1

# --- BANNER DE ALERTA VISUAL DE SISTEMAS HACKEADOS ---
var hack_alert_banner: PanelContainer
var hack_alert_style: StyleBoxFlat
var lbl_hack_alert_banner: Label
var btn_hack_alert_goto: Button

var flash_stun_grace: float = 0.0
var lbl_lure_title: Label
var lbl_lure_selected_cam: Label
var lbl_lure_hint: Label
var lbl_sys_audio_badge: Label
var lbl_sys_video_badge: Label
var lbl_sys_door_badge: Label
var btn_hallway_light: Button
var btn_goto_reboot: Button
var lbl_code_progress_status: Label

# --- ESTADO DE TAB 03: DESBLOQUEAR PC DE LA COMPAÑERA (MATRIZ HEX) ---
var hex_pool: PackedStringArray = ["1C", "55", "BD", "E9", "7A", "FF"]
var matrix_grid: Array = []
var matrix_buttons: Array = []
var target_sequence: Array[String] = []
var entered_sequence: Array[String] = []
var active_index: int = 0
var selecting_row: bool = true
var used_cells: Dictionary = {}

# --- NODOS UI CONSOLA ---
var lbl_affinity: Label
var lbl_timer: Label
var lbl_sector: Label
var lbl_codename: Label
var bar_affinity: ProgressBar
var bar_trace: ProgressBar
var rtl_chat: RichTextLabel
var tactical_map: Control
var monitor_3d_diorama: Control

var lbl_energy_val: Label
var bar_energy: ProgressBar
var lbl_temp_val: Label
var bar_temperature: ProgressBar
var lbl_companion_hack_status: Label

var mia_portrait_rect: TextureRect
var mia_portrait_border_style: StyleBoxFlat
var lbl_mia_header: Label
var lbl_mia_hearts: Label
var bar_mia_hp: ProgressBar
var lbl_mia_heart_icon: Label
var lbl_mia_bpm_overlay: Label
var mia_ecg_graph: Control

var btn_inject: Button
var btn_continue_vn: Button
var status_overlay: Label
var tab_container: TabContainer
var mission_selector: OptionButton
var game_timer: Timer

var lbl_breach_status: Label
var lbl_target_seq: RichTextLabel
var lbl_buffer_seq: RichTextLabel
var lbl_breach_hint: Label
var grid_matrix: GridContainer
var btn_reset_matrix: Button
var lock_banner: PanelContainer
var lbl_lock_banner: Label
var lbl_monster_status: Label
var bar_monster_hack: ProgressBar
var lbl_perk_status: Label
var btn_companion_perk: Button
var death_modal: Control
var death_art_canvas: Control
var lbl_death_title: Label
var lbl_death_details: RichTextLabel
var victory_modal: Control
var lbl_victory_title: Label
var lbl_victory_details: RichTextLabel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_turbine_audio()
	_build_universal_ui()
	_build_vn_stage_ui()
	_build_death_jumpscare_modal()
	_build_victory_modal()
	var vp_s: Vector2 = Vector2(get_viewport().size)
	if vp_s.x > 100 and vp_s.y > 100:
		size = vp_s

	if available_missions.is_empty():
		available_missions.append(_create_default_template("Mia", "ORACLE-01", Color("#f600ff"), Vector2(0.86, 0.50)))
		available_missions.append(_create_default_template("Naomi", "AEGIS-02", Color("#00ff9d"), Vector2(0.86, 0.50)))
	elif available_missions.size() == 1:
		available_missions.append(_create_default_template("Naomi", "AEGIS-02", Color("#00ff9d"), Vector2(0.86, 0.50)))

	_populate_mission_selector()
	if not embedded_in_vn_engine:
		var initial_mission = available_missions[clamp(starting_mission_index, 0, available_missions.size() - 1)]
		load_mission(initial_mission, start_in_vn_mode)

func _unhandled_input(event: InputEvent) -> void:
	if not vn_active or vn_log_modal.visible or vn_waiting_choice:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_on_vn_advance_pressed()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(current_mission):
		return
	var bps = float(bpm) / 60.0
	pulse_phase += delta * bps * TAU

	var mia_bps = float(mia_bpm) / 60.0
	mia_pulse_phase += delta * mia_bps * TAU
	var mia_heart_scale = 1.0 + (max(0.0, sin(mia_pulse_phase)) * 0.28 if mia_bpm > 0 else 0.0)
	if is_instance_valid(lbl_mia_heart_icon):
		lbl_mia_heart_icon.scale = Vector2(mia_heart_scale, mia_heart_scale)
	if mia_damage_flash > 0.0:
		mia_damage_flash = max(0.0, mia_damage_flash - delta * 2.2)
		if is_instance_valid(mia_portrait_rect):
			mia_portrait_rect.modulate = Color(1.0, 1.0 - mia_damage_flash * 0.65, 1.0 - mia_damage_flash * 0.65, 1.0)

	tactical_map.queue_redraw()
	_update_hack_alert_visual_pulse()
	if is_instance_valid(monitor_3d_diorama):
		monitor_3d_diorama.queue_redraw()
	if is_instance_valid(mia_ecg_graph):
		mia_ecg_graph.queue_redraw()
	if is_instance_valid(death_modal) and death_modal.visible and is_instance_valid(death_art_canvas):
		death_art_canvas.queue_redraw()

	if game_active and not vn_active:
		if flash_stun_grace > 0.0:
			flash_stun_grace = max(0.0, flash_stun_grace - delta)

		# --- EVENTOS DE HACKEO INDEPENDIENTES Y AL AZAR ---
		next_light_hack_timer -= delta
		if next_light_hack_timer <= 0.0:
			next_light_hack_timer = randf_range(14.0, 30.0)
			if not light_hacked_by_monster and randf() < 0.75:
				_trigger_monster_light_knob_hack()
				_log_chat("SISTEMA", "🎛️ ¡El monstruo hackeó las Perillas de Luz en [Tab 02]! Calibralas para poder iluminar los pasillos.", "#ffaa00")

		next_cooling_hack_timer -= delta
		if next_cooling_hack_timer <= 0.0:
			next_cooling_hack_timer = randf_range(16.0, 34.0)
			if not temp_hacked_by_monster and randf() < 0.75:
				temp_hacked_by_monster = true
				mia_bpm = min(195, mia_bpm + 34)
				_update_mia_vitals_ui()
				var comp_n = current_mission.agent_name.to_upper()
				_log_chat(comp_n, "«¡Ugh...! Siento que falta el aire y hace muchísimo calor acá adentro... ¡Mi pulso se está disparando, revisá la refrigeración!»", "#ff4d94")

		next_pc_hack_timer -= delta
		if next_pc_hack_timer <= 0.0:
			next_pc_hack_timer = randf_range(18.0, 36.0)
			if companion_pc_unlocked and monster_attack_active and randf() < 0.70:
				companion_pc_unlocked = false
				_generate_breach_matrix()
				_refresh_lure_tab_ui()
				var comp_n = current_mission.agent_name.to_upper()
				_log_chat(comp_n, "💻 «¡Subject-Zero acaba de bloquear mi terminal! Desbloqueámela en [Tab 03] para seguir frenando su hackeo!»", "#f600ff")

		# 1. PROCESAR TURBINA DE REFRIGERACIÓN (TAB 01)
		if music_box_pulse_grace > 0.0:
			music_box_pulse_grace = max(0.0, music_box_pulse_grace - delta)
		else:
			var turb_drain: float = 1.8
			if monster_attack_active:
				turb_drain = 3.2
			if temp_hacked_by_monster:
				turb_drain += 2.2
			music_box_charge = max(0.0, music_box_charge - delta * turb_drain)

		var turbine_working: bool = (music_box_charge >= 40.0 and power_energy > 0.0)
		if turbine_working:
			var gear_spd: float = 7.5 if music_box_pulse_grace > 0.0 else 3.8 * (music_box_charge / 100.0)
			music_gear_angle = fmod(music_gear_angle + delta * gear_spd, TAU)
			_fill_turbine_audio_buffer()

		# 2. PROCESAR TEMPERATURA
		var temp_rate: float = 0.0
		if not turbine_working:
			temp_rate += 4.6
		if temp_hacked_by_monster:
			temp_rate += 2.8
		if turbine_working and not temp_hacked_by_monster:
			temp_rate = -3.8

		bunker_temperature = clampf(bunker_temperature + delta * temp_rate, NORMAL_TEMP, CRITICAL_TEMP)

		# 3. PROCESAR ENERGÍA
		var closed_doors_cnt: int = _count_locked_doors()
		var energy_drain: float = float(closed_doors_cnt) * 1.45
		if not turbine_working:
			energy_drain += 3.6
		if bunker_temperature >= 70.0:
			energy_drain += 1.6
		if closed_doors_cnt == 0 and turbine_working and bunker_temperature < 50.0:
			energy_drain = -0.8

		power_energy = clampf(power_energy - delta * energy_drain, 0.0, 100.0)

		if power_energy <= 0.0 and closed_doors_cnt > 0:
			_force_open_all_doors_on_power_outage()

		if bunker_temperature >= CRITICAL_TEMP:
			bunker_temperature = 75.0
			power_energy = max(0.0, power_energy - 25.0)
			_log_chat("ALERTA_TÉRMICA", "🔥 ¡SOBRECALENTAMIENTO (100°C)! El calor extremo drenó -25% de Energía! ¡Impulsá la Turbina en [Tab 01]!", "#ff1744")

		# 4. PROCESAR ATAQUE DEL MONSTRUO, PUERTAS (0 A 10s RANDOM) Y PC COMPAÑERA
		if not monster_attack_active:
			monster_is_moving = false
			monster_hack_progress = 0.0
			door_hold_timer = 0.0
			door_hold_target_time = -1.0
			monster_cooldown_timer -= delta
			_update_turbine_ui()
			_update_energy_and_temp_hud()
			if is_instance_valid(music_box_canvas):
				music_box_canvas.queue_redraw()
			if is_instance_valid(bar_monster_hack):
				bar_monster_hack.value = 0.0
			if is_instance_valid(lbl_monster_status):
				var err_cnt = _count_active_errors()
				var sys_txt = ("⚠️ %d SABOTAJE(S)!" % err_cnt) if err_cnt > 0 else "✓ SISTEMAS OK"
				lbl_monster_status.text = "👁️ %s [DESAPARECIDO // ÚLTIMO RASTRO C%s]  |  %s  |  DEFENSAS: %d/%d" % [
					current_mission.monster_name,
					monster_last_node_id,
					sys_txt,
					gates_closed_by_guard,
					TOTAL_DEFENSES_REQUIRED
				]
				lbl_monster_status.modulate = Color("#ffaa00") if err_cnt > 0 else Color("#00f0ff")
			_update_3d_previz(delta)
			if monster_cooldown_timer <= 0.0:
				_start_monster_attack_wave()
		else:
			var cur_monster_node: String = _get_monster_node_id()
			var door_is_closed_on_monster: bool = (door_node_states.get(cur_monster_node, "OPEN") == "LOCKED" and power_energy > 0.0)

			if door_is_closed_on_monster:
				monster_is_moving = false
				if door_hold_target_time < 0.0:
					door_hold_target_time = randf_range(1.5, 10.0)
					door_hold_timer = 0.0
				door_hold_timer += delta

				if companion_pc_unlocked:
					monster_hack_progress = max(0.0, monster_hack_progress - 6.0 * delta)
				monster_hack_progress = min(monster_hack_progress, 90.0)

				if door_hold_timer >= door_hold_target_time:
					_on_monster_left_after_closed_door(cur_monster_node, door_hold_target_time)
					return
			else:
				monster_is_moving = true
				door_hold_timer = 0.0
				door_hold_target_time = -1.0

				var hack_speed: float = 4.2 + float(monster_security_level) * 0.4
				if not turbine_working:
					hack_speed += 2.2
				if temp_hacked_by_monster:
					hack_speed += 1.4

				var companion_reduction: float = 2.2 if companion_pc_unlocked else 0.0
				var net_delta: float = (hack_speed - companion_reduction) * delta
				monster_hack_progress = clampf(monster_hack_progress + net_delta, 0.0, 100.0)

			_update_turbine_ui()
			_update_energy_and_temp_hud()
			_update_terminal_lock_state()
			if is_instance_valid(music_box_canvas):
				music_box_canvas.queue_redraw()
			if is_instance_valid(bar_monster_hack):
				bar_monster_hack.value = monster_hack_progress
			if is_instance_valid(lbl_monster_status):
				var move_state_txt = ("🚪 BLOQUEADO EN C%s (%0.1fs)" % [cur_monster_node, door_hold_timer]) if door_is_closed_on_monster else "🚨 HACKEANDO Y AVANZANDO!"
				var comp_txt = "👩‍💻 PC COMPAÑERA: ACTIVA" if companion_pc_unlocked else "🔒 PC COMPAÑERA: BLOQUEADA"
				var cur_node_txt = cur_monster_node if (monster_spotted_on_cam or monster_security_level >= TOTAL_SECURITY_LEVELS) else (_stage_doors_text(monster_security_level) + "?")
				lbl_monster_status.text = "☣️ %s [%s] EN CAM %s: %d%%  |  %s  |  %d/%d" % [
					current_mission.monster_name,
					move_state_txt,
					cur_node_txt,
					int(monster_hack_progress),
					comp_txt,
					gates_closed_by_guard,
					TOTAL_DEFENSES_REQUIRED
				]
				lbl_monster_status.modulate = Color("#00ff9d") if not monster_is_moving else Color("#ff4466")
			_update_3d_previz(delta)

			if monster_hack_progress >= 100.0 and not door_is_closed_on_monster:
				_on_monster_completed_hack("Subject-Zero completó el 100%% de hackeo en el pasillo abierto [C%s]!" % cur_monster_node)
	else:
		_update_3d_previz(delta)

	if vn_active:
		if is_instance_valid(vn_grid_canvas):
			vn_grid_canvas.queue_redraw()
		if vn_typing:
			vn_char_progress += delta * vn_type_speed
			var total_chars = vn_dialogue_rtl.get_total_character_count()
			vn_dialogue_rtl.visible_characters = int(vn_char_progress)
			if vn_dialogue_rtl.visible_characters >= total_chars:
				vn_dialogue_rtl.visible_characters = -1
				vn_typing = false
				vn_next_indicator.visible = not vn_waiting_choice
		elif vn_auto_mode and not vn_waiting_choice and not vn_log_modal.visible:
			vn_auto_timer += delta
			if vn_auto_timer >= 2.2:
				vn_auto_timer = 0.0
				_on_vn_advance_pressed()

# =========================================================
# 1. CARGADOR DE MISIÓN Y FLUJO NOVELA VISUAL <-> CONSOLA
# =========================================================
func load_mission(data: MissionData, launch_vn_intro: bool = false) -> void:
	current_mission = data
	bpm = data.initial_bpm
	max_bpm = data.max_bpm
	affinity = data.initial_affinity
	time_left = data.mission_time_seconds
	btn_continue_vn.visible = false
	if is_instance_valid(death_modal):
		death_modal.visible = false
	if is_instance_valid(victory_modal):
		victory_modal.visible = false

	power_energy = 100.0
	bunker_temperature = NORMAL_TEMP
	temp_hacked_by_monster = false
	light_hacked_by_monster = false
	companion_pc_unlocked = true
	next_light_hack_timer = randf_range(10.0, 22.0)
	next_cooling_hack_timer = randf_range(15.0, 28.0)
	next_pc_hack_timer = randf_range(18.0, 32.0)
	door_hold_timer = 0.0
	door_hold_target_time = -1.0

	monster_security_level = 1
	monster_branch = _random_branch_for_level(1)
	monster_spotted_on_cam = false
	monster_attack_active = false
	monster_cooldown_timer = randf_range(3.5, 6.5)
	monster_last_node_id = _get_monster_node_id()
	monster_advance_on_next_wave = false
	gates_closed_by_guard = 0
	monster_hack_progress = 0.0
	door_node_states = {
		"1A": "OPEN",
		"1": "OPEN",
		"1B": "OPEN",
		"2A": "OPEN",
		"2B": "OPEN",
		"3A": "OPEN",
		"3B": "OPEN",
		"4": "OPEN"
	}
	selected_cam_id = "1"
	naomi_shield_charges = 1 if data.companion_perk == "forgive_hack" else 0
	mia_prediction_ready = (data.companion_perk == "prediction")
	flash_stun_grace = 0.0

	mia_max_lives = 5
	mia_lives = 5
	mia_hp_percent = 100
	mia_bpm = 92
	mia_damage_flash = 0.0
	if is_instance_valid(mia_portrait_rect):
		mia_portrait_rect.modulate = Color(1, 1, 1, 1)

	var is_naomi = (data.agent_name.to_lower() == "naomi")
	var chosen_tex: Texture2D = _load_board_texture("res://assets/sprites/naomi_board.jpg" if is_naomi else "res://assets/sprites/mia_boardui.png")

	if not is_instance_valid(chosen_tex):
		var sheet_name = "naomi" if is_naomi else "mia"
		for ext in ["png", "jpg", "jpeg", "webp"]:
			var candidate = "res://assets/sprites/%s_sheet.%s" % [sheet_name, ext]
			if ResourceLoader.exists(candidate):
				var s_tex: Texture2D = load(candidate)
				var atlas = AtlasTexture.new()
				atlas.atlas = s_tex
				atlas.region = Rect2(s_tex.get_width() * 0.04, 0.0, s_tex.get_width() * 0.42, s_tex.get_height() * 0.72)
				chosen_tex = atlas
				break

	if not is_instance_valid(data.agent_portrait):
		data.agent_portrait = chosen_tex

	if is_instance_valid(mia_portrait_rect):
		mia_portrait_rect.texture = chosen_tex
		mia_portrait_rect.material = _create_portrait_crt_material(Color(0.86, 1.0, 0.94, 1.0) if is_naomi else Color(0.98, 0.88, 1.0, 1.0))
	vn_portrait_rect.texture = data.agent_portrait
	vn_bg_rect.texture = data.vn_background

	var role_icon = "🛡️" if is_naomi else "🔮"
	var role_perk_tag = "AEGIS SHIELD" if is_naomi else "NEURAL PREDICTOR"
	if is_instance_valid(lbl_mia_header):
		lbl_mia_header.text = "COMPAÑERA // %s %s [%s]" % [role_icon, data.agent_name.to_upper(), role_perk_tag]
		lbl_mia_header.modulate = data.agent_color
	_update_mia_vitals_ui()

	if data.seedance_video != "" and ResourceLoader.exists(data.seedance_video):
		var stream = load(data.seedance_video)
		vn_video_player.stream = stream
		vn_video_player.visible = true
		vn_video_player.play()
	else:
		vn_video_player.stop()
		vn_video_player.visible = false

	status_overlay.text = "● TURBINA + LUZ/PERILLAS + PC COMPAÑERA // RED 3-2-2-1"
	status_overlay.modulate = Color("#00ff9d")
	lbl_sector.text = "CONTENCIÓN BÚNKER // ENERGÍA, TEMPERATURA Y CÁMARAS"
	lbl_codename.text = "🔮 MIA PREDICTION" if data.companion_perk == "prediction" else "🛡️ NAOMI 1-HACK SHIELD"
	lbl_codename.modulate = data.agent_color

	vn_portrait_style.border_color = data.agent_color
	tactical_map.queue_redraw()

	tab_container.set_tab_title(0, "🌀 01_TURBINA")
	tab_container.set_tab_title(1, "🎛️ 02_LUZ Y PERILLAS")
	tab_container.set_tab_title(2, "💻 03_PC COMPAÑERA")
	tab_container.current_tab = 0

	music_box_charge = 92.0
	music_box_pulse_grace = 0.0
	monster_is_moving = false
	_sync_knobs_aligned()
	_update_turbine_ui()
	_refresh_lure_tab_ui()
	_update_energy_and_temp_hud()

	bar_trace.max_value = data.mission_time_seconds
	bar_trace.value = data.mission_time_seconds

	rtl_chat.clear()
	_log_chat("SISTEMA", "Red 3-2-2-1 activa. Mantené la [01_TURBINA] >40%% para que no suba la Temperatura ni caiga la Energía.", "#00f0ff")
	_log_chat(data.agent_name.to_upper(), "«Si prendés la Luz del Pasillo en [02_LUZ Y PERILLAS], el monstruo desaparece y tarda un tiempo impredecible en volver. Y si le cerrás su puerta, aguantá entre 0 y 10 segundos hasta que se vaya!»", "#f600ff")

	_generate_breach_matrix()
	_select_camera("1")
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()

	if launch_vn_intro and data.vn_intro_script.strip_edges() != "":
		game_active = false
		game_timer.stop()
		start_vn_sequence(data.vn_intro_script, "intro")
	else:
		vn_active = false
		vn_layer.visible = false
		game_active = true
		game_timer.start()

func _setup_turbine_audio() -> void:
	music_audio_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.12
	music_audio_player.stream = gen
	music_audio_player.volume_db = -16.0
	add_child(music_audio_player)
	music_audio_player.play()
	music_audio_playback = music_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _fill_turbine_audio_buffer() -> void:
	if not is_instance_valid(music_audio_player):
		return
	if not music_audio_player.playing:
		music_audio_player.play()
		music_audio_playback = music_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if music_audio_playback == null:
		return

	var base_freq: float = lerpf(52.0, 115.0, clampf(music_box_charge / 100.0, 0.0, 1.0))
	var frames_avail: int = music_audio_playback.get_frames_available()
	var mix_rate: float = 22050.0
	var inc: float = base_freq / mix_rate
	for _i in range(frames_avail):
		var hum: float = sin(music_audio_phase * TAU) * 0.55 + sin(music_audio_phase * TAU * 2.0) * 0.25
		var air_noise: float = randf_range(-0.18, 0.18) * (music_box_charge / 100.0)
		var sample: float = (hum + air_noise) * 0.14
		music_audio_playback.push_frame(Vector2(sample, sample))
		music_audio_phase = fmod(music_audio_phase + inc, 1.0)

func _start_monster_attack_wave() -> void:
	if not game_active or not is_instance_valid(current_mission):
		return
	if monster_advance_on_next_wave:
		monster_advance_on_next_wave = false
		if monster_security_level < TOTAL_SECURITY_LEVELS:
			monster_security_level += 1
	monster_branch = _random_branch_for_level(monster_security_level)

	var target_node = _get_monster_node_id()
	monster_attack_active = true
	monster_hack_progress = randf_range(12.0, 26.0)
	monster_is_moving = true
	door_hold_timer = 0.0
	door_hold_target_time = -1.0

	if door_node_states.get(target_node, "OPEN") == "LOCKED" and power_energy > 0.0:
		door_hold_target_time = randf_range(1.5, 10.0)
		monster_is_moving = false

	monster_spotted_on_cam = (monster_security_level >= TOTAL_SECURITY_LEVELS) or (selected_cam_id == target_node)
	flash_stun_grace = 0.0

	var branch_msg = " ¡Revisá las cámaras [%s] para encontrarlo!" % _stage_doors_text(monster_security_level) if _is_branching_level(monster_security_level) else " ¡Apareció en la Puerta [%s]!" % target_node

	_log_chat("ALERTA_ENTIDAD", "🚨 [LA ENTIDAD REAPARECIÓ]: Subject-Zero detectado en Nivel %d!%s ¡Vigilá las cámaras y el pulso (BPM) de %s!" % [
		monster_security_level,
		branch_msg,
		current_mission.agent_name
	], "#ff4466")

	_update_turbine_ui()
	_refresh_lure_tab_ui()
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()
	_update_3d_previz(0.0)

# =========================================================
# 2. MOTOR DE NOVELA VISUAL NATIVO (VN STAGE ENGINE)
# =========================================================
func _build_vn_stage_ui() -> void:
	vn_layer = Control.new()
	vn_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_layer.visible = false
	add_child(vn_layer)

	var bg_color = ColorRect.new()
	bg_color.color = Color("#05080d")
	bg_color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_layer.add_child(bg_color)

	vn_bg_rect = TextureRect.new()
	vn_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vn_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vn_bg_rect.modulate = Color(1, 1, 1, 0.35)
	vn_layer.add_child(vn_bg_rect)

	vn_grid_canvas = Control.new()
	vn_grid_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_grid_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_grid_canvas.draw.connect(_draw_vn_cyber_backdrop)
	vn_layer.add_child(vn_grid_canvas)

	var main_margin = MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		main_margin.add_theme_constant_override("margin_" + side, 22)
	vn_layer.add_child(main_margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 14)
	main_margin.add_child(main_vbox)

	var top_panel = _create_cyber_panel(Color(0.05, 0.09, 0.14, 0.92), Color("#00f0ff"), 1, 10)
	main_vbox.add_child(top_panel)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_hbox)

	var vn_badge = _create_badge_label("STORY MODE // VISUAL LINK", Color("#05080d"), Color("#00f0ff"))
	top_hbox.add_child(vn_badge)

	vn_lbl_chapter = Label.new()
	vn_lbl_chapter.text = "CHAPTER 01 // HELIOS TOWER"
	vn_lbl_chapter.modulate = Color("#d8f4ff")
	vn_lbl_chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(vn_lbl_chapter)

	vn_lbl_affinity_chip = Label.new()
	vn_lbl_affinity_chip.text = "♥ BOND: 45%"
	vn_lbl_affinity_chip.modulate = Color("#b829ff")
	top_hbox.add_child(vn_lbl_affinity_chip)

	var btn_log = Button.new()
	btn_log.text = "📜 HISTORY"
	_apply_styled_button(btn_log, Color("#00f0ff"), false)
	btn_log.pressed.connect(func(): vn_log_modal.visible = not vn_log_modal.visible)
	top_hbox.add_child(btn_log)

	vn_btn_auto = Button.new()
	vn_btn_auto.text = "▶ AUTO: OFF"
	_apply_styled_button(vn_btn_auto, Color("#00f0ff"), false)
	vn_btn_auto.pressed.connect(_on_toggle_vn_auto)
	top_hbox.add_child(vn_btn_auto)

	var btn_skip = Button.new()
	btn_skip.text = "⏭ SKIP SCENE"
	_apply_styled_button(btn_skip, Color("#ffaa00"), false)
	btn_skip.pressed.connect(_finish_vn_sequence)
	top_hbox.add_child(btn_skip)

	var stage_center = HBoxContainer.new()
	stage_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_center.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_center.add_theme_constant_override("separation", 28)
	main_vbox.add_child(stage_center)

	vn_portrait_frame = PanelContainer.new()
	vn_portrait_style = StyleBoxFlat.new()
	vn_portrait_style.bg_color = Color(0.06, 0.09, 0.14, 0.90)
	vn_portrait_style.border_color = Color("#b829ff")
	vn_portrait_style.set_border_width_all(2)
	vn_portrait_style.set_corner_radius_all(6)
	vn_portrait_frame.add_theme_stylebox_override("panel", vn_portrait_style)
	vn_portrait_frame.custom_minimum_size = Vector2(360, 340)
	vn_portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_center.add_child(vn_portrait_frame)

	var vn_port_layer = Control.new()
	vn_port_layer.clip_contents = true
	vn_portrait_frame.add_child(vn_port_layer)

	var vn_placeholder = Label.new()
	vn_placeholder.text = "[ AGENT HOLOGRAM ]\n\nSprite / .ogv Video\n(Configurable in MissionData)"
	vn_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vn_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vn_placeholder.modulate = Color(0.65, 0.8, 0.95, 0.3)
	vn_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_port_layer.add_child(vn_placeholder)

	vn_portrait_rect = TextureRect.new()
	vn_portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vn_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vn_port_layer.add_child(vn_portrait_rect)

	vn_video_player = VideoStreamPlayer.new()
	vn_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_video_player.expand = true
	vn_video_player.finished.connect(func(): vn_video_player.play())
	vn_port_layer.add_child(vn_video_player)

	vn_choices_box = VBoxContainer.new()
	vn_choices_box.custom_minimum_size = Vector2(540, 0)
	vn_choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vn_choices_box.add_theme_constant_override("separation", 14)
	vn_choices_box.visible = false
	stage_center.add_child(vn_choices_box)

	var lbl_choice_header = Label.new()
	lbl_choice_header.text = "⚡ DIALOGUE DECISION // SELECT YOUR RESPONSE:"
	lbl_choice_header.modulate = Color("#00f0ff")
	vn_choices_box.add_child(lbl_choice_header)

	vn_choice_btn_1 = Button.new()
	vn_choice_btn_1.custom_minimum_size = Vector2(540, 54)
	vn_choice_btn_1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vn_choice_btn_1.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(vn_choice_btn_1, Color("#b829ff"), true)
	vn_choice_btn_1.pressed.connect(func(): _on_vn_choice_selected(1))
	vn_choices_box.add_child(vn_choice_btn_1)

	vn_choice_btn_2 = Button.new()
	vn_choice_btn_2.custom_minimum_size = Vector2(540, 54)
	vn_choice_btn_2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vn_choice_btn_2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(vn_choice_btn_2, Color("#00f0ff"), true)
	vn_choice_btn_2.pressed.connect(func(): _on_vn_choice_selected(2))
	vn_choices_box.add_child(vn_choice_btn_2)

	var dialogue_box = _create_cyber_panel(Color(0.04, 0.07, 0.12, 0.95), Color("#00f0ff"), 2, 16)
	dialogue_box.custom_minimum_size = Vector2(0, 185)
	dialogue_box.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_vn_advance_pressed()
	)
	main_vbox.add_child(dialogue_box)

	var dlg_vbox = VBoxContainer.new()
	dlg_vbox.add_theme_constant_override("separation", 10)
	dialogue_box.add_child(dlg_vbox)

	var dlg_top_row = HBoxContainer.new()
	dlg_vbox.add_child(dlg_top_row)

	vn_speaker_badge = _create_badge_label("MARIA", Color("#05080d"), Color("#b829ff"))
	dlg_top_row.add_child(vn_speaker_badge)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_top_row.add_child(spacer)

	var lbl_controls_hint = Label.new()
	lbl_controls_hint.text = "[CLICK / SPACE / ENTER TO ADVANCE]"
	lbl_controls_hint.modulate = Color("#557799")
	lbl_controls_hint.add_theme_font_size_override("font_size", 12)
	dlg_top_row.add_child(lbl_controls_hint)

	vn_dialogue_rtl = RichTextLabel.new()
	vn_dialogue_rtl.bbcode_enabled = true
	vn_dialogue_rtl.scroll_active = false
	vn_dialogue_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vn_dialogue_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_dialogue_rtl.add_theme_font_size_override("normal_font_size", 20)
	vn_dialogue_rtl.add_theme_font_size_override("bold_font_size", 20)
	vn_dialogue_rtl.add_theme_constant_override("line_separation", 6)
	dlg_vbox.add_child(vn_dialogue_rtl)

	var dlg_bottom_row = HBoxContainer.new()
	dlg_vbox.add_child(dlg_bottom_row)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_bottom_row.add_child(spacer2)

	vn_next_indicator = Label.new()
	vn_next_indicator.text = "▼ CONTINUE"
	vn_next_indicator.modulate = Color("#00ff9d")
	dlg_bottom_row.add_child(vn_next_indicator)

	vn_log_modal = _create_cyber_panel(Color(0.03, 0.05, 0.09, 0.97), Color("#00f0ff"), 2, 18)
	vn_log_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vn_log_modal.offset_left = 120
	vn_log_modal.offset_top = 80
	vn_log_modal.offset_right = -120
	vn_log_modal.offset_bottom = -80
	vn_log_modal.visible = false
	vn_layer.add_child(vn_log_modal)

	var log_vbox = VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 10)
	vn_log_modal.add_child(log_vbox)

	var log_top = HBoxContainer.new()
	log_vbox.add_child(log_top)

	var log_title = Label.new()
	log_title.text = "📜 CONVERSATION LOG (SCENE HISTORY)"
	log_title.modulate = Color("#00f0ff")
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_top.add_child(log_title)

	var btn_close_log = Button.new()
	btn_close_log.text = "✕ CLOSE"
	_apply_styled_button(btn_close_log, Color("#ff3366"), false)
	btn_close_log.pressed.connect(func(): vn_log_modal.visible = false)
	log_top.add_child(btn_close_log)

	vn_log_rtl = RichTextLabel.new()
	vn_log_rtl.bbcode_enabled = true
	vn_log_rtl.scroll_following = true
	vn_log_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_vbox.add_child(vn_log_rtl)

func start_vn_sequence(raw_script: String, phase: String) -> void:
	vn_phase = phase
	vn_parsed_lines = _parse_vn_script(raw_script)
	if vn_parsed_lines.is_empty():
		_finish_vn_sequence()
		return

	vn_line_index = 0
	vn_waiting_choice = false
	vn_choices_box.visible = false
	vn_log_modal.visible = false
	vn_active = true
	vn_layer.visible = true

	var phase_title = "PRE-INFILTRATION BRIEFING" if phase == "intro" else "OPERATION EPILOGUE"
	vn_lbl_chapter.text = "%s // %s (%s)" % [phase_title, current_mission.sector_name, current_mission.agent_name.to_upper()]
	_update_vn_affinity_chip()
	_show_current_vn_line()

func _parse_vn_script(raw_script: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines = raw_script.split("\n")
	for raw_l in lines:
		var line = raw_l.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts = line.split("|")
		if parts.size() >= 7 and parts[0].strip_edges().to_upper() == "CHOICE":
			result.append({
				"type": "choice",
				"opt1_text": parts[1].strip_edges(),
				"opt1_affinity": int(parts[2].strip_edges()),
				"opt1_reply": parts[3].strip_edges(),
				"opt2_text": parts[4].strip_edges(),
				"opt2_affinity": int(parts[5].strip_edges()),
				"opt2_reply": parts[6].strip_edges()
			})
		elif parts.size() >= 2:
			result.append({
				"type": "line",
				"speaker": parts[0].strip_edges(),
				"text": parts[1].strip_edges()
			})
		else:
			result.append({
				"type": "line",
				"speaker": "NARRATOR",
				"text": line
			})
	return result

func _show_current_vn_line() -> void:
	if vn_line_index >= vn_parsed_lines.size():
		_finish_vn_sequence()
		return

	var entry = vn_parsed_lines[vn_line_index]
	if entry["type"] == "choice":
		vn_waiting_choice = true
		vn_typing = false
		vn_next_indicator.visible = false
		vn_choices_box.visible = true
		vn_choice_btn_1.text = "▸ " + entry["opt1_text"]
		vn_choice_btn_2.text = "▸ " + entry["opt2_text"]
		_apply_styled_button(vn_choice_btn_1, current_mission.agent_color, true)
		return

	vn_waiting_choice = false
	vn_choices_box.visible = false
	var speaker: String = entry["speaker"]
	var text: String = entry["text"]

	var spk_upper = speaker.to_upper()
	var spk_col = Color("#00f0ff")
	if spk_upper == current_mission.agent_name.to_upper():
		spk_col = current_mission.agent_color
		vn_portrait_frame.modulate = Color(1, 1, 1, 1)
	elif spk_upper in ["OPERADOR", "OPERATOR"]:
		spk_col = Color("#00ff9d")
		vn_portrait_frame.modulate = Color(0.75, 0.75, 0.82, 0.95)
	else:
		spk_col = Color("#ffcc00")
		vn_portrait_frame.modulate = Color(0.65, 0.65, 0.75, 0.9)

	_update_badge_style(vn_speaker_badge, spk_upper, Color("#05080d"), spk_col)
	vn_dialogue_rtl.text = text
	vn_dialogue_rtl.visible_characters = 0
	vn_char_progress = 0.0
	vn_typing = true
	vn_next_indicator.visible = false
	vn_auto_timer = 0.0

	var log_line = "[color=#%s][b][%s]:[/b][/color] %s\n\n" % [spk_col.to_html(false), spk_upper, text]
	vn_history_entries.append(log_line)
	vn_log_rtl.append_text(log_line)

func _on_vn_advance_pressed() -> void:
	if not vn_active or vn_waiting_choice:
		return
	if vn_typing:
		vn_typing = false
		vn_dialogue_rtl.visible_characters = -1
		vn_next_indicator.visible = true
		return

	vn_line_index += 1
	_show_current_vn_line()

func _on_vn_choice_selected(option_idx: int) -> void:
	if not vn_waiting_choice:
		return
	var entry = vn_parsed_lines[vn_line_index]
	var chosen_txt = entry["opt1_text"] if option_idx == 1 else entry["opt2_text"]
	var aff_delta = entry["opt1_affinity"] if option_idx == 1 else entry["opt2_affinity"]
	var agent_reply = entry["opt1_reply"] if option_idx == 1 else entry["opt2_reply"]

	affinity = clamp(affinity + aff_delta, 0, 100)
	_update_hud()
	_update_vn_affinity_chip()

	vn_log_rtl.append_text("[color=#00ff9d][b][OPERATOR DECISION]:[/b] %s[/color]\n\n" % chosen_txt)

	vn_waiting_choice = false
	vn_choices_box.visible = false
	vn_parsed_lines[vn_line_index] = {
		"type": "line",
		"speaker": current_mission.agent_name,
		"text": agent_reply
	}
	_show_current_vn_line()

func _finish_vn_sequence() -> void:
	vn_active = false
	vn_layer.visible = false
	if vn_phase == "intro":
		game_active = true
		game_timer.start()
		_log_chat("SYSTEM", "⚡ TACTICAL CONSOLE MODE ACTIVE. Trace countdown initiated.", "#00f0ff")
	else:
		var current_idx = available_missions.find(current_mission)
		if current_idx >= 0 and current_idx + 1 < available_missions.size():
			var next_idx = current_idx + 1
			mission_selector.select(next_idx)
			load_mission(available_missions[next_idx], true)

func _on_toggle_vn_auto() -> void:
	vn_auto_mode = not vn_auto_mode
	vn_auto_timer = 0.0
	vn_btn_auto.text = "▶ AUTO: ON" if vn_auto_mode else "▶ AUTO: OFF"
	_apply_styled_button(vn_btn_auto, Color("#00ff9d") if vn_auto_mode else Color("#00f0ff"), vn_auto_mode)

func _update_vn_affinity_chip() -> void:
	if not is_instance_valid(current_mission):
		return
	vn_lbl_affinity_chip.text = "♥ BOND WITH %s: %d%%" % [current_mission.agent_name.to_upper(), affinity]
	vn_lbl_affinity_chip.modulate = current_mission.agent_color.lightened(0.25)

func _draw_vn_cyber_backdrop() -> void:
	var s = vn_grid_canvas.size
	var col = current_mission.agent_color if is_instance_valid(current_mission) else Color("#00f0ff")
	var grid_c = Color(col.r, col.g, col.b, 0.05)
	var step = 48.0
	var offset = fmod(pulse_phase * 4.0, step)
	var x = offset
	while x < s.x:
		vn_grid_canvas.draw_line(Vector2(x, 0), Vector2(x, s.y), grid_c, 1.0)
		x += step
	var y = 0.0
	while y < s.y:
		vn_grid_canvas.draw_line(Vector2(0, y), Vector2(s.x, y), grid_c, 1.0)
		y += step

# =========================================================
# 3. CONSTRUCCIÓN DE LA CONSOLA DE OPERADOR (INDUSTRIAL GRUNGE UI)
# =========================================================
func _build_universal_ui() -> void:
	clip_contents = true

	# 1. FONDO Y DIORAMA 3D DEL ESCRITORIO, SIRENA ROJA, TAZA Y CARCASA "BÚNKER B7"
	var room_bg = ColorRect.new()
	room_bg.color = Color("#030405")
	room_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(room_bg)

	monitor_3d_diorama = Control.new()
	monitor_3d_diorama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	monitor_3d_diorama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_3d_diorama.visible = not embedded_in_3d_monitor
	monitor_3d_diorama.draw.connect(_draw_3d_monitor_diorama)
	add_child(monitor_3d_diorama)

	var main_margin = MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.clip_contents = true
	var pad_h: int = 8 if embedded_in_3d_monitor else 74
	var pad_v: int = 8 if embedded_in_3d_monitor else 54
	main_margin.add_theme_constant_override("margin_left", pad_h)
	main_margin.add_theme_constant_override("margin_top", pad_v)
	main_margin.add_theme_constant_override("margin_right", 8 if embedded_in_3d_monitor else 88)
	main_margin.add_theme_constant_override("margin_bottom", 8 if embedded_in_3d_monitor else 68)
	add_child(main_margin)

	var screen_bezel_frame = PanelContainer.new()
	var bezel_st = StyleBoxFlat.new()
	bezel_st.bg_color = Color(0.035, 0.045, 0.05, 0.97)
	bezel_st.border_color = Color("#1c2426")
	bezel_st.set_border_width_all(3)
	bezel_st.set_corner_radius_all(6)
	bezel_st.set_content_margin_all(10)
	bezel_st.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	bezel_st.shadow_size = 18
	screen_bezel_frame.add_theme_stylebox_override("panel", bezel_st)
	main_margin.add_child(screen_bezel_frame)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	screen_bezel_frame.add_child(main_vbox)

	# --- HEADER SUPERIOR ESTILO "FACILITY STATUS: CRITICAL ///" ---
	var header = _create_cyber_panel(Color("#0c0e10"), Color("#d9382e"), 2, 7)
	main_vbox.add_child(header)
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	header.add_child(header_vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	header_vbox.add_child(header_hbox)

	var badge = _create_badge_label("▲ FACILITY STATUS: CRITICAL", Color("#ffffff"), Color("#d9382e"))
	header_hbox.add_child(badge)

	var title = Label.new()
	title.text = "////  TURBINA • ENERGÍA • CONTROL TÉRMICO"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color("#d9382e")
	header_hbox.add_child(title)

	lbl_sector = Label.new()
	lbl_sector.text = "MANTÉN LAS PUERTAS CERRADAS Y LA TURBINA ACTIVA"
	lbl_sector.modulate = Color("#88aacc")
	lbl_sector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_hbox.add_child(lbl_sector)

	var btn_open_vn = Button.new()
	btn_open_vn.text = "🎭 VN INTRO"
	_apply_styled_button(btn_open_vn, Color("#b829ff"), false)
	btn_open_vn.pressed.connect(func(): load_mission(current_mission, true))
	header_hbox.add_child(btn_open_vn)

	var lbl_sel = Label.new()
	lbl_sel.text = "COMPAÑERA:"
	lbl_sel.modulate = Color("#88aacc")
	header_hbox.add_child(lbl_sel)

	mission_selector = OptionButton.new()
	mission_selector.fit_to_longest_item = false
	mission_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mission_selector.custom_minimum_size = Vector2(155, 28)
	mission_selector.item_selected.connect(func(idx): load_mission(available_missions[idx], start_in_vn_mode))
	header_hbox.add_child(mission_selector)

	var btn_restart = Button.new()
	btn_restart.text = "↻ REINICIAR"
	_apply_styled_button(btn_restart, Color("#00f0ff"), false)
	btn_restart.pressed.connect(func(): load_mission(current_mission, false))
	header_hbox.add_child(btn_restart)

	lbl_timer = Label.new()
	lbl_timer.text = "12:00 AM (180s)"
	lbl_timer.add_theme_font_size_override("font_size", 15)
	lbl_timer.modulate = Color("#00ff9d")
	header_hbox.add_child(lbl_timer)

	bar_trace = ProgressBar.new()
	bar_trace.custom_minimum_size = Vector2(0, 4)
	bar_trace.show_percentage = false
	_style_progress_bar(bar_trace, Color("#121c29"), Color("#00ff9d"))
	header_vbox.add_child(bar_trace)

	var monster_hbox = HBoxContainer.new()
	monster_hbox.add_theme_constant_override("separation", 10)
	header_vbox.add_child(monster_hbox)

	lbl_monster_status = Label.new()
	lbl_monster_status.text = "☣️ SISTEMA DE HACKEO: EN ESPERA  |  DEFENSAS: 0/5"
	lbl_monster_status.add_theme_font_size_override("font_size", 12)
	lbl_monster_status.modulate = Color("#ff4466")
	lbl_monster_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_monster_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	monster_hbox.add_child(lbl_monster_status)

	bar_monster_hack = ProgressBar.new()
	bar_monster_hack.max_value = 100.0
	bar_monster_hack.custom_minimum_size = Vector2(210, 12)
	bar_monster_hack.show_percentage = false
	_style_progress_bar(bar_monster_hack, Color("#1f0910"), Color("#b829ff"))
	monster_hbox.add_child(bar_monster_hack)

	# --- BANNER DE ALERTA DE HACKEO EN VIVO ---
	hack_alert_banner = PanelContainer.new()
	hack_alert_style = StyleBoxFlat.new()
	hack_alert_style.bg_color = Color(0.28, 0.03, 0.07, 0.95)
	hack_alert_style.border_color = Color("#ff1744")
	hack_alert_style.set_border_width_all(2)
	hack_alert_style.set_corner_radius_all(4)
	hack_alert_style.set_content_margin_all(6)
	hack_alert_banner.add_theme_stylebox_override("panel", hack_alert_style)
	hack_alert_banner.visible = false
	header_vbox.add_child(hack_alert_banner)

	var alert_hbox = HBoxContainer.new()
	alert_hbox.add_theme_constant_override("separation", 10)
	hack_alert_banner.add_child(alert_hbox)

	lbl_hack_alert_banner = Label.new()
	lbl_hack_alert_banner.text = "🚨 ¡ALERTA DE SABOTAJE! SISTEMAS HACKEADOS POR SUBJECT-ZERO"
	lbl_hack_alert_banner.add_theme_font_size_override("font_size", 13)
	lbl_hack_alert_banner.modulate = Color("#ffccd5")
	lbl_hack_alert_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_hack_alert_banner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	alert_hbox.add_child(lbl_hack_alert_banner)

	btn_hack_alert_goto = Button.new()
	btn_hack_alert_goto.text = "🛠️ IR A REPARAR >>"
	btn_hack_alert_goto.custom_minimum_size = Vector2(150, 26)
	btn_hack_alert_goto.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_hack_alert_goto, Color("#ff1744"), true)
	btn_hack_alert_goto.pressed.connect(_on_hack_alert_goto_pressed)
	alert_hbox.add_child(btn_hack_alert_goto)

	# --- SPLIT CENTRAL ---
	var split = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	main_vbox.add_child(split)

	# COLUMNA IZQUIERDA (MONITORES + ENERGÍA/TEMPERATURA + CHAT)
	var left_vbox = VBoxContainer.new()
	left_vbox.clip_contents = true
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.05
	left_vbox.add_theme_constant_override("separation", 8)
	split.add_child(left_vbox)

	var monitor_panel = _create_cyber_panel(Color("#080d14"), Color("#1e3246"), 1, 8)
	monitor_panel.custom_minimum_size = Vector2(280, 255)
	monitor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_panel.size_flags_stretch_ratio = 1.4
	left_vbox.add_child(monitor_panel)

	var monitor_vbox = VBoxContainer.new()
	monitor_vbox.add_theme_constant_override("separation", 6)
	monitor_panel.add_child(monitor_vbox)

	var monitor_top_bar = HBoxContainer.new()
	monitor_vbox.add_child(monitor_top_bar)

	status_overlay = Label.new()
	status_overlay.modulate = Color("#00ff9d")
	status_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_overlay.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	monitor_top_bar.add_child(status_overlay)

	lbl_codename = Label.new()
	lbl_codename.text = "ID: VALKYRIE-01"
	monitor_top_bar.add_child(lbl_codename)

	var monitor_hbox = HBoxContainer.new()
	monitor_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_hbox.add_theme_constant_override("separation", 6)
	monitor_vbox.add_child(monitor_hbox)

	# --- RETRATO DE COMPAÑERA ACTIVA ---
	var mia_portrait_frame = PanelContainer.new()
	mia_portrait_border_style = StyleBoxFlat.new()
	mia_portrait_border_style.bg_color = Color("#140d1c")
	mia_portrait_border_style.border_color = Color("#f600ff")
	mia_portrait_border_style.set_border_width_all(2)
	mia_portrait_border_style.set_corner_radius_all(4)
	mia_portrait_frame.add_theme_stylebox_override("panel", mia_portrait_border_style)
	mia_portrait_frame.custom_minimum_size = Vector2(175, 0)
	mia_portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_hbox.add_child(mia_portrait_frame)

	var mia_portrait_layer = Control.new()
	mia_portrait_layer.clip_contents = true
	mia_portrait_frame.add_child(mia_portrait_layer)

	var mia_placeholder = Label.new()
	mia_placeholder.text = "[ COMPAÑERA ]"
	mia_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mia_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mia_placeholder.modulate = Color(0.9, 0.5, 0.95, 0.28)
	mia_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mia_portrait_layer.add_child(mia_placeholder)

	mia_portrait_rect = TextureRect.new()
	mia_portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mia_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mia_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mia_portrait_rect.material = _create_portrait_crt_material(Color(0.98, 0.88, 1.0, 1.0))
	mia_portrait_layer.add_child(mia_portrait_rect)

	var mia_crt_overlay = _create_portrait_crt_overlay(Color(0.96, 0.0, 1.0, 1.0))
	mia_portrait_layer.add_child(mia_crt_overlay)

	var mia_top_bar = PanelContainer.new()
	mia_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mia_top_bar.offset_bottom = 38
	var mia_top_st = StyleBoxFlat.new()
	mia_top_st.bg_color = Color(0.06, 0.02, 0.09, 0.88)
	mia_top_st.border_width_bottom = 1
	mia_top_st.border_color = Color(0.96, 0.0, 1.0, 0.35)
	mia_top_st.set_content_margin_all(3)
	mia_top_bar.add_theme_stylebox_override("panel", mia_top_st)
	mia_portrait_layer.add_child(mia_top_bar)

	var mia_top_vbox = VBoxContainer.new()
	mia_top_vbox.add_theme_constant_override("separation", 2)
	mia_top_bar.add_child(mia_top_vbox)

	var mia_hdr_hbox = HBoxContainer.new()
	mia_hdr_hbox.add_theme_constant_override("separation", 2)
	mia_top_vbox.add_child(mia_hdr_hbox)

	lbl_mia_header = Label.new()
	lbl_mia_header.text = "🔮 COMPAÑERA // MIA"
	lbl_mia_header.add_theme_font_size_override("font_size", 10)
	lbl_mia_header.modulate = Color("#f600ff")
	mia_hdr_hbox.add_child(lbl_mia_header)

	lbl_mia_hearts = Label.new()
	lbl_mia_hearts.text = "♥♥♥♥♥"
	lbl_mia_hearts.add_theme_font_size_override("font_size", 10)
	lbl_mia_hearts.modulate = Color("#ff1744")
	lbl_mia_hearts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_mia_hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mia_hdr_hbox.add_child(lbl_mia_hearts)

	bar_mia_hp = ProgressBar.new()
	bar_mia_hp.max_value = 100.0
	bar_mia_hp.value = 100.0
	bar_mia_hp.custom_minimum_size = Vector2(0, 5)
	bar_mia_hp.show_percentage = false
	_style_progress_bar(bar_mia_hp, Color("#240814"), Color("#ff1744"))
	mia_top_vbox.add_child(bar_mia_hp)

	var mia_bpm_backdrop = PanelContainer.new()
	mia_bpm_backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	mia_bpm_backdrop.offset_top = -38
	var mia_bd_style = StyleBoxFlat.new()
	mia_bd_style.bg_color = Color(0.06, 0.02, 0.09, 0.88)
	mia_bd_style.border_width_top = 1
	mia_bd_style.border_color = Color(1.0, 0.09, 0.27, 0.35)
	mia_bd_style.set_content_margin_all(4)
	mia_bpm_backdrop.add_theme_stylebox_override("panel", mia_bd_style)
	mia_portrait_layer.add_child(mia_bpm_backdrop)

	var mia_bpm_hbox = HBoxContainer.new()
	mia_bpm_hbox.add_theme_constant_override("separation", 4)
	mia_bpm_backdrop.add_child(mia_bpm_hbox)

	lbl_mia_heart_icon = Label.new()
	lbl_mia_heart_icon.text = "♥"
	lbl_mia_heart_icon.add_theme_font_size_override("font_size", 18)
	lbl_mia_heart_icon.modulate = Color("#ff1744")
	lbl_mia_heart_icon.pivot_offset = Vector2(8, 12)
	mia_bpm_hbox.add_child(lbl_mia_heart_icon)

	lbl_mia_bpm_overlay = Label.new()
	lbl_mia_bpm_overlay.text = "BIEN (92)"
	lbl_mia_bpm_overlay.add_theme_font_size_override("font_size", 11)
	lbl_mia_bpm_overlay.modulate = Color("#00ff9d")
	mia_bpm_hbox.add_child(lbl_mia_bpm_overlay)

	mia_ecg_graph = Control.new()
	mia_ecg_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mia_ecg_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mia_ecg_graph.draw.connect(_draw_mia_ecg_wave)
	mia_bpm_hbox.add_child(mia_ecg_graph)

	# --- MONITOR PREVIZ 3D DE CÁMARA DE SEGURIDAD ---
	var previz_3d_panel = _build_3d_camera_previz()
	monitor_hbox.add_child(previz_3d_panel)

	# --- MAPA INTERACTIVO 3 - 2 - 2 - 1 DE CÁMARAS Y PUERTAS ---
	var map_frame = _create_cyber_panel(Color("#050910"), Color("#192a3c"), 1, 4)
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_stretch_ratio = 1.15
	monitor_hbox.add_child(map_frame)

	tactical_map = Control.new()
	tactical_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tactical_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tactical_map.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tactical_map.draw.connect(_draw_tactical_map)
	tactical_map.gui_input.connect(_on_tactical_map_gui_input)
	map_frame.add_child(tactical_map)

	var cam_bar_hbox = HBoxContainer.new()
	cam_bar_hbox.add_theme_constant_override("separation", 5)
	monitor_vbox.add_child(cam_bar_hbox)

	var lbl_cam_bar = Label.new()
	lbl_cam_bar.text = "🎥 CÁMARAS DEL BÚNKER:"
	lbl_cam_bar.add_theme_font_size_override("font_size", 11)
	lbl_cam_bar.modulate = Color("#88ccee")
	cam_bar_hbox.add_child(lbl_cam_bar)

	cam_select_buttons.clear()
	for cam_id in CAM_NODE_IDS:
		var c_btn = Button.new()
		c_btn.text = "C" + cam_id
		c_btn.custom_minimum_size = Vector2(0, 26)
		c_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_btn.clip_text = true
		c_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c_btn.pressed.connect(func(): _select_camera(cam_id))
		cam_bar_hbox.add_child(c_btn)
		cam_select_buttons[cam_id] = c_btn

	# --- PANEL DE ENERGÍA, TEMPERATURA Y SISTEMA DE HACKEO ---
	var bio_panel = _create_cyber_panel(Color("#0a1018"), Color("#1c2d3f"), 1, 8)
	left_vbox.add_child(bio_panel)
	var bio_vbox = VBoxContainer.new()
	bio_vbox.add_theme_constant_override("separation", 6)
	bio_panel.add_child(bio_vbox)

	var gauges_hbox = HBoxContainer.new()
	gauges_hbox.add_theme_constant_override("separation", 14)
	bio_vbox.add_child(gauges_hbox)

	var nrg_vbox = VBoxContainer.new()
	nrg_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrg_vbox.add_theme_constant_override("separation", 3)
	gauges_hbox.add_child(nrg_vbox)

	var nrg_top = HBoxContainer.new()
	nrg_vbox.add_child(nrg_top)
	var lbl_nrg_title = Label.new()
	lbl_nrg_title.text = "⚡ ENERGÍA"
	lbl_nrg_title.add_theme_font_size_override("font_size", 12)
	lbl_nrg_title.modulate = Color("#aaddff")
	lbl_nrg_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrg_top.add_child(lbl_nrg_title)

	lbl_energy_val = Label.new()
	lbl_energy_val.text = "100%"
	lbl_energy_val.add_theme_font_size_override("font_size", 13)
	lbl_energy_val.modulate = Color("#00ff9d")
	nrg_top.add_child(lbl_energy_val)

	bar_energy = ProgressBar.new()
	bar_energy.max_value = 100.0
	bar_energy.value = 100.0
	bar_energy.custom_minimum_size = Vector2(0, 8)
	bar_energy.show_percentage = false
	_style_progress_bar(bar_energy, Color("#101b24"), Color("#00ff9d"))
	nrg_vbox.add_child(bar_energy)

	var tmp_vbox = VBoxContainer.new()
	tmp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tmp_vbox.add_theme_constant_override("separation", 3)
	gauges_hbox.add_child(tmp_vbox)

	var tmp_top = HBoxContainer.new()
	tmp_vbox.add_child(tmp_top)
	var lbl_tmp_title = Label.new()
	lbl_tmp_title.text = "🌡️ TEMPERATURA"
	lbl_tmp_title.add_theme_font_size_override("font_size", 12)
	lbl_tmp_title.modulate = Color("#aaddff")
	lbl_tmp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tmp_top.add_child(lbl_tmp_title)

	lbl_temp_val = Label.new()
	lbl_temp_val.text = "24°C"
	lbl_temp_val.add_theme_font_size_override("font_size", 13)
	lbl_temp_val.modulate = Color("#00f0ff")
	tmp_top.add_child(lbl_temp_val)

	bar_temperature = ProgressBar.new()
	bar_temperature.min_value = 20.0
	bar_temperature.max_value = 100.0
	bar_temperature.value = 24.0
	bar_temperature.custom_minimum_size = Vector2(0, 8)
	bar_temperature.show_percentage = false
	_style_progress_bar(bar_temperature, Color("#101b24"), Color("#00f0ff"))
	tmp_vbox.add_child(bar_temperature)

	var bio_header = HBoxContainer.new()
	bio_header.add_theme_constant_override("separation", 8)
	bio_vbox.add_child(bio_header)

	lbl_affinity = Label.new()
	lbl_affinity.modulate = Color("#00f0ff")
	lbl_affinity.add_theme_font_size_override("font_size", 11)
	lbl_affinity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_affinity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bio_header.add_child(lbl_affinity)

	lbl_companion_hack_status = Label.new()
	lbl_companion_hack_status.text = "👩‍💻 PC COMPAÑERA: ACTIVA"
	lbl_companion_hack_status.add_theme_font_size_override("font_size", 11)
	lbl_companion_hack_status.modulate = Color("#00ff9d")
	bio_header.add_child(lbl_companion_hack_status)

	lbl_perk_status = Label.new()
	lbl_perk_status.text = "🔮 PERK LISTO"
	lbl_perk_status.add_theme_font_size_override("font_size", 11)
	lbl_perk_status.modulate = Color("#f600ff")
	bio_header.add_child(lbl_perk_status)

	bar_affinity = ProgressBar.new()
	bar_affinity.max_value = 100
	bar_affinity.custom_minimum_size = Vector2(0, 4)
	bar_affinity.show_percentage = false
	_style_progress_bar(bar_affinity, Color("#121d2b"), Color("#00f0ff"))
	bio_vbox.add_child(bar_affinity)

	btn_companion_perk = Button.new()
	btn_companion_perk.text = "🔮 USAR HABILIDAD DE COMPAÑERA"
	btn_companion_perk.custom_minimum_size = Vector2(0, 28)
	btn_companion_perk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_companion_perk.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_companion_perk.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_companion_perk, Color("#f600ff"), true)
	btn_companion_perk.pressed.connect(_on_companion_perk_pressed)
	bio_vbox.add_child(btn_companion_perk)

	# --- CHAT / LOG ---
	var chat_panel = _create_cyber_panel(Color("#090e16"), Color("#1e2d3d"), 1, 8)
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_panel.size_flags_stretch_ratio = 0.80
	left_vbox.add_child(chat_panel)

	var chat_vbox = VBoxContainer.new()
	chat_vbox.add_theme_constant_override("separation", 4)
	chat_panel.add_child(chat_vbox)

	rtl_chat = RichTextLabel.new()
	rtl_chat.bbcode_enabled = true
	rtl_chat.scroll_following = true
	rtl_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl_chat.add_theme_constant_override("line_separation", 2)
	chat_vbox.add_child(rtl_chat)

	btn_continue_vn = Button.new()
	btn_continue_vn.text = "🎭 VER EPÍLOGO (NOVELA VISUAL) >>"
	btn_continue_vn.custom_minimum_size = Vector2(0, 34)
	btn_continue_vn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_continue_vn, Color("#00ff9d"), true)
	btn_continue_vn.visible = false
	btn_continue_vn.pressed.connect(_launch_outro_vn)
	chat_vbox.add_child(btn_continue_vn)

	# COLUMNA DERECHA (3 TABS: TURBINA + LUZ/PERILLAS + PC COMPAÑERA + PUERTAS)
	var right_vbox = VBoxContainer.new()
	right_vbox.clip_contents = true
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.95
	right_vbox.add_theme_constant_override("separation", 8)
	split.add_child(right_vbox)

	tab_container = TabContainer.new()
	tab_container.clip_contents = true
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tab_container(tab_container)
	right_vbox.add_child(tab_container)

	tab_container.add_child(_build_turbine_tab())
	tab_container.add_child(_build_light_and_knobs_tab())
	tab_container.add_child(_build_hacking_minigame_tab())

	# PANEL DE CONTROL DE PUERTAS CON CONSUMO DE ENERGÍA
	var term_panel = _create_cyber_panel(Color("#0c131f"), Color("#00f0ff"), 2, 10)
	term_panel.clip_contents = true
	right_vbox.add_child(term_panel)

	var term_vbox = VBoxContainer.new()
	term_vbox.add_theme_constant_override("separation", 6)
	term_panel.add_child(term_vbox)

	var term_header_hbox = HBoxContainer.new()
	term_header_hbox.add_theme_constant_override("separation", 8)
	term_vbox.add_child(term_header_hbox)

	var lbl_term = Label.new()
	lbl_term.text = "🚪 CONTROL DE PUERTAS (SE VA EN 0-10s RANDOM // CONSUME ⚡)"
	lbl_term.modulate = Color("#00f0ff")
	lbl_term.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_term.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	term_header_hbox.add_child(lbl_term)

	lbl_code_progress_status = Label.new()
	lbl_code_progress_status.text = "PUERTAS CERRADAS: 0"
	lbl_code_progress_status.modulate = Color("#00ff9d")
	lbl_code_progress_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	term_header_hbox.add_child(lbl_code_progress_status)

	lock_banner = _create_cyber_panel(Color("#1b111c"), Color("#ffaa00"), 1, 5)
	term_vbox.add_child(lock_banner)

	lbl_lock_banner = Label.new()
	lbl_lock_banner.text = "Cerrá la puerta del pasillo donde esté el monstruo: tardará entre 0 y 10 segundos aleatorios en irse mientras mantengas la puerta cerrada con Energía."
	lbl_lock_banner.modulate = Color("#ffcc44")
	lbl_lock_banner.add_theme_font_size_override("font_size", 11)
	lbl_lock_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_lock_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_banner.add_child(lbl_lock_banner)

	var hbox_btns = HBoxContainer.new()
	hbox_btns.add_theme_constant_override("separation", 6)
	term_vbox.add_child(hbox_btns)

	btn_inject = Button.new()
	btn_inject.custom_minimum_size = Vector2(0, 40)
	btn_inject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_inject.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_inject.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_inject, Color("#00f0ff"), true)
	btn_inject.pressed.connect(func(): _on_seal_door_choice_pressed("A"))
	hbox_btns.add_child(btn_inject)

	btn_seal_door_b = Button.new()
	btn_seal_door_b.custom_minimum_size = Vector2(0, 40)
	btn_seal_door_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seal_door_b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_seal_door_b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_seal_door_b, Color("#00ff9d"), true)
	btn_seal_door_b.visible = false
	btn_seal_door_b.pressed.connect(func(): _on_seal_door_choice_pressed("B"))
	hbox_btns.add_child(btn_seal_door_b)

	btn_seal_door_c = Button.new()
	btn_seal_door_c.custom_minimum_size = Vector2(0, 40)
	btn_seal_door_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seal_door_c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_seal_door_c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_seal_door_c, Color("#ffcc00"), true)
	btn_seal_door_c.visible = false
	btn_seal_door_c.pressed.connect(func(): _on_seal_door_choice_pressed("C"))
	hbox_btns.add_child(btn_seal_door_c)

	btn_open_all_doors = Button.new()
	btn_open_all_doors.text = "🔓 ABRIR TODAS (AHORRAR ⚡)"
	btn_open_all_doors.custom_minimum_size = Vector2(130, 40)
	btn_open_all_doors.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_open_all_doors.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_open_all_doors, Color("#ffaa00"), false)
	btn_open_all_doors.pressed.connect(_on_open_all_doors_pressed)
	hbox_btns.add_child(btn_open_all_doors)

	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_second_tick)
	add_child(game_timer)

# =========================================================
# 4A. TAB 01: TURBINA DE VENTILACIÓN Y TEMPERATURA
# =========================================================
func _build_turbine_tab() -> Control:
	var wrapper = _create_doc_tab_wrapper()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	wrapper.add_child(vbox)

	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var lbl_mb_title = Label.new()
	lbl_mb_title.text = "🌀 TURBINA DE REFRIGERACIÓN CENTRAL // CONTROL TÉRMICO"
	lbl_mb_title.modulate = Color("#00f0ff")
	lbl_mb_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_mb_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_hbox.add_child(lbl_mb_title)

	lbl_music_status = Label.new()
	lbl_music_status.text = "🌀 RPM: 90%"
	lbl_music_status.modulate = Color("#00ff9d")
	top_hbox.add_child(lbl_music_status)

	var lbl_desc = Label.new()
	lbl_desc.text = "¡Mantené la Turbina por encima del 40%! Si deja de funcionar (o si el monstruo hackea la refrigeración y ves que el BPM de tu compañera se dispara), la TEMPERATURA sube hasta 100°C y la ENERGÍA cae rápido."
	lbl_desc.modulate = Color("#99badd")
	lbl_desc.add_theme_font_size_override("font_size", 12)
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_desc)

	bar_music_box = ProgressBar.new()
	bar_music_box.max_value = 100.0
	bar_music_box.value = 90.0
	bar_music_box.custom_minimum_size = Vector2(0, 20)
	bar_music_box.show_percentage = true
	_style_progress_bar(bar_music_box, Color("#0a1420"), Color("#00ff9d"))
	vbox.add_child(bar_music_box)

	lbl_music_beast_state = Label.new()
	lbl_music_beast_state.text = "🌀 TURBINA ESTABLE — TEMPERATURA Y ENERGÍA CONTROLADAS"
	lbl_music_beast_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_music_beast_state.add_theme_font_size_override("font_size", 14)
	lbl_music_beast_state.modulate = Color("#00ff9d")
	lbl_music_beast_state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(lbl_music_beast_state)

	var canvas_frame = _create_cyber_panel(Color("#060b12"), Color("#1b3248"), 1, 6)
	canvas_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(canvas_frame)

	music_box_canvas = Control.new()
	music_box_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_box_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	music_box_canvas.draw.connect(_draw_turbine_device)
	canvas_frame.add_child(music_box_canvas)

	btn_wind_music = Button.new()
	btn_wind_music.text = "🌀 IMPULSAR TURBINA DE VENTILACIÓN (+22% RPM)"
	btn_wind_music.custom_minimum_size = Vector2(0, 52)
	btn_wind_music.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_wind_music.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_wind_music, Color("#00ff9d"), true)
	btn_wind_music.pressed.connect(_on_wind_turbine_pressed)
	vbox.add_child(btn_wind_music)

	var nav_hbox = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(nav_hbox)

	var btn_to_tab2 = Button.new()
	btn_to_tab2.text = "🎛️ IR A LUZ Y PERILLAS [TAB 02] >>"
	btn_to_tab2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_to_tab2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_styled_button(btn_to_tab2, Color("#00f0ff"), false)
	btn_to_tab2.pressed.connect(func(): tab_container.current_tab = 1)
	nav_hbox.add_child(btn_to_tab2)

	var btn_to_tab3 = Button.new()
	btn_to_tab3.text = "💻 DESBLOQUEAR PC COMPAÑERA [TAB 03] >>"
	btn_to_tab3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_to_tab3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_styled_button(btn_to_tab3, Color("#f600ff"), false)
	btn_to_tab3.pressed.connect(func(): tab_container.current_tab = 2)
	nav_hbox.add_child(btn_to_tab3)

	return wrapper

func _on_wind_turbine_pressed() -> void:
	if not game_active:
		return
	if power_energy <= 0.0:
		_log_chat("SISTEMA", "⚠️ ¡Sin energía eléctrica! Abrí puertas cerradas para recuperar el generador auxiliar.", "#ff1744")
		return
	music_box_charge = min(100.0, music_box_charge + 22.0)
	music_box_pulse_grace = 1.8
	if music_box_charge >= 85.0 and temp_hacked_by_monster and companion_pc_unlocked:
		temp_hacked_by_monster = false
		_log_chat("SISTEMA", "🌀 Turbina al máximo + PC de compañera activa: ¡Sabotaje térmico purgado!", "#00ff9d")
	_update_turbine_ui()
	_refresh_lure_tab_ui()
	if is_instance_valid(music_box_canvas):
		music_box_canvas.queue_redraw()

func _update_turbine_ui() -> void:
	if is_instance_valid(bar_music_box):
		bar_music_box.value = music_box_charge

	var turbine_ok: bool = (music_box_charge >= 40.0 and power_energy > 0.0)
	if is_instance_valid(lbl_music_status):
		lbl_music_status.text = ("🌀 ACTIVA: %d%%" % int(music_box_charge)) if turbine_ok else ("🚨 DETENIDA (<40%%): %d%%" % int(music_box_charge))
		lbl_music_status.modulate = Color("#00ff9d") if turbine_ok else Color("#ff1744")

	if is_instance_valid(lbl_music_beast_state):
		if not turbine_ok:
			lbl_music_beast_state.text = "🚨 ¡TURBINA PARADA! TEMPERATURA SUBIENDO (%d°C) Y ENERGÍA CAYENDO RÁPIDO!" % int(bunker_temperature)
			lbl_music_beast_state.modulate = Color("#ff1744")
		else:
			lbl_music_beast_state.text = "🌀 TURBINA REFRIGERANDO (%d%%) — TEMP: %d°C  |  ENERGÍA: %d%%" % [int(music_box_charge), int(bunker_temperature), int(power_energy)]
			lbl_music_beast_state.modulate = Color("#00ff9d")

	if is_instance_valid(btn_wind_music):
		btn_wind_music.text = "🌀 IMPULSAR TURBINA (+22% RPM — MANTENER ARRIBA DE 40%)"
		_apply_styled_button(btn_wind_music, Color("#00ff9d") if turbine_ok else Color("#ff1744"), true)

func _draw_turbine_device() -> void:
	if not is_instance_valid(music_box_canvas):
		return
	var s = music_box_canvas.size
	if s.x < 30 or s.y < 30:
		return
	var font = ThemeDB.fallback_font
	var center = Vector2(s.x * 0.24, s.y * 0.5)
	var radius = min(s.x * 0.17, s.y * 0.38)
	var turbine_ok = (music_box_charge >= 40.0 and power_energy > 0.0)
	var col = Color("#00ff9d") if turbine_ok else Color("#ff1744")

	music_box_canvas.draw_circle(center, radius, Color(col.r, col.g, col.b, 0.12))
	music_box_canvas.draw_arc(center, radius, 0, TAU, 36, col, 2.8)
	music_box_canvas.draw_circle(center, radius * 0.24, col)
	for i in range(6):
		var ang = music_gear_angle + float(i) * (TAU / 6.0)
		var p1 = center + Vector2(cos(ang), sin(ang)) * (radius * 0.24)
		var p2 = center + Vector2(cos(ang + 0.22), sin(ang + 0.22)) * (radius * 0.92)
		var p3 = center + Vector2(cos(ang - 0.15), sin(ang - 0.15)) * (radius * 0.85)
		music_box_canvas.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(col.r, col.g, col.b, 0.65))

	var wave_start_x = s.x * 0.46
	var wave_end_x = s.x * 0.94
	var mid_y = s.y * 0.55
	var pts = PackedVector2Array()
	var steps = 42
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var wx = lerpf(wave_start_x, wave_end_x, t)
		var amp = (s.y * 0.26 * (music_box_charge / 100.0)) if turbine_ok else (s.y * 0.05)
		var wy = mid_y + sin(t * 16.0 - music_gear_angle * 3.0) * amp
		pts.append(Vector2(wx, wy))
	music_box_canvas.draw_polyline(pts, col, 2.2)

	var state_str = "TURBINA ACTIVA (%d%%) — TEMP: %d°C" % [int(music_box_charge), int(bunker_temperature)] if turbine_ok else "¡TURBINA CAÍDA! CALOR SUBIENDO Y ENERGÍA DRENÁNDOSE!"
	music_box_canvas.draw_string(font, Vector2(wave_start_x, 22), state_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

# =========================================================
# 4B. TAB 02: LUZ DEL PASILLO + JUEGO DE PERILLAS ALEATORIAS
# =========================================================
func _build_light_and_knobs_tab() -> Control:
	var wrapper = _create_doc_tab_wrapper()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	wrapper.add_child(vbox)

	lbl_lure_title = Label.new()
	lbl_lure_title.text = "🔦 LUZ DEL PASILLO & 🎛️ CALIBRACIÓN DE PERILLAS"
	lbl_lure_title.modulate = Color("#00f0ff")
	lbl_lure_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(lbl_lure_title)

	var sys_panel = _create_cyber_panel(Color("#070c14"), Color("#1e3448"), 1, 6)
	vbox.add_child(sys_panel)

	var sys_hbox = HBoxContainer.new()
	sys_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sys_hbox.add_theme_constant_override("separation", 8)
	sys_panel.add_child(sys_hbox)

	lbl_sys_audio_badge = _create_badge_label("🌀 VENTILACIÓN", Color("#05080d"), Color("#00ff9d"))
	sys_hbox.add_child(lbl_sys_audio_badge)

	lbl_sys_video_badge = _create_badge_label("🔦 LUZ: LISTA", Color("#05080d"), Color("#00ff9d"))
	sys_hbox.add_child(lbl_sys_video_badge)

	lbl_sys_door_badge = _create_badge_label("💻 PC COMPAÑERA: OK", Color("#05080d"), Color("#00ff9d"))
	sys_hbox.add_child(lbl_sys_door_badge)

	lbl_lure_selected_cam = Label.new()
	lbl_lure_selected_cam.text = "🎥 PASILLO SELECCIONADO: [ CAM C1 ] (Hacé clic en el mapa para cambiar de pasillo)"
	lbl_lure_selected_cam.modulate = Color("#ffcc00")
	lbl_lure_selected_cam.add_theme_font_size_override("font_size", 12)
	lbl_lure_selected_cam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(lbl_lure_selected_cam)

	lbl_lure_hint = Label.new()
	lbl_lure_hint.text = "• Al prender la LUZ DEL PASILLO donde está el monstruo, este DESAPARECE de las cámaras y tarda un tiempo IMPREDECIBLE en volver (-8% Energía).\n• Cuando el monstruo HACKEA LA LUZ, mantené click y girá las 4 PERILLAS hacia sus marcas verdes META."
	lbl_lure_hint.modulate = Color("#99badd")
	lbl_lure_hint.add_theme_font_size_override("font_size", 11)
	lbl_lure_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_lure_hint)

	var knobs_panel = _create_cyber_panel(Color("#060b12"), Color("#1e3448"), 1, 8)
	knobs_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(knobs_panel)

	var knobs_hbox = HBoxContainer.new()
	knobs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	knobs_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knobs_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	knobs_hbox.add_theme_constant_override("separation", 12)
	knobs_panel.add_child(knobs_hbox)

	knob_canvases.clear()
	knob_val_labels.clear()
	for k_idx in range(KNOB_COUNT):
		var k_card = _create_cyber_panel(Color("#09111c"), Color("#223a52"), 1, 6)
		k_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		knobs_hbox.add_child(k_card)

		var kv = VBoxContainer.new()
		kv.alignment = BoxContainer.ALIGNMENT_CENTER
		kv.add_theme_constant_override("separation", 4)
		k_card.add_child(kv)

		var k_title = Label.new()
		k_title.text = "PERILLA %d" % (k_idx + 1)
		k_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k_title.add_theme_font_size_override("font_size", 11)
		k_title.modulate = Color("#88ccee")
		kv.add_child(k_title)

		var k_canvas = Control.new()
		k_canvas.custom_minimum_size = Vector2(68, 68)
		k_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		k_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bound_idx = k_idx
		k_canvas.draw.connect(func(): _draw_single_knob(bound_idx))
		k_canvas.gui_input.connect(func(ev): _on_knob_canvas_gui_input(ev, bound_idx))
		kv.add_child(k_canvas)
		knob_canvases.append(k_canvas)

		var k_lbl = Label.new()
		k_lbl.text = "2 / META: 2"
		k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k_lbl.add_theme_font_size_override("font_size", 11)
		kv.add_child(k_lbl)
		knob_val_labels.append(k_lbl)

		var k_btns = HBoxContainer.new()
		k_btns.alignment = BoxContainer.ALIGNMENT_CENTER
		k_btns.add_theme_constant_override("separation", 6)
		kv.add_child(k_btns)

		var b_left = Button.new()
		b_left.text = "◀"
		b_left.custom_minimum_size = Vector2(30, 26)
		_apply_styled_button(b_left, Color("#00f0ff"), false)
		b_left.pressed.connect(func(): _rotate_knob(bound_idx, -1))
		k_btns.add_child(b_left)

		var b_right = Button.new()
		b_right.text = "▶"
		b_right.custom_minimum_size = Vector2(30, 26)
		_apply_styled_button(b_right, Color("#00f0ff"), false)
		b_right.pressed.connect(func(): _rotate_knob(bound_idx, 1))
		k_btns.add_child(b_right)

	btn_hallway_light = Button.new()
	btn_hallway_light.text = "🔦 PRENDER LUZ DEL PASILLO [CAM C1] (-8% ENERGÍA // HACE DESAPARECER AL MONSTRUO)"
	btn_hallway_light.custom_minimum_size = Vector2(0, 46)
	btn_hallway_light.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_hallway_light.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_hallway_light, Color("#00ff9d"), true)
	btn_hallway_light.pressed.connect(_on_hallway_light_pressed)
	vbox.add_child(btn_hallway_light)

	btn_goto_reboot = Button.new()
	btn_goto_reboot.text = "💻 ¡PC DE COMPAÑERA BLOQUEADA! IR A TAB 03 PARA DESBLOQUEAR >>"
	btn_goto_reboot.custom_minimum_size = Vector2(0, 38)
	btn_goto_reboot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_goto_reboot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_goto_reboot, Color("#f600ff"), true)
	btn_goto_reboot.visible = false
	btn_goto_reboot.pressed.connect(func(): tab_container.current_tab = 2)
	vbox.add_child(btn_goto_reboot)

	return wrapper

func _on_knob_canvas_gui_input(ev: InputEvent, knob_idx: int) -> void:
	if not game_active or knob_idx < 0 or knob_idx >= knob_canvases.size():
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				dragging_knob_index = knob_idx
				_update_knob_from_mouse_pos(knob_idx, ev.position)
			else:
				dragging_knob_index = -1
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			_rotate_knob(knob_idx, -1)
	elif ev is InputEventMouseMotion and dragging_knob_index == knob_idx:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_knob_from_mouse_pos(knob_idx, ev.position)
		else:
			dragging_knob_index = -1

func _update_knob_from_mouse_pos(knob_idx: int, local_mouse_pos: Vector2) -> void:
	var c: Control = knob_canvases[knob_idx]
	var center: Vector2 = c.size * 0.5
	var vec: Vector2 = local_mouse_pos - center
	if vec.length() < 4.0:
		return
	var ang: float = atan2(vec.y, vec.x)
	var rel_ang: float = fposmod(ang - (-PI * 0.75) + (TAU / float(KNOB_MAX_STEPS * 2)), TAU)
	var new_step: int = clampi(int(floor((rel_ang / TAU) * float(KNOB_MAX_STEPS))), 0, KNOB_MAX_STEPS - 1)
	if knob_Current_values[knob_idx] != new_step:
		knob_Current_values[knob_idx] = new_step
		_refresh_knobs_ui()
		_check_if_all_knobs_aligned()

func _sync_knobs_aligned() -> void:
	for i in range(KNOB_COUNT):
		var v = randi() % KNOB_MAX_STEPS
		knob_Target_values[i] = v
		knob_Current_values[i] = v
	light_hacked_by_monster = false
	_refresh_knobs_ui()
	_refresh_lure_tab_ui()

func _trigger_monster_light_knob_hack() -> void:
	light_hacked_by_monster = true
	for i in range(KNOB_COUNT):
		var target_v = randi() % KNOB_MAX_STEPS
		var cur_v = (target_v + randi_range(1, KNOB_MAX_STEPS - 1)) % KNOB_MAX_STEPS
		knob_Target_values[i] = target_v
		knob_Current_values[i] = cur_v
	_refresh_knobs_ui()
	_refresh_lure_tab_ui()

func _rotate_knob(knob_idx: int, step_dir: int) -> void:
	if not game_active or knob_idx < 0 or knob_idx >= KNOB_COUNT:
		return
	knob_Current_values[knob_idx] = posmod(knob_Current_values[knob_idx] + step_dir, KNOB_MAX_STEPS)
	_refresh_knobs_ui()
	_check_if_all_knobs_aligned()

func _check_if_all_knobs_aligned() -> void:
	var all_aligned = true
	for i in range(KNOB_COUNT):
		if knob_Current_values[i] != knob_Target_values[i]:
			all_aligned = false
			break

	if all_aligned and light_hacked_by_monster:
		light_hacked_by_monster = false
		_log_chat("SISTEMA", "🎛️ ¡Perillas alineadas! Circuito de Luz del Pasillo restaurado y listo para usar.", "#00ff9d")
		_refresh_lure_tab_ui()
		_update_3d_previz(0.0)

func _refresh_knobs_ui() -> void:
	for i in range(KNOB_COUNT):
		if i < knob_val_labels.size() and is_instance_valid(knob_val_labels[i]):
			var matched = (knob_Current_values[i] == knob_Target_values[i])
			knob_val_labels[i].text = ("✓ POS %d == %d" % [knob_Current_values[i], knob_Target_values[i]]) if matched else ("POS: %d  |  META: %d" % [knob_Current_values[i], knob_Target_values[i]])
			knob_val_labels[i].modulate = Color("#00ff9d") if matched else Color("#ffcc00")
		if i < knob_canvases.size() and is_instance_valid(knob_canvases[i]):
			knob_canvases[i].queue_redraw()

func _draw_single_knob(knob_idx: int) -> void:
	if knob_idx < 0 or knob_idx >= knob_canvases.size():
		return
	var c: Control = knob_canvases[knob_idx]
	var s = c.size
	if s.x < 20 or s.y < 20:
		return
	var center = s * 0.5
	var radius = min(s.x, s.y) * 0.38
	var cur_val = knob_Current_values[knob_idx]
	var tgt_val = knob_Target_values[knob_idx]
	var matched = (cur_val == tgt_val)
	var is_dragging = (dragging_knob_index == knob_idx)

	var base_col = Color("#00ff9d") if matched else (Color("#00f0ff") if is_dragging else Color("#ffaa00"))
	c.draw_circle(center, radius, Color(0.05, 0.09, 0.14, 0.95))
	c.draw_arc(center, radius, 0, TAU, 28, base_col, 3.0 if is_dragging else 2.2)

	for step_i in range(KNOB_MAX_STEPS):
		var a = -PI * 0.75 + (float(step_i) / float(KNOB_MAX_STEPS)) * TAU
		var p_in = center + Vector2(cos(a), sin(a)) * (radius * 0.78)
		var p_out = center + Vector2(cos(a), sin(a)) * (radius * 1.15)
		var tick_col = Color("#00ff9d") if step_i == tgt_val else Color("#335577")
		var tick_w = 3.4 if step_i == tgt_val else 1.4
		c.draw_line(p_in, p_out, tick_col, tick_w)

	var cur_ang = -PI * 0.75 + (float(cur_val) / float(KNOB_MAX_STEPS)) * TAU
	var needle_end = center + Vector2(cos(cur_ang), sin(cur_ang)) * (radius * 0.74)
	c.draw_line(center, needle_end, Color.WHITE if (matched or is_dragging) else Color("#00f0ff"), 3.2)
	c.draw_circle(needle_end, 3.2, base_col)
	c.draw_circle(center, 4.5, base_col)

func _on_hallway_light_pressed() -> void:
	if not game_active:
		return
	if light_hacked_by_monster:
		_log_chat("SISTEMA", "⚠️ ¡El monstruo hackeó la Luz del Pasillo! Mantené click y girá las 4 perillas de arriba hacia sus marcas verdes META.", "#ff1744")
		return
	if power_energy < 8.0:
		_log_chat("SISTEMA", "⚠️ ¡Energía insuficiente (<8%) para encender los reflectores del pasillo!", "#ff1744")
		return
	if not monster_attack_active:
		_log_chat("SISTEMA", "🔦 Encendiste la luz en [CAM C%s], pero el monstruo está oculto y todavía no reapareció." % selected_cam_id, "#88ccee")
		return

	power_energy = max(0.0, power_energy - 8.0)
	var actual_node = _get_monster_node_id()

	if selected_cam_id == actual_node:
		flash_stun_grace = 1.2
		monster_last_node_id = actual_node

		var stage_branches = _branches_for_level(monster_security_level)
		var move_desc = ""
		if monster_security_level > 1 and (randf() < 0.60 or stage_branches.size() <= 1):
			monster_security_level -= 1
			monster_branch = _random_branch_for_level(monster_security_level)
			move_desc = "retrocedió un nivel hacia las sombras"
		elif stage_branches.size() > 1:
			var alt_branches: Array[String] = []
			for b in stage_branches:
				if b != monster_branch:
					alt_branches.append(b)
			if not alt_branches.is_empty():
				monster_branch = alt_branches[randi() % alt_branches.size()]
			move_desc = "huyó hacia un pasillo lateral"
		else:
			move_desc = "se desvaneció en la oscuridad del pasillo"

		monster_attack_active = false
		monster_is_moving = false
		monster_spotted_on_cam = false
		monster_hack_progress = 0.0
		door_hold_timer = 0.0
		door_hold_target_time = -1.0
		monster_cooldown_timer = randf_range(4.0, 16.5)

		_log_chat("LUZ_PASILLO", "🔦 ¡IMPACTO LUMÍNICO EN [C%s]! Subject-Zero %s, DESAPARECIÓ de las cámaras y tardará un tiempo impredecible en volver a aparecer!" % [actual_node, move_desc], "#00ff9d")
	else:
		_log_chat("LUZ_PASILLO", "⚠️ Encendiste la luz en [CAM C%s] (-8%% Energía), pero el monstruo no estaba en ese pasillo." % selected_cam_id, "#ffaa00")

	_update_energy_and_temp_hud()
	_refresh_lure_tab_ui()
	_update_terminal_lock_state()
	_update_hud()
	_update_3d_previz(0.0)

func _count_active_errors() -> int:
	var c: int = 0
	if light_hacked_by_monster:
		c += 1
	if not companion_pc_unlocked:
		c += 1
	return c

func _on_hack_alert_goto_pressed() -> void:
	if not is_instance_valid(tab_container):
		return
	if light_hacked_by_monster:
		tab_container.current_tab = 1
	elif not companion_pc_unlocked:
		tab_container.current_tab = 2

func _update_hack_alert_visual_pulse() -> void:
	if not is_instance_valid(hack_alert_banner) or not hack_alert_banner.visible:
		return
	var blink = 0.5 + 0.5 * sin(pulse_phase * 2.4)
	hack_alert_style.border_color = Color("#ff1744").lerp(Color("#ffcc00"), blink)
	hack_alert_style.bg_color = Color(0.22 + 0.14 * blink, 0.02, 0.06, 0.95)

func _refresh_lure_tab_ui() -> void:
	if is_instance_valid(lbl_sys_audio_badge):
		_update_badge_style(lbl_sys_audio_badge, "🌀 VENTILACIÓN", Color("#05080d"), Color("#00ff9d"))
	if is_instance_valid(lbl_sys_video_badge):
		_update_badge_style(lbl_sys_video_badge, "🎛️ LUZ: ¡HACKEADA!" if light_hacked_by_monster else "🔦 LUZ: LISTA", Color("#05080d"), Color("#ff1744") if light_hacked_by_monster else Color("#00ff9d"))
	if is_instance_valid(lbl_sys_door_badge):
		_update_badge_style(lbl_sys_door_badge, "💻 PC COMPAÑERA: ACTIVA" if companion_pc_unlocked else "🔒 PC COMPAÑERA: ¡HACKEADA!", Color("#05080d"), Color("#00ff9d") if companion_pc_unlocked else Color("#ff1744"))

	if is_instance_valid(tab_container) and tab_container.get_tab_count() >= 3:
		tab_container.set_tab_title(0, "🌀 01_TURBINA")
		tab_container.set_tab_title(1, "🚨 02_LUZ Y PERILLAS (!)" if light_hacked_by_monster else "🎛️ 02_LUZ Y PERILLAS")
		tab_container.set_tab_title(2, "🚨 03_PC COMPAÑERA (!)" if not companion_pc_unlocked else "💻 03_PC COMPAÑERA")

	if is_instance_valid(hack_alert_banner):
		var hacked_parts: Array[String] = []
		if light_hacked_by_monster:
			hacked_parts.append("🎛️ LUZ/PERILLAS [TAB 02]")
		if not companion_pc_unlocked:
			hacked_parts.append("💻 PC COMPAÑERA [TAB 03]")

		if hacked_parts.is_empty():
			hack_alert_banner.visible = false
		else:
			hack_alert_banner.visible = true
			lbl_hack_alert_banner.text = "🚨 ¡SISTEMA HACKEADO!: " + "  +  ".join(hacked_parts)
			if light_hacked_by_monster:
				btn_hack_alert_goto.text = "🎛️ ACOMODAR PERILLAS [TAB 02] >>"
			else:
				btn_hack_alert_goto.text = "💻 DESBLOQUEAR PC [TAB 03] >>"

	if is_instance_valid(lbl_lure_selected_cam):
		lbl_lure_selected_cam.text = "🎥 PASILLO APUNTADO: [ CAM C%s ]  |  ENERGÍA: %d%%" % [selected_cam_id, int(power_energy)]
		lbl_lure_selected_cam.modulate = Color("#ffcc00")

	if is_instance_valid(btn_hallway_light):
		if light_hacked_by_monster:
			btn_hallway_light.text = "🔒 LUZ HACKEADA — MANTENÉ CLICK Y GIRÁ LAS 4 PERILLAS ARRIBA"
			_apply_styled_button(btn_hallway_light, Color("#ff1744"), true)
		else:
			btn_hallway_light.text = "🔦 PRENDER LUZ DEL PASILLO EN CAM C%s (-8%% ENERGÍA // EL MONSTRUO DESAPARECE)" % selected_cam_id
			_apply_styled_button(btn_hallway_light, Color("#00ff9d"), monster_attack_active)

	if is_instance_valid(btn_goto_reboot):
		btn_goto_reboot.visible = not companion_pc_unlocked
		btn_goto_reboot.text = "💻 ¡PC DE %s BLOQUEADA! CLIC PARA DESBLOQUEAR EN TAB 03 >>" % (current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA")

	if is_instance_valid(lbl_code_progress_status):
		var locked_cnt = _count_locked_doors()
		lbl_code_progress_status.text = "PUERTAS CERRADAS: %d (-%0.1f%%⚡/s)" % [locked_cnt, float(locked_cnt) * 1.45]
		lbl_code_progress_status.modulate = Color("#ffaa00") if locked_cnt > 0 else Color("#00ff9d")

# =========================================================
# 4C. TAB 03: DESBLOQUEAR PC DE TU COMPAÑERA (MATRIZ HEX)
# =========================================================
func _build_hacking_minigame_tab() -> Control:
	var wrapper = _create_doc_tab_wrapper()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	wrapper.add_child(vbox)

	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)

	lbl_breach_status = Label.new()
	lbl_breach_status.text = "💻 DESBLOQUEAR COMPUTADORA DE TU COMPAÑERA"
	lbl_breach_status.modulate = Color("#00f0ff")
	lbl_breach_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_breach_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_bar.add_child(lbl_breach_status)

	btn_reset_matrix = Button.new()
	btn_reset_matrix.text = "↻ NUEVA CLAVE"
	_apply_styled_button(btn_reset_matrix, Color("#00f0ff"), false)
	btn_reset_matrix.pressed.connect(_on_manual_reset_matrix)
	top_bar.add_child(btn_reset_matrix)

	lbl_breach_hint = Label.new()
	lbl_breach_hint.text = "Completá la secuencia Hex (FILA → COLUMNA) para DESBLOQUEAR LA COMPUTADORA de tu compañera: una vez desbloqueada, ella reducirá automáticamente el hackeo del monstruo y limpiará el sabotaje térmico!"
	lbl_breach_hint.modulate = Color("#88aacc")
	lbl_breach_hint.add_theme_font_size_override("font_size", 12)
	lbl_breach_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_breach_hint)

	var seq_panel = _create_cyber_panel(Color("#070c14"), Color("#1e3448"), 1, 8)
	vbox.add_child(seq_panel)
	var seq_hbox = HBoxContainer.new()
	seq_hbox.add_theme_constant_override("separation", 20)
	seq_panel.add_child(seq_hbox)

	lbl_target_seq = RichTextLabel.new()
	lbl_target_seq.bbcode_enabled = true
	lbl_target_seq.fit_content = true
	lbl_target_seq.scroll_active = false
	lbl_target_seq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seq_hbox.add_child(lbl_target_seq)

	lbl_buffer_seq = RichTextLabel.new()
	lbl_buffer_seq.bbcode_enabled = true
	lbl_buffer_seq.fit_content = true
	lbl_buffer_seq.scroll_active = false
	lbl_buffer_seq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seq_hbox.add_child(lbl_buffer_seq)

	var center_box = CenterContainer.new()
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center_box)

	grid_matrix = GridContainer.new()
	grid_matrix.columns = 5
	grid_matrix.add_theme_constant_override("h_separation", 8)
	grid_matrix.add_theme_constant_override("v_separation", 8)
	center_box.add_child(grid_matrix)

	matrix_buttons.clear()
	for r in range(5):
		var row_btns: Array = []
		for c in range(5):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(68, 44)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.pressed.connect(_on_matrix_cell_pressed.bind(r, c))
			grid_matrix.add_child(btn)
			row_btns.append(btn)
		matrix_buttons.append(row_btns)

	return wrapper

func _is_matrix_interactive() -> bool:
	return game_active and (not companion_pc_unlocked or temp_hacked_by_monster or monster_attack_active)

func _generate_breach_matrix() -> void:
	matrix_grid.clear()
	used_cells.clear()
	entered_sequence.clear()
	target_sequence.clear()
	selecting_row = true
	active_index = 0

	for r in range(5):
		var row_vals: Array = []
		for c in range(5):
			row_vals.append(hex_pool[randi() % hex_pool.size()])
		matrix_grid.append(row_vals)

	var seq_len = clamp(current_mission.breach_difficulty if is_instance_valid(current_mission) else 3, 3, 5)
	var sim_row = 0
	var sim_col = 0
	var sim_sel_row = true
	var sim_used: Dictionary = {}

	for _step in range(seq_len):
		if sim_sel_row:
			var candidates: Array[int] = []
			for c in range(5):
				if not sim_used.has(Vector2i(sim_row, c)):
					candidates.append(c)
			sim_col = candidates[randi() % candidates.size()]
		else:
			var candidates: Array[int] = []
			for r in range(5):
				if not sim_used.has(Vector2i(r, sim_col)):
					candidates.append(r)
			sim_row = candidates[randi() % candidates.size()]

		sim_used[Vector2i(sim_row, sim_col)] = true
		var token = hex_pool[randi() % hex_pool.size()]
		matrix_grid[sim_row][sim_col] = token
		target_sequence.append(token)
		sim_sel_row = not sim_sel_row

	_refresh_matrix_ui()

func _on_matrix_cell_pressed(r: int, c: int) -> void:
	if not _is_matrix_interactive():
		return
	var cell_key = Vector2i(r, c)
	if used_cells.has(cell_key):
		return
	if selecting_row and r != active_index:
		return
	if not selecting_row and c != active_index:
		return

	var picked_token: String = matrix_grid[r][c]
	var expected_token: String = target_sequence[entered_sequence.size()]

	if picked_token == expected_token:
		used_cells[cell_key] = true
		entered_sequence.append(picked_token)
		active_index = c if selecting_row else r
		selecting_row = not selecting_row

		if entered_sequence.size() >= target_sequence.size():
			companion_pc_unlocked = true
			temp_hacked_by_monster = false
			monster_hack_progress = max(0.0, monster_hack_progress - 28.0)
			bpm = max(70, bpm - 12)
			var comp_name = current_mission.agent_name if is_instance_valid(current_mission) else "Compañera"
			_log_chat(comp_name.to_upper(), "💻 «¡Gracias por desbloquear mi computadora! Estoy reduciendo el hackeo del monstruo (-28%% inmediato + reducción continua) y purgué el sabotaje térmico!»", "#00ff9d")
			_update_turbine_ui()
			_refresh_lure_tab_ui()
			_update_terminal_lock_state()
			_update_hud()
			_update_3d_previz(0.0)
		_refresh_matrix_ui()
		_update_companion_perk_ui()
	else:
		_log_chat("SISTEMA", "⚠️ Celda incorrecta! Secuencia de desbloqueo reiniciada.", "#ffcc00")
		_generate_breach_matrix()

func _on_manual_reset_matrix() -> void:
	if not _is_matrix_interactive():
		return
	_generate_breach_matrix()

func _refresh_matrix_ui() -> void:
	var is_mia = is_instance_valid(current_mission) and current_mission.companion_perk == "prediction"
	var can_interact = _is_matrix_interactive() and not (companion_pc_unlocked and not temp_hacked_by_monster and entered_sequence.size() >= target_sequence.size())
	if is_instance_valid(btn_reset_matrix):
		btn_reset_matrix.disabled = not can_interact

	var comp_name = current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA"
	var header_label = "CÓDIGO DE DESBLOQUEO PC (%s):" % comp_name
	var target_str = "[b][color=#88aacc]%s[/color][/b]\n" % header_label
	if companion_pc_unlocked and not temp_hacked_by_monster and entered_sequence.size() >= target_sequence.size():
		target_str += "[color=#00ff9d][ PC DESBLOQUEADA — REDUCIENDO HACKEO ][/color]"
	else:
		for i in range(target_sequence.size()):
			if i < entered_sequence.size():
				target_str += "[b][color=#00ff9d][ %s ][/color][/b] " % target_sequence[i]
			elif i == entered_sequence.size() and can_interact:
				target_str += "[b][color=#f600ff][ 🔮%s ][/color][/b] " % target_sequence[i] if is_mia else "[b][color=#00f0ff][ %s ][/color][/b] " % target_sequence[i]
			else:
				target_str += "[color=#667788][ %s ][/color] " % target_sequence[i]
	lbl_target_seq.text = target_str

	var buf_str = "[b][color=#88aacc]ESTADO TERMINAL COMPAÑERA:[/color][/b]\n"
	if companion_pc_unlocked and not temp_hacked_by_monster and entered_sequence.size() >= target_sequence.size():
		buf_str += "[b][color=#00ff9d]✓ %s ESTÁ TRABAJANDO EN ELLO (REDUCIENDO HACKEO)[/color][/b]" % comp_name
		lbl_breach_status.text = "✓ PC DE %s ACTIVA // REDUCIENDO HACKEO" % comp_name
		lbl_breach_status.modulate = Color("#00ff9d")
	else:
		for t in entered_sequence:
			buf_str += "[b][color=#00ff9d]%s[/color][/b]  " % t
		for _i in range(target_sequence.size() - entered_sequence.size()):
			buf_str += "[color=#445566]__[/color]  "
		var mode_txt = ("FILA %d" % (active_index + 1)) if selecting_row else ("COLUMNA %d" % (active_index + 1))
		lbl_breach_status.text = "🔒 PC BLOQUEADA — ELEGÍ EN %s // PASO %d/%d" % [
			mode_txt,
			entered_sequence.size() + 1,
			target_sequence.size()
		]
		lbl_breach_status.modulate = Color("#ff1744") if not companion_pc_unlocked else Color("#00f0ff")
	lbl_buffer_seq.text = buf_str

	var next_expected = target_sequence[entered_sequence.size()] if entered_sequence.size() < target_sequence.size() else ""
	for r in range(5):
		for c in range(5):
			var btn: Button = matrix_buttons[r][c]
			var cell_key = Vector2i(r, c)
			var is_used = used_cells.has(cell_key)
			var is_selectable = can_interact and (not is_used) and ((selecting_row and r == active_index) or (not selecting_row and c == active_index))

			var cell_txt = String(matrix_grid[r][c])
			var is_predicted_match = is_selectable and (cell_txt == next_expected)
			if not can_interact or is_used:
				btn.text = "✓"
			elif is_mia and is_predicted_match:
				btn.text = "🔮" + cell_txt
			else:
				btn.text = cell_txt
			btn.disabled = not is_selectable

			if is_used or not can_interact:
				_style_matrix_cell(btn, Color("#0a291e"), Color("#00ff9d"), Color("#00ff9d"))
			elif is_selectable:
				if is_mia and is_predicted_match:
					_style_matrix_cell(btn, Color("#2e1038"), Color("#f600ff"), Color("#ffffff"))
				elif is_predicted_match:
					_style_matrix_cell(btn, Color("#112638"), Color("#00ff9d"), Color("#ffffff"))
				else:
					_style_matrix_cell(btn, Color("#112638"), Color("#00f0ff"), Color("#ffffff"))
			else:
				_style_matrix_cell(btn, Color("#080d14"), Color("#182432"), Color("#445566"))

	_refresh_lure_tab_ui()

func _get_monster_node_id() -> String:
	return _node_id_for(monster_security_level, monster_branch)

func _node_id_for(level: int, branch: String) -> String:
	if level <= 1:
		if branch == "A":
			return "1A" # Arriba
		elif branch == "B":
			return "1"  # Medio
		else:
			return "1B" # Abajo
	elif level == 2 or level == 3:
		return str(level) + ("B" if branch == "B" else "A")
	return "4"

func _branches_for_level(level: int) -> Array[String]:
	if level <= 1:
		return ["A", "B", "C"]
	elif level == 2 or level == 3:
		return ["A", "B"]
	return ["A"]

func _random_branch_for_level(level: int) -> String:
	var opts = _branches_for_level(level)
	return opts[randi() % opts.size()]

func _is_branching_level(level: int) -> bool:
	return _branches_for_level(level).size() > 1

func _stage_doors_text(level: int) -> String:
	var parts: Array[String] = []
	for b in _branches_for_level(level):
		parts.append("C" + _node_id_for(level, b))
	return " / ".join(parts)

func _select_camera(cam_id: String) -> void:
	if not CAM_NODE_IDS.has(cam_id):
		cam_id = "1"
	selected_cam_id = cam_id

	if monster_attack_active and selected_cam_id == _get_monster_node_id():
		monster_spotted_on_cam = true

	for id_key in cam_select_buttons.keys():
		var btn: Button = cam_select_buttons[id_key]
		if is_instance_valid(btn):
			var is_sel = (id_key == selected_cam_id)
			var d_state = door_node_states.get(id_key, "OPEN")
			var col = Color("#5a6266")
			if is_sel:
				col = Color("#d9382e")
			elif d_state == "LOCKED":
				col = Color("#2bbd7e")
			elif d_state == "BREACHED":
				col = Color("#ff1744")
			_apply_styled_button(btn, col, is_sel)

	_refresh_lure_tab_ui()
	if is_instance_valid(tactical_map):
		tactical_map.queue_redraw()
	_update_terminal_lock_state()
	_update_3d_previz(0.0)

func _on_tactical_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos: Vector2 = event.position
		for cam_id in map_node_positions.keys():
			var node_pos: Vector2 = map_node_positions[cam_id]
			if click_pos.distance_to(node_pos) <= 28.0:
				_select_camera(cam_id)
				break

func _build_3d_camera_previz() -> Control:
	var frame = _create_cyber_panel(Color("#040810"), Color("#00f0ff"), 2, 3)
	frame.custom_minimum_size = Vector2(215, 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 0.95

	var layer = Control.new()
	layer.clip_contents = true
	layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(layer)

	var svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(svc)

	previz_viewport = SubViewport.new()
	previz_viewport.own_world_3d = true
	previz_viewport.size = Vector2i(320, 220)
	previz_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(previz_viewport)

	var root_3d = Node3D.new()
	previz_viewport.add_child(root_3d)

	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#010408")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#08121a")
	env.ambient_light_energy = 0.55
	env_node.environment = env
	root_3d.add_child(env_node)

	previz_cam_3d = Camera3D.new()
	previz_cam_3d.position = Vector3(0.0, 1.4, 3.2)
	previz_cam_3d.rotation_degrees = Vector3(-9.0, 0.0, 0.0)
	previz_cam_3d.fov = 74.0
	root_3d.add_child(previz_cam_3d)

	previz_room_light = OmniLight3D.new()
	previz_room_light.position = Vector3(0.0, 2.4, -0.8)
	previz_room_light.light_color = Color("#3cd070")
	previz_room_light.light_energy = 1.1
	previz_room_light.omni_range = 10.0
	root_3d.add_child(previz_room_light)

	var corridor = Node3D.new()
	root_3d.add_child(corridor)

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color("#0a1118")
	wall_mat.roughness = 0.95

	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#05080c")
	floor_mat.roughness = 0.35
	floor_mat.metallic = 0.1

	var door_edge_mat = StandardMaterial3D.new()
	door_edge_mat.albedo_color = Color("#111a24")
	door_edge_mat.roughness = 0.8

	var pipe_mat = StandardMaterial3D.new()
	pipe_mat.albedo_color = Color("#0c1218")
	pipe_mat.roughness = 0.4
	pipe_mat.metallic = 0.6

	var floor_mi = MeshInstance3D.new()
	var floor_box = BoxMesh.new()
	floor_box.size = Vector3(2.8, 0.1, 13.0)
	floor_mi.mesh = floor_box
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(0.0, 0.0, -3.0)
	corridor.add_child(floor_mi)

	var ceil_mi = MeshInstance3D.new()
	var ceil_box = BoxMesh.new()
	ceil_box.size = Vector3(2.8, 0.1, 13.0)
	ceil_mi.mesh = ceil_box
	ceil_mi.material_override = wall_mat
	ceil_mi.position = Vector3(0.0, 2.6, -3.0)
	corridor.add_child(ceil_mi)

	var side_box = BoxMesh.new()
	side_box.size = Vector3(0.1, 2.6, 13.0)
	for side_x in [-1.4, 1.4]:
		var w_mi = MeshInstance3D.new()
		w_mi.mesh = side_box
		w_mi.material_override = wall_mat
		w_mi.position = Vector3(side_x, 1.3, -3.0)
		corridor.add_child(w_mi)

	var pipe_box = CylinderMesh.new()
	pipe_box.top_radius = 0.06
	pipe_box.bottom_radius = 0.06
	pipe_box.height = 13.0
	for px in [-0.8, -0.7, 0.7]:
		var p_mi = MeshInstance3D.new()
		p_mi.mesh = pipe_box
		p_mi.material_override = pipe_mat
		p_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		p_mi.position = Vector3(px, 2.45, -3.0)
		corridor.add_child(p_mi)

	var door_panel_box = BoxMesh.new()
	door_panel_box.size = Vector3(0.12, 1.9, 1.1)
	for z_pos in [-1.5, -4.5]:
		for px in [-1.34, 1.34]:
			var d_edge = MeshInstance3D.new()
			d_edge.mesh = door_panel_box
			d_edge.material_override = door_edge_mat
			d_edge.position = Vector3(px, 0.95, z_pos)
			corridor.add_child(d_edge)

	var back_mi = MeshInstance3D.new()
	var back_box = BoxMesh.new()
	back_box.size = Vector3(2.8, 2.6, 0.1)
	back_mi.mesh = back_box
	back_mi.material_override = wall_mat
	back_mi.position = Vector3(0.0, 1.3, -9.5)
	corridor.add_child(back_mi)

	previz_door_mesh = MeshInstance3D.new()
	var door_box = BoxMesh.new()
	door_box.size = Vector3(2.6, 2.5, 0.15)
	previz_door_mesh.mesh = door_box
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color("#0b221a")
	door_mat.roughness = 0.8
	previz_door_mesh.material_override = door_mat
	previz_door_mesh.position = Vector3(0.0, 3.85, 0.5)
	corridor.add_child(previz_door_mesh)

	# --- EL MONSTRUO LIMINAL ---
	previz_monster_root = Node3D.new()
	previz_monster_root.position = Vector3(0.0, 0.0, -4.5)
	root_3d.add_child(previz_monster_root)

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color("#020202")
	body_mat.roughness = 1.0

	var face_mat = StandardMaterial3D.new()
	face_mat.albedo_color = Color("#2a2b2f")
	face_mat.roughness = 0.9

	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color("#ffffff")
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var pupil_mat = StandardMaterial3D.new()
	pupil_mat.albedo_color = Color("#000000")

	var mouth_mat = StandardMaterial3D.new()
	mouth_mat.albedo_color = Color("#111111")
	mouth_mat.roughness = 0.9

	var torso_mi = MeshInstance3D.new()
	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.28
	torso_mesh.height = 1.4
	torso_mi.mesh = torso_mesh
	torso_mi.material_override = body_mat
	torso_mi.position = Vector3(0.0, 1.15, 0.0)
	previz_monster_root.add_child(torso_mi)

	previz_monster_head = Node3D.new()
	previz_monster_head.position = Vector3(0.0, 1.85, 0.08)
	previz_monster_root.add_child(previz_monster_head)

	var head_mi = MeshInstance3D.new()
	var head_sphere = SphereMesh.new()
	head_sphere.radius = 0.24
	head_sphere.height = 0.54
	head_mi.mesh = head_sphere
	head_mi.material_override = face_mat
	previz_monster_head.add_child(head_mi)

	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.065
	eye_mesh.height = 0.08
	var pupil_mesh = SphereMesh.new()
	pupil_mesh.radius = 0.02
	pupil_mesh.height = 0.02
	for ex in [-0.08, 0.08]:
		var eye_mi = MeshInstance3D.new()
		eye_mi.mesh = eye_mesh
		eye_mi.material_override = eye_mat
		eye_mi.position = Vector3(ex, 0.08, 0.17)
		previz_monster_head.add_child(eye_mi)

		var pupil_mi = MeshInstance3D.new()
		pupil_mi.mesh = pupil_mesh
		pupil_mi.material_override = pupil_mat
		pupil_mi.position = Vector3(ex, 0.08, 0.21)
		previz_monster_head.add_child(pupil_mi)

	var mouth_mi = MeshInstance3D.new()
	var mouth_mesh = SphereMesh.new()
	mouth_mesh.radius = 0.09
	mouth_mesh.height = 0.12
	mouth_mi.mesh = mouth_mesh
	mouth_mi.material_override = mouth_mat
	mouth_mi.position = Vector3(0.0, -0.09, 0.15)
	previz_monster_head.add_child(mouth_mi)

	var tooth_box = BoxMesh.new()
	tooth_box.size = Vector3(0.015, 0.025, 0.01)
	for i in range(5):
		var dx = (i - 2) * 0.022
		var t_up = MeshInstance3D.new()
		t_up.mesh = tooth_box
		t_up.material_override = eye_mat
		t_up.position = Vector3(dx, -0.065, 0.2)
		previz_monster_head.add_child(t_up)

		var t_down = MeshInstance3D.new()
		t_down.mesh = tooth_box
		t_down.material_override = eye_mat
		t_down.position = Vector3(dx, -0.115, 0.2)
		previz_monster_head.add_child(t_down)

	var eye_glow = OmniLight3D.new()
	eye_glow.light_color = Color("#ffffff")
	eye_glow.light_energy = 0.45
	eye_glow.omni_range = 1.1
	eye_glow.position = Vector3(0.0, 0.05, 0.25)
	previz_monster_head.add_child(eye_glow)

	var arm_mesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 1.35, 0.08)

	previz_monster_arm_l = Node3D.new()
	previz_monster_arm_l.position = Vector3(-0.35, 1.45, 0.0)
	previz_monster_arm_l.rotation_degrees = Vector3(0.0, 0.0, -28.0)
	previz_monster_root.add_child(previz_monster_arm_l)
	var arm_l_mi = MeshInstance3D.new()
	arm_l_mi.mesh = arm_mesh
	arm_l_mi.material_override = body_mat
	arm_l_mi.position = Vector3(0.0, -0.6, 0.05)
	previz_monster_arm_l.add_child(arm_l_mi)

	previz_monster_arm_r = Node3D.new()
	previz_monster_arm_r.position = Vector3(0.35, 1.45, 0.0)
	previz_monster_arm_r.rotation_degrees = Vector3(0.0, 0.0, 28.0)
	previz_monster_root.add_child(previz_monster_arm_r)
	var arm_r_mi = MeshInstance3D.new()
	arm_r_mi.mesh = arm_mesh
	arm_r_mi.material_override = body_mat
	arm_r_mi.position = Vector3(0.0, -0.6, 0.05)
	previz_monster_arm_r.add_child(arm_r_mi)

	var leg_mesh = BoxMesh.new()
	leg_mesh.size = Vector3(0.09, 0.75, 0.09)

	previz_monster_leg_l = Node3D.new()
	previz_monster_leg_l.position = Vector3(-0.14, 0.55, 0.0)
	previz_monster_root.add_child(previz_monster_leg_l)
	var leg_l_mi = MeshInstance3D.new()
	leg_l_mi.mesh = leg_mesh
	leg_l_mi.material_override = body_mat
	leg_l_mi.position = Vector3(0.0, -0.32, 0.0)
	previz_monster_leg_l.add_child(leg_l_mi)

	previz_monster_leg_r = Node3D.new()
	previz_monster_leg_r.position = Vector3(0.14, 0.55, 0.0)
	previz_monster_root.add_child(previz_monster_leg_r)
	var leg_r_mi = MeshInstance3D.new()
	leg_r_mi.mesh = leg_mesh
	leg_r_mi.material_override = body_mat
	leg_r_mi.position = Vector3(0.0, -0.32, 0.0)
	previz_monster_leg_r.add_child(leg_r_mi)

	var cam_crt = _create_portrait_crt_overlay(Color(0.02, 0.95, 0.75, 1.0))
	layer.add_child(cam_crt)

	var cam_top_bar = PanelContainer.new()
	cam_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cam_top_bar.offset_bottom = 24
	var ct_st = StyleBoxFlat.new()
	ct_st.bg_color = Color(0.01, 0.03, 0.06, 0.85)
	ct_st.set_content_margin_all(3)
	cam_top_bar.add_theme_stylebox_override("panel", ct_st)
	layer.add_child(cam_top_bar)

	lbl_previz_cam_title = Label.new()
	lbl_previz_cam_title.text = "🎥 CAM 1 - PASILLO"
	lbl_previz_cam_title.add_theme_font_size_override("font_size", 10)
	lbl_previz_cam_title.modulate = Color("#00f0ff")
	lbl_previz_cam_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cam_top_bar.add_child(lbl_previz_cam_title)

	var cam_bot_bar = PanelContainer.new()
	cam_bot_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cam_bot_bar.offset_top = -24
	cam_bot_bar.add_theme_stylebox_override("panel", ct_st)
	layer.add_child(cam_bot_bar)

	lbl_previz_cam_alert = Label.new()
	lbl_previz_cam_alert.text = "☣️ SUBJECT-ZERO DETECTED"
	lbl_previz_cam_alert.add_theme_font_size_override("font_size", 10)
	lbl_previz_cam_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_previz_cam_alert.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cam_bot_bar.add_child(lbl_previz_cam_alert)

	return frame

func _update_3d_previz(delta: float) -> void:
	if not is_instance_valid(previz_monster_root) or not is_instance_valid(previz_cam_3d):
		return

	var monster_node = _get_monster_node_id() if monster_attack_active else ""
	var monster_in_this_cam = monster_attack_active and (selected_cam_id == monster_node)
	previz_monster_root.visible = monster_in_this_cam
	if monster_in_this_cam:
		monster_spotted_on_cam = true

	previz_cam_3d.rotation_degrees.y = sin(pulse_phase * 0.22) * 3.2

	var d_state = door_node_states.get(selected_cam_id, "OPEN")
	if is_instance_valid(previz_door_mesh):
		var target_door_y = 1.28 if d_state == "LOCKED" else 3.85
		previz_door_mesh.position.y = lerpf(previz_door_mesh.position.y, target_door_y, clampf(delta * 8.0 if delta > 0.0 else 1.0, 0.1, 1.0))

	if monster_in_this_cam:
		if monster_attack_active and monster_is_moving and game_active:
			var walk_spd = 7.5 if music_box_charge < 40.0 else 4.6
			previz_walk_phase = fmod(previz_walk_phase + delta * walk_spd, TAU)
		var t = clampf(monster_hack_progress / 100.0, 0.0, 1.0) if monster_attack_active else 0.0
		var z_pos = lerpf(-6.8, 1.15, t)
		var x_sway = (sin(previz_walk_phase) * 0.18) if (monster_attack_active and monster_is_moving) else 0.0
		var y_bob = (abs(sin(previz_walk_phase * 2.0)) * 0.10) if (monster_attack_active and monster_is_moving) else 0.0
		previz_monster_root.position = Vector3(x_sway, y_bob, z_pos)
		previz_monster_root.rotation.z = (sin(previz_walk_phase) * 0.07) if (monster_attack_active and monster_is_moving) else 0.0

		if is_instance_valid(previz_monster_arm_l) and is_instance_valid(previz_monster_arm_r):
			var arm_swing = sin(previz_walk_phase) * 0.35 if (monster_attack_active and monster_is_moving) else 0.0
			previz_monster_arm_l.rotation.x = -0.35 + arm_swing
			previz_monster_arm_r.rotation.x = -0.35 - arm_swing
			previz_monster_arm_l.rotation.z = deg_to_rad(-26.0) - abs(arm_swing) * 0.2
			previz_monster_arm_r.rotation.z = deg_to_rad(26.0) + abs(arm_swing) * 0.2
		if is_instance_valid(previz_monster_leg_l) and is_instance_valid(previz_monster_leg_r):
			var leg_swing = sin(previz_walk_phase) * 0.45 if (monster_attack_active and monster_is_moving) else 0.0
			previz_monster_leg_l.rotation.x = -leg_swing
			previz_monster_leg_r.rotation.x = leg_swing
		if is_instance_valid(previz_monster_head):
			previz_monster_head.rotation.z = sin(pulse_phase * 1.3) * 0.14
			previz_monster_head.rotation.y = (sin(pulse_phase * 1.7) * 0.18) if (monster_attack_active and monster_is_moving) else 0.0

		if is_instance_valid(previz_room_light):
			previz_room_light.light_color = Color("#3cd070") if not monster_is_moving else Color("#2ea866")
			previz_room_light.light_energy = 1.15 + sin(pulse_phase * 4.0) * 0.25
	else:
		if is_instance_valid(previz_room_light):
			if flash_stun_grace > 0.0:
				previz_room_light.light_color = Color("#ffffff")
				previz_room_light.light_energy = 3.2
			else:
				previz_room_light.light_color = Color("#00ff9d") if d_state == "LOCKED" else Color("#3cd070")
				previz_room_light.light_energy = 1.05

	if is_instance_valid(lbl_previz_cam_title):
		lbl_previz_cam_title.text = "🎥 CAM C%s // PUERTA: %s" % [selected_cam_id, "CERRADA" if d_state == "LOCKED" else "ABIERTA"]
		lbl_previz_cam_title.modulate = Color("#00ff9d") if d_state == "LOCKED" else Color("#00f0ff")
	if is_instance_valid(lbl_previz_cam_alert):
		if not monster_attack_active:
			lbl_previz_cam_alert.text = "SIN RASTRO — LA ENTIDAD ESTÁ OCULTA"
			lbl_previz_cam_alert.modulate = Color("#557799")
		elif monster_in_this_cam:
			if d_state == "LOCKED":
				lbl_previz_cam_alert.text = "🚪 BLOQUEADO EN PUERTA C%s (%0.1fs)..." % [selected_cam_id, door_hold_timer]
				lbl_previz_cam_alert.modulate = Color("#00ff9d")
			else:
				lbl_previz_cam_alert.text = "☣️ ENTIDAD EN CAM C%s (%d%%)" % [selected_cam_id, int(monster_hack_progress)]
				lbl_previz_cam_alert.modulate = Color("#ff1744")
		else:
			lbl_previz_cam_alert.text = "PASILLO C%s DESPEJADO" % selected_cam_id
			lbl_previz_cam_alert.modulate = Color("#7799bb")

func _count_locked_doors() -> int:
	var cnt: int = 0
	for k in door_node_states.keys():
		if door_node_states[k] == "LOCKED":
			cnt += 1
	return cnt

func _force_open_all_doors_on_power_outage() -> void:
	for k in door_node_states.keys():
		if door_node_states[k] == "LOCKED":
			door_node_states[k] = "OPEN"
	door_hold_timer = 0.0
	door_hold_target_time = -1.0
	_log_chat("APAGÓN_ELÉCTRICO", "⚡ ¡ENERGÍA AL 0%! Todas las puertas magnéticas se abrieron por falta de corriente! Impulsá la Turbina [Tab 01] para recuperar energía!", "#ff1744")
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_refresh_lure_tab_ui()

func _on_open_all_doors_pressed() -> void:
	var opened_any = false
	for k in door_node_states.keys():
		if door_node_states[k] == "LOCKED":
			door_node_states[k] = "OPEN"
			opened_any = true
	door_hold_timer = 0.0
	door_hold_target_time = -1.0
	if opened_any:
		_log_chat("SISTEMA", "🔓 Abriste todas las puertas para ahorrar Energía eléctrica.", "#00ff9d")
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_refresh_lure_tab_ui()

func _update_terminal_lock_state() -> void:
	if not is_instance_valid(current_mission) or not is_instance_valid(btn_inject):
		return

	# Solo existe un botón: cierra o abre ÚNICAMENTE la cámara que el jugador tiene seleccionada
	var sel_closed: bool = (door_node_states.get(selected_cam_id, "OPEN") == "LOCKED")
	btn_inject.visible = true
	btn_inject.text = ("🔓 ABRIR CAM ACTUAL [C%s]" % selected_cam_id) if sel_closed else ("🚪 CERRAR CAM ACTUAL [C%s]" % selected_cam_id)
	_apply_styled_button(btn_inject, Color("#00ff9d") if sel_closed else Color("#00f0ff"), true)

	if is_instance_valid(btn_seal_door_b):
		btn_seal_door_b.visible = false
	if is_instance_valid(btn_seal_door_c):
		btn_seal_door_c.visible = false

	if power_energy <= 0.0:
		lbl_lock_banner.text = "🚨 ¡SIN ENERGÍA (0%)! No podés mantener puertas cerradas hasta recuperar la Turbina en [Tab 01]."
		lbl_lock_banner.modulate = Color("#ff1744")
	elif not monster_attack_active:
		lbl_lock_banner.text = "🔇 El monstruo desapareció y volverá en un momento impredecible. Abrí las puertas con [🔓 ABRIR TODAS] para ahorrar Energía."
		lbl_lock_banner.modulate = Color("#88ccee")
	else:
		var cur_monster_node: String = _get_monster_node_id()
		var is_monster_door_closed: bool = (door_node_states.get(cur_monster_node, "OPEN") == "LOCKED")
		if is_monster_door_closed:
			lbl_lock_banner.text = "🚪 ¡PUERTA [C%s] CERRADA CON ÉXITO! El monstruo está bloqueado (se irá en %0.1fs / %0.1fs)..." % [cur_monster_node, door_hold_timer, max(0.1, door_hold_target_time)]
			lbl_lock_banner.modulate = Color("#00ff9d")
		elif selected_cam_id == cur_monster_node:
			lbl_lock_banner.text = "🚨 ¡LO ENCONTRASTE EN [CAM C%s]! ¡Cerrale la puerta de esta cámara o prendé la Luz antes de que avance!" % selected_cam_id
			lbl_lock_banner.modulate = Color("#ff1744")
		else:
			lbl_lock_banner.text = "🚨 ATAQUE EN CURSO: Buscá al monstruo en las cámaras [%s], entrá a su cámara y cerrale la puerta!" % _stage_doors_text(monster_security_level)
			lbl_lock_banner.modulate = Color("#ffcc44")

func _update_companion_perk_ui() -> void:
	if not is_instance_valid(current_mission) or not is_instance_valid(lbl_perk_status) or not is_instance_valid(btn_companion_perk):
		return
	if current_mission.companion_perk == "prediction":
		if not monster_attack_active:
			lbl_perk_status.text = "🔮 MIA: EN ESPERA"
			lbl_perk_status.modulate = Color("#88aacc")
			btn_companion_perk.text = "🔮 ESPERANDO QUE REAPAREZCA PARA RASTREAR"
			btn_companion_perk.disabled = true
			_apply_styled_button(btn_companion_perk, Color("#667788"), false)
			return
		lbl_perk_status.text = "🔮 RASTREO: Cam [C%s]" % _get_monster_node_id()
		lbl_perk_status.modulate = Color("#f600ff")
		btn_companion_perk.text = "🔮 MIA: MARCAR CÁMARA + ALINEAR PERILLAS Y PC" if mia_prediction_ready else "🔮 RASTREO USADO EN ESTA OLEADA"
		btn_companion_perk.disabled = not mia_prediction_ready
		_apply_styled_button(btn_companion_perk, Color("#f600ff"), mia_prediction_ready)
	else:
		if naomi_shield_charges > 0:
			lbl_perk_status.text = "🛡️ NAOMI: ESCUDO LISTO"
			lbl_perk_status.modulate = Color("#00ff9d")
			btn_companion_perk.text = "🛡️ NAOMI: RECARGAR ENERGÍA + ENFRIAR TURBINA" if (monster_attack_active or _count_active_errors() > 0 or power_energy < 70.0) else "🛡️ ESCUDO AUXILIAR LISTO"
			btn_companion_perk.disabled = false
			_apply_styled_button(btn_companion_perk, Color("#00ff9d"), true)
		else:
			lbl_perk_status.text = "🛡️ NAOMI: ESCUDO USADO"
			lbl_perk_status.modulate = Color("#ffcc00")
			btn_companion_perk.text = "🛡️ ESCUDO CONSUMIDO"
			btn_companion_perk.disabled = true
			_apply_styled_button(btn_companion_perk, Color("#667788"), false)

func _on_companion_perk_pressed() -> void:
	if not game_active or not is_instance_valid(current_mission):
		return
	if current_mission.companion_perk == "prediction":
		if not monster_attack_active or not mia_prediction_ready:
			return
		mia_prediction_ready = false
		monster_spotted_on_cam = true
		_select_camera(_get_monster_node_id())
		_sync_knobs_aligned()
		music_box_charge = min(100.0, music_box_charge + 25.0)
		monster_hack_progress = max(0.0, monster_hack_progress - 22.0)
		if not companion_pc_unlocked and entered_sequence.size() < target_sequence.size():
			var expected_token: String = target_sequence[entered_sequence.size()]
			for idx in range(5):
				var rr = active_index if selecting_row else idx
				var cc = idx if selecting_row else active_index
				if not used_cells.has(Vector2i(rr, cc)) and matrix_grid[rr][cc] == expected_token:
					_on_matrix_cell_pressed(rr, cc)
					break
		_log_chat("MIA_PERK", "🔮 [MIA]: «¡Subject-Zero está en [C%s]! Alineé las perillas de luz por vos y avancé el desbloqueo!»" % _get_monster_node_id(), "#f600ff")
		_update_companion_perk_ui()
	else:
		if naomi_shield_charges <= 0:
			return
		temp_hacked_by_monster = false
		_sync_knobs_aligned()
		companion_pc_unlocked = true
		power_energy = min(100.0, power_energy + 35.0)
		bunker_temperature = max(NORMAL_TEMP, bunker_temperature - 25.0)
		music_box_charge = min(100.0, music_box_charge + 35.0)
		monster_hack_progress = max(0.0, monster_hack_progress - 30.0)
		bpm = max(75, bpm - 12)
		_log_chat("NAOMI_PERK", "🛡️ [NAOMI]: «¡Inyecté +35% de Energía, enfrié la Turbina, alineé las perillas y desbloqueé mi PC!»", "#00ff9d")
		_refresh_lure_tab_ui()
		_update_turbine_ui()
		_update_terminal_lock_state()
		_update_hud()

# =========================================================
# 5. DIBUJO DEL MAPA 3 - 2 - 2 - 1, MEDIDORES Y ECG
# =========================================================
func _update_energy_and_temp_hud() -> void:
	if is_instance_valid(lbl_energy_val):
		lbl_energy_val.text = "%d%%" % int(round(power_energy))
		lbl_energy_val.modulate = Color("#ff1744") if power_energy <= 25.0 else (Color("#ffcc00") if power_energy <= 55.0 else Color("#00ff9d"))
	if is_instance_valid(bar_energy):
		bar_energy.value = power_energy

	if is_instance_valid(lbl_temp_val):
		lbl_temp_val.text = "%d°C" % int(round(bunker_temperature))
		lbl_temp_val.modulate = Color("#ff1744") if bunker_temperature >= 75.0 else (Color("#ffaa00") if bunker_temperature >= 48.0 else Color("#00f0ff"))
	if is_instance_valid(bar_temperature):
		bar_temperature.value = bunker_temperature

	if is_instance_valid(lbl_companion_hack_status):
		var c_name = current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA"
		if companion_pc_unlocked:
			lbl_companion_hack_status.text = "👩‍💻 %s: REDUCIENDO HACKEO" % c_name
			lbl_companion_hack_status.modulate = Color("#00ff9d")
		else:
			lbl_companion_hack_status.text = "🔒 PC %s: BLOQUEADA (TAB 03)" % c_name
			lbl_companion_hack_status.modulate = Color("#ff1744")

func _draw_mia_ecg_wave() -> void:
	if not is_instance_valid(mia_ecg_graph):
		return
	var s = mia_ecg_graph.size
	if s.x <= 10 or s.y <= 10:
		return
	var mid_y = s.y * 0.55
	var col = Color("#00ff9d")
	if mia_lives <= 2:
		col = Color("#ff1744")
	elif mia_lives <= 3:
		col = Color("#ffaa00")

	mia_ecg_graph.draw_line(Vector2(0, mid_y), Vector2(s.x, mid_y), Color(col.r, col.g, col.b, 0.25), 1.0)

	var pts = PackedVector2Array()
	var steps = 42
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var x = t * s.x
		var phase = fmod(t * 2.8 - (mia_pulse_phase / TAU), 1.0)
		if phase < 0.0:
			phase += 1.0
		var y_offset = 0.0
		if mia_bpm > 0 and mia_lives > 0:
			var amp_mult = 1.0 + float(mia_max_lives - mia_lives) * 0.12
			if phase > 0.40 and phase < 0.47:
				y_offset = -s.y * 0.40 * amp_mult
			elif phase >= 0.47 and phase < 0.54:
				y_offset = s.y * 0.30 * amp_mult
			elif phase >= 0.54 and phase < 0.62:
				y_offset = -s.y * 0.16 * amp_mult
		pts.append(Vector2(x, clampf(mid_y + y_offset, 2.0, s.y - 2.0)))

	mia_ecg_graph.draw_polyline(pts, col, 2.0)

func _update_mia_vitals_ui() -> void:
	var hearts_str = ""
	for i in range(mia_max_lives):
		hearts_str += "♥" if i < mia_lives else "♡"
	mia_hp_percent = clampi(int(round(float(mia_lives) / float(max(1, mia_max_lives)) * 100.0)), 0, 100)

	if is_instance_valid(lbl_mia_hearts):
		lbl_mia_hearts.text = "%s" % hearts_str
		if mia_lives <= 1:
			lbl_mia_hearts.modulate = Color("#ff1744")
		elif mia_lives <= 3:
			lbl_mia_hearts.modulate = Color("#ffaa00")
		else:
			lbl_mia_hearts.modulate = Color("#ff4d94")

	if is_instance_valid(bar_mia_hp):
		bar_mia_hp.value = mia_hp_percent

	var suffering_heat: bool = (temp_hacked_by_monster or bunker_temperature >= 42.0 or music_box_charge < 45.0)
	if is_instance_valid(lbl_mia_bpm_overlay):
		if mia_lives <= 0 or mia_bpm <= 0:
			lbl_mia_bpm_overlay.text = "CRÍTICO"
			lbl_mia_bpm_overlay.modulate = Color("#ff1744")
		elif suffering_heat:
			lbl_mia_bpm_overlay.text = "🥵 %d BPM!" % mia_bpm
			lbl_mia_bpm_overlay.modulate = Color("#ff1744") if mia_bpm >= 145 else Color("#ffaa00")
		elif mia_lives <= 2:
			lbl_mia_bpm_overlay.text = "PELIGRO (%d)" % mia_bpm
			lbl_mia_bpm_overlay.modulate = Color("#ff1744")
		else:
			lbl_mia_bpm_overlay.text = "BIEN (%d)" % mia_bpm
			lbl_mia_bpm_overlay.modulate = Color("#00ff9d")

	if is_instance_valid(mia_portrait_border_style):
		if mia_lives <= 2 or (suffering_heat and mia_bpm >= 145):
			mia_portrait_border_style.border_color = Color("#ff1744")
		elif mia_lives <= 3 or suffering_heat:
			mia_portrait_border_style.border_color = Color("#ffaa00")
		else:
			mia_portrait_border_style.border_color = Color("#f600ff")

func _draw_tactical_map() -> void:
	var s = tactical_map.size
	if s.x < 40 or s.y < 40:
		return
	var font = ThemeDB.fallback_font
	var grid_col = Color(0.22, 0.25, 0.26, 0.08)

	var step = 20.0
	var x = 0.0
	while x < s.x:
		tactical_map.draw_line(Vector2(x, 0), Vector2(x, s.y), grid_col, 1.0)
		x += step
	var y = 0.0
	while y < s.y:
		tactical_map.draw_line(Vector2(0, y), Vector2(s.x, y), grid_col, 1.0)
		y += step

	tactical_map.draw_string(font, Vector2(8, 14), "MAPA DEL BÚNKER (RED DE CÁMARAS)", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#7c8588"))

	var mid_y = s.y * 0.50
	var top_y = s.y * 0.27
	var bot_y = s.y * 0.73

	var p_core = Vector2(s.x * 0.08, mid_y)
	var p_1a = Vector2(s.x * 0.23, s.y * 0.23) # Arriba: C1A
	var p_1 = Vector2(s.x * 0.23, mid_y)       # Medio: C1
	var p_1b = Vector2(s.x * 0.23, s.y * 0.77) # Abajo: C1B
	var p_2a = Vector2(s.x * 0.45, top_y)
	var p_2b = Vector2(s.x * 0.45, bot_y)
	var p_3a = Vector2(s.x * 0.67, top_y)
	var p_3b = Vector2(s.x * 0.67, bot_y)
	var p_4 = Vector2(s.x * 0.83, mid_y)
	var p_you = Vector2(s.x * 0.94, mid_y)

	map_node_positions = {
		"1A": p_1a,
		"1": p_1,
		"1B": p_1b,
		"2A": p_2a,
		"2B": p_2b,
		"3A": p_3a,
		"3B": p_3b,
		"4": p_4
	}

	var line_col = Color(0.38, 0.42, 0.44, 0.55)
	var edges = [
		[p_core, p_1a], [p_core, p_1], [p_core, p_1b],
		[p_1a, p_2a], [p_1a, p_2b], [p_1, p_2a], [p_1, p_2b], [p_1b, p_2a], [p_1b, p_2b],
		[p_2a, p_3a], [p_2b, p_3b], [p_2a, p_3b], [p_2b, p_3a],
		[p_3a, p_4], [p_3b, p_4], [p_4, p_you]
	]
	for e in edges:
		tactical_map.draw_line(e[0], e[1], line_col, 1.4)

	tactical_map.draw_circle(p_core, 7.0, Color(0.25, 0.04, 0.04, 0.9))
	tactical_map.draw_arc(p_core, 7.0, 0, TAU, 16, Color("#d9382e"), 1.6)
	tactical_map.draw_string(font, p_core + Vector2(-15, 18), "CIERRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#d9382e"))

	var you_col = Color("#2bbd7e")
	tactical_map.draw_circle(p_you, 7.0, Color(0.04, 0.18, 0.10, 0.9))
	tactical_map.draw_arc(p_you, 7.0, 0, TAU, 16, you_col, 1.6)
	tactical_map.draw_line(p_you + Vector2(-4, 0), p_you + Vector2(4, 0), you_col, 1.4)
	tactical_map.draw_line(p_you + Vector2(0, -4), p_you + Vector2(0, 4), you_col, 1.4)

	var monster_node = _get_monster_node_id()
	for node_id in CAM_NODE_IDS:
		var npos: Vector2 = map_node_positions[node_id]
		var d_state: String = door_node_states.get(node_id, "OPEN")
		var is_cam_sel: bool = (selected_cam_id == node_id)
		var is_monster_here: bool = monster_attack_active and (monster_node == node_id)

		var ncol = Color("#6e767a")
		var nfill = Color(0.07, 0.08, 0.09, 0.95)
		if is_cam_sel:
			ncol = Color("#d9a52e")
			nfill = Color(0.22, 0.15, 0.04, 0.95)
		elif d_state == "LOCKED":
			ncol = Color("#2bbd7e")
			nfill = Color(0.04, 0.20, 0.12, 0.95)
		elif d_state == "BREACHED":
			ncol = Color("#d9382e")
			nfill = Color(0.25, 0.04, 0.04, 0.95)
		elif is_monster_here and monster_spotted_on_cam:
			ncol = Color("#d9382e")
			nfill = Color(0.24, 0.06, 0.04, 0.95)

		var box_r = Rect2(npos - Vector2(15, 10), Vector2(30, 20))
		tactical_map.draw_rect(box_r, nfill, true)
		tactical_map.draw_rect(box_r, ncol, false, 1.8 if is_cam_sel else 1.2)
		tactical_map.draw_string(font, npos + Vector2(-10, 4), "C" + node_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#f0e6d2") if is_cam_sel else Color("#b0b8bc"))

		if monster_attack_active and is_monster_here and (monster_spotted_on_cam or not _is_branching_level(monster_security_level)):
			var m_dot = npos + Vector2(0, -14)
			tactical_map.draw_circle(m_dot, 4.0, Color("#d9382e"))

	var footer_txt = "⚡ %d%%   🌡️ %d°C   🌀 TURBINA %d%%  |  DEFENSAS %d/%d" % [
		int(power_energy),
		int(bunker_temperature),
		int(music_box_charge),
		gates_closed_by_guard,
		TOTAL_DEFENSES_REQUIRED
	]
	tactical_map.draw_string(font, Vector2(8, s.y - 6), footer_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#7c8588"))

# =========================================================
# 6. SHADER CRT Y MODALES DE MUERTE Y VICTORIA
# =========================================================
func _build_death_jumpscare_modal() -> void:
	death_modal = ColorRect.new()
	death_modal.color = Color(0.05, 0.0, 0.02, 0.96)
	death_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_modal.visible = false
	add_child(death_modal)

	death_art_canvas = Control.new()
	death_art_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_art_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_art_canvas.draw.connect(_draw_monster_jumpscare_art)
	death_modal.add_child(death_art_canvas)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_modal.add_child(center)

	var card = _create_cyber_panel(Color(0.09, 0.01, 0.03, 0.94), Color("#ff1744"), 3, 24)
	card.custom_minimum_size = Vector2(720, 420)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	lbl_death_title = Label.new()
	lbl_death_title.text = "☣️ BRECHA DE CONTENCIÓN — NOCHE PERDIDA"
	lbl_death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_death_title.add_theme_font_size_override("font_size", 26)
	lbl_death_title.modulate = Color("#ff1744")
	vbox.add_child(lbl_death_title)

	lbl_death_details = RichTextLabel.new()
	lbl_death_details.bbcode_enabled = true
	lbl_death_details.fit_content = true
	lbl_death_details.scroll_active = false
	lbl_death_details.custom_minimum_size = Vector2(640, 170)
	vbox.add_child(lbl_death_details)

	var btns_hbox = HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btns_hbox)

	var btn_retry_night = Button.new()
	btn_retry_night.text = "🔄 REINICIAR TURNO NOCTURNO (12:00 AM)"
	btn_retry_night.custom_minimum_size = Vector2(310, 52)
	btn_retry_night.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_retry_night, Color("#00ff9d"), true)
	btn_retry_night.pressed.connect(func():
		death_modal.visible = false
		load_mission(current_mission, false)
	)
	btns_hbox.add_child(btn_retry_night)

	var btn_death_vn = Button.new()
	btn_death_vn.text = "🎭 CAMBIAR COMPAÑERA / HISTORIA"
	btn_death_vn.custom_minimum_size = Vector2(280, 52)
	btn_death_vn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_death_vn, Color("#ff3366"), false)
	btn_death_vn.pressed.connect(func():
		death_modal.visible = false
		_launch_outro_vn()
	)
	btns_hbox.add_child(btn_death_vn)

func _draw_monster_jumpscare_art() -> void:
	var s = death_art_canvas.size
	var cx = s.x * 0.5
	var cy = s.y * 0.22
	var jitter = Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
	var left_eye = Vector2(cx - 110, cy) + jitter
	var right_eye = Vector2(cx + 110, cy) + jitter
	death_art_canvas.draw_circle(left_eye, 28.0, Color(1.0, 0.0, 0.15, 0.25))
	death_art_canvas.draw_circle(right_eye, 28.0, Color(1.0, 0.0, 0.15, 0.25))
	death_art_canvas.draw_circle(left_eye, 11.0, Color("#ff1744"))
	death_art_canvas.draw_circle(right_eye, 11.0, Color("#ff1744"))
	death_art_canvas.draw_circle(left_eye, 4.0, Color.WHITE)
	death_art_canvas.draw_circle(right_eye, 4.0, Color.WHITE)
	for i in range(5):
		var offset_x = (i - 2) * 85.0
		death_art_canvas.draw_line(
			Vector2(cx + offset_x - 40, 40) + jitter,
			Vector2(cx + offset_x + 40, s.y - 40) - jitter,
			Color(1.0, 0.05, 0.2, 0.16),
			4.0
		)

func _create_fullscreen_crt_shader() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)

	var crt_rect = ColorRect.new()
	crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.65;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(SCREEN_TEXTURE, uv).rgb;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma * 0.95, luma * 1.02, luma * 0.96), 0.28);

	float scanline = sin(uv.y * 850.0) * 0.025;
	float grain = (hash(uv * 420.0 + fract(TIME * 0.5)) - 0.5) * 0.045;
	col -= scanline;
	col += grain;

	float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	float vig_factor = clamp(pow(18.0 * vig, 0.22), 0.0, 1.0);
	col *= mix(1.0, vig_factor, 0.75);

	COLOR = vec4(col, 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", crt_intensity)
	crt_rect.material = mat
	canvas_layer.add_child(crt_rect)

func _load_board_texture(res_path: String) -> Texture2D:
	var abs_path = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img = Image.load_from_file(abs_path)
		if is_instance_valid(img) and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(res_path):
		return load(res_path)
	return null

func _create_portrait_crt_material(tint_col: Color) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 crt_tint : source_color = vec4(0.9, 1.0, 0.96, 1.0);

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	vec2 warped_uv = UV + centered * (dot(centered, centered) * 0.035);
	vec2 uv = clamp(warped_uv, vec2(0.002), vec2(0.998));

	float glitch_wave = sin(uv.y * 55.0 + TIME * 9.0) * step(0.94, fract(sin(floor(TIME * 4.0) * 43.758)));
	float shift = 0.0045 + abs(glitch_wave) * 0.008;

	float r = texture(TEXTURE, clamp(uv + vec2(shift, 0.0), vec2(0.0), vec2(1.0))).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, clamp(uv - vec2(shift, 0.0), vec2(0.0), vec2(1.0))).b;
	vec3 col = vec3(r, g, b) * crt_tint.rgb;

	float scanline = sin(uv.y * 290.0 - TIME * 6.0) * 0.11;
	col -= scanline;

	float roll_bar = smoothstep(0.0, 0.14, fract(uv.y - TIME * 0.24)) * (1.0 - smoothstep(0.14, 0.28, fract(uv.y - TIME * 0.24)));
	col += vec3(0.05, 0.09, 0.08) * roll_bar;

	float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	float vig_factor = clamp(pow(16.0 * vig, 0.24), 0.0, 1.0);
	col *= mix(0.55, 1.08, vig_factor);

	COLOR = vec4(col, COLOR.a);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("crt_tint", tint_col)
	return mat

func _create_portrait_crt_overlay(accent_col: Color) -> ColorRect:
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(1, 1, 1, 1)

	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 beam_color : source_color = vec4(0.0, 1.0, 0.65, 1.0);

void fragment() {
	vec2 uv = UV;
	float fine_lines = step(0.5, fract(uv.y * 115.0));
	float roll = exp(-pow((fract(uv.y - TIME * 0.24) - 0.15) * 14.0, 2.0));
	float noise = fract(sin(dot(uv + vec2(TIME * 0.13, TIME * 0.07), vec2(12.9898, 78.233))) * 43758.5453);

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float border_dark = 1.0 - smoothstep(0.0, 0.12, min(edge_x, edge_y));

	vec3 col = beam_color.rgb * (roll * 0.22 + noise * 0.05);
	float alpha = fine_lines * 0.12 + roll * 0.16 + noise * 0.035 + border_dark * 0.28;
	COLOR = vec4(col, clamp(alpha, 0.0, 0.55));
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("beam_color", accent_col)
	overlay.material = mat
	return overlay

# =========================================================
# 7. LÓGICA DEL MONSTRUO, PUERTAS (0-10s RANDOM) Y RESOLUCIÓN
# =========================================================
func _on_monster_completed_hack(reason_msg: String) -> void:
	if not game_active or not is_instance_valid(current_mission):
		return
	var breached_node = _get_monster_node_id()
	if door_node_states.get(breached_node, "OPEN") == "LOCKED" and power_energy > 0.0:
		monster_hack_progress = 85.0
		if door_hold_target_time < 0.0:
			door_hold_target_time = randf_range(1.5, 8.0)
			door_hold_timer = 0.0
		return

	var next_lvl = min(TOTAL_SECURITY_LEVELS, monster_security_level + 1)
	var candidate_branch = _random_branch_for_level(next_lvl)
	var next_node_id = _node_id_for(next_lvl, candidate_branch)
	if door_node_states.get(next_node_id, "OPEN") == "LOCKED" and power_energy > 0.0:
		monster_security_level = next_lvl
		monster_branch = candidate_branch
		monster_spotted_on_cam = true
		monster_hack_progress = 50.0
		door_hold_target_time = randf_range(1.5, 8.0)
		door_hold_timer = 0.0
		_log_chat("PUERTA_ANTICIPADA", "🚪 ¡Subject-Zero intentó avanzar a [C%s], pero ya tenías esa puerta CERRADA! Quedó retenido frente a [C%s] sin hacerte daño." % [next_node_id, next_node_id], "#00ff9d")
		_select_camera(next_node_id)
		_update_terminal_lock_state()
		_update_hud()
		return

	monster_hack_progress = 0.0
	door_hold_timer = 0.0
	door_hold_target_time = -1.0

	if current_mission.companion_perk == "forgive_hack" and naomi_shield_charges > 0:
		naomi_shield_charges -= 1
		bpm = max(85, bpm - 10)
		_log_chat("NAOMI_SAVED_YOU", "🛡️ [NAOMI BLOQUEÓ LA BRECHA EN CAM %s!]: «%s ¡Intercepté el ataque con mi escudo Aegis! (0/1 Escudo restante)»" % [
			breached_node,
			reason_msg
		], "#00ff9d")
		_update_companion_perk_ui()
		_update_hud()
		_generate_breach_matrix()
		return

	door_node_states[breached_node] = "BREACHED"
	monster_last_node_id = breached_node
	monster_security_level += 1
	monster_branch = candidate_branch
	monster_spotted_on_cam = (monster_security_level >= TOTAL_SECURITY_LEVELS) or (selected_cam_id == _get_monster_node_id())
	bpm = min(max_bpm, bpm + 14)

	mia_lives = max(0, mia_lives - 1)
	mia_bpm = min(195, mia_bpm + 24)
	mia_damage_flash = 1.0
	_update_mia_vitals_ui()

	if mia_lives <= 0 or monster_security_level > TOTAL_SECURITY_LEVELS:
		_trigger_level_5_fatal_breach()
		return

	var next_stage_hint = ("¡Revisá las cámaras [%s] para ver qué pasillo tomó!" % _stage_doors_text(monster_security_level)) if _is_branching_level(monster_security_level) else ("¡Llegó a la Puerta Final 4!")
	_log_chat("BRECHA", "☣️ [PUERTA C%s VULNERADA!]: %s 💔 Tu compañera perdió 1 Corazón (%d/%d)! %s" % [
		breached_node,
		reason_msg,
		mia_lives,
		mia_max_lives,
		next_stage_hint
	], "#ff1744")
	_generate_breach_matrix()
	_update_turbine_ui()
	_refresh_lure_tab_ui()
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()

func _trigger_level_5_fatal_breach() -> void:
	game_active = false
	game_timer.stop()
	bpm = 0
	mia_lives = 0
	mia_hp_percent = 0
	mia_bpm = 0
	_update_mia_vitals_ui()
	last_outcome_type = "failure"
	var comp_name = current_mission.agent_name.to_upper()
	var guard_name = current_mission.security_guard_name.to_upper()
	var m_name = current_mission.monster_name

	_log_chat("FATAL_BREACH", "💀 %s VULNERÓ LA PUERTA FINAL 4! %s FUE ASESINADA Y EL MONSTRUO ACABÓ CON VOS!" % [m_name, comp_name], "#ff1744")
	status_overlay.text = "● BRECHA CRÍTICA // %s: 0%% HP // OPERADOR: CAÍDO" % comp_name
	status_overlay.modulate = Color("#ff1744")
	btn_continue_vn.visible = true

	if is_instance_valid(death_modal):
		lbl_death_title.text = "☣️ CONTENCIÓN VULNERADA — NOCHE FALLIDA"
		lbl_death_details.text = "[center][color=#ff6688][b]%s[/b] atravesó las puertas del búnker antes de que [b]%s[/b] y vos pudieran contenerlo.[/color]\n\n[color=#ff1744][b]1. %s cayó frente a tu consola.[/b]\n[b]2. Instantes después, %s destruyó la terminal y acabó con tu vida.[/b][/color]\n\n[color=#00ff9d]Hacé clic abajo para reiniciar el turno desde las 12:00 AM![/color][/center]" % [
			m_name,
			guard_name,
			comp_name,
			m_name
		]
		death_modal.visible = true

func _on_second_tick() -> void:
	if not game_active:
		return
	time_left -= 1
	bpm = clamp(bpm + randi_range(1, 3), 65, max_bpm)
	if mia_lives > 0:
		var base_mia_bpm = 90 + (mia_max_lives - mia_lives) * 20
		if temp_hacked_by_monster:
			base_mia_bpm += 42
		if bunker_temperature > NORMAL_TEMP:
			base_mia_bpm += int((bunker_temperature - NORMAL_TEMP) * 1.15)
		if music_box_charge < 45.0:
			base_mia_bpm += 22
		mia_bpm = clampi(base_mia_bpm + randi_range(-3, 5), 75, 198)

	if (temp_hacked_by_monster or bunker_temperature >= 48.0 or music_box_charge < 40.0) and time_left % 8 == 0:
		var comp_n = current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA"
		_log_chat(comp_n, "«¡Hace demasiado calor en la sala (%d°C) y mi corazón va a %d BPM! ¡Impulsá la Turbina en [Tab 01] al >85%% para purgar la refrigeración!»" % [int(bunker_temperature), mia_bpm], "#ff4d94")

	_update_hud()

	if bpm >= int(max_bpm * 0.85) and time_left % 9 == 0:
		_log_chat(current_mission.agent_name.to_upper(), current_mission.agent_panic_line, "#ff3366")

	if bpm >= max_bpm:
		bpm = int(max_bpm * 0.78)
		var cur_m_node = _get_monster_node_id()
		if monster_attack_active and music_box_charge < 40.0 and door_node_states.get(cur_m_node, "OPEN") != "LOCKED":
			monster_hack_progress = min(100.0, monster_hack_progress + 12.0)
	elif time_left <= 0:
		_end_game(true, "mission", "¡06:00 AM ALCANZADAS! ¡Sobreviviste la noche junto a %s y %s!" % [current_mission.agent_name, current_mission.security_guard_name])

func _on_seal_door_choice_pressed(_branch_choice: String = "A") -> void:
	if not game_active:
		return
	var chosen_node_id: String = selected_cam_id
	var cur_state: String = door_node_states.get(chosen_node_id, "OPEN")

	if cur_state == "LOCKED":
		door_node_states[chosen_node_id] = "OPEN"
		if chosen_node_id == _get_monster_node_id():
			door_hold_timer = 0.0
			door_hold_target_time = -1.0
		_log_chat("PUERTAS", "🔓 Abriste la Puerta [C%s] para ahorrar Energía eléctrica." % chosen_node_id, "#88ccee")
		_select_camera(chosen_node_id)
		_update_terminal_lock_state()
		_refresh_lure_tab_ui()
		return

	if power_energy <= 2.0:
		_log_chat("SISTEMA", "⚠️ ¡No hay Energía suficiente para cerrar la Puerta [C%s]!" % chosen_node_id, "#ff1744")
		return

	power_energy = max(0.0, power_energy - 4.0)
	door_node_states[chosen_node_id] = "LOCKED"
	_select_camera(chosen_node_id)

	var actual_monster_node = _get_monster_node_id()
	if monster_attack_active and chosen_node_id == actual_monster_node:
		door_hold_target_time = randf_range(1.5, 10.0)
		door_hold_timer = 0.0
		monster_is_moving = false
		_log_chat("PUERTAS", "🚪 ¡Cerraste la Puerta [C%s] frente a Subject-Zero! Mantenela cerrada con Energía (se irá entre 1.5 y 10 segundos)!" % chosen_node_id, "#00ff9d")
	else:
		_log_chat("PUERTAS", "🚪 Puerta [C%s] cerrada preventivamente (consumiendo Energía)." % chosen_node_id, "#ffcc00")

	_update_energy_and_temp_hud()
	_refresh_lure_tab_ui()
	_update_terminal_lock_state()
	_update_hud()

func _on_monster_left_after_closed_door(repelled_node_id: String, waited_seconds: float) -> void:
	gates_closed_by_guard += 1
	monster_hack_progress = 0.0
	door_hold_timer = 0.0
	door_hold_target_time = -1.0
	affinity = min(100, affinity + 12)
	bpm = max(70, bpm - 12)
	mia_prediction_ready = (current_mission.companion_perk == "prediction")

	if gates_closed_by_guard >= TOTAL_DEFENSES_REQUIRED:
		_update_hud()
		var final_route = "romance" if affinity >= 75 else "mission"
		var win_txt = current_mission.romance_success_text if final_route == "romance" else current_mission.mission_success_text
		_end_game(true, final_route, win_txt)
		return

	monster_attack_active = false
	monster_is_moving = false
	monster_spotted_on_cam = false
	monster_hack_progress = 0.0
	monster_last_node_id = repelled_node_id
	monster_advance_on_next_wave = false
	monster_cooldown_timer = randf_range(5.0, 15.5)

	_log_chat(current_mission.agent_name.to_upper(), "🚪 «¡Se fue! Después de %0.1f segundos con la Puerta [C%s] cerrada, Subject-Zero desistió y desapareció (%d/%d defensas). ¡Ya podés abrir la puerta para no gastar Energía!»" % [
		waited_seconds,
		repelled_node_id,
		gates_closed_by_guard,
		TOTAL_DEFENSES_REQUIRED
	], "#00ff9d")

	_refresh_lure_tab_ui()
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()
	_update_3d_previz(0.0)


func _end_game(victory: bool, outcome_type: String, reason: String) -> void:
	game_active = false
	game_timer.stop()
	last_outcome_type = outcome_type
	var color = "#2bbd7e" if victory else "#ff3366"
	_log_chat("RESULTADO", ("🏆 ¡GANASTE! " + reason) if victory else reason, color)
	status_overlay.text = "● CONTENCIÓN: " + ("🏆 ¡GANASTE! NOCHE COMPLETADA" if victory else "VULNERADO")
	status_overlay.modulate = Color(color)
	btn_continue_vn.visible = true

	if victory and is_instance_valid(victory_modal):
		var comp_name = current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA"
		lbl_victory_title.text = "🏆 ¡GANASTE! — 06:00 AM // NOCHE SUPERADA"
		lbl_victory_details.text = "[center][color=#aaddff][b]%s[/b][/color]\n\n[color=#2bbd7e][b]• Estado de %s:[/b] A SALVO (%d/%d ♥)  |  [b]Vínculo:[/b] %d%%\n[b]• Energía Restante:[/b] %d%%  |  [b]Temperatura Final:[/b] %d°C[/color]\n\n[color=#d8dfdc]¡Lograste contener a Subject-Zero y sobrevivir el turno nocturno de prueba![/color][/center]" % [
			reason,
			comp_name,
			mia_lives,
			mia_max_lives,
			affinity,
			int(power_energy),
			int(bunker_temperature)
		]
		victory_modal.visible = true

func _build_victory_modal() -> void:
	victory_modal = ColorRect.new()
	victory_modal.color = Color(0.02, 0.06, 0.04, 0.94)
	victory_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_modal.visible = false
	add_child(victory_modal)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_modal.add_child(center)

	var card = _create_cyber_panel(Color(0.05, 0.10, 0.08, 0.96), Color("#2bbd7e"), 3, 24)
	card.custom_minimum_size = Vector2(700, 390)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	lbl_victory_title = Label.new()
	lbl_victory_title.text = "🏆 ¡GANASTE! — 06:00 AM // NOCHE SUPERADA"
	lbl_victory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_victory_title.add_theme_font_size_override("font_size", 26)
	lbl_victory_title.modulate = Color("#2bbd7e")
	vbox.add_child(lbl_victory_title)

	lbl_victory_details = RichTextLabel.new()
	lbl_victory_details.bbcode_enabled = true
	lbl_victory_details.fit_content = true
	lbl_victory_details.scroll_active = false
	lbl_victory_details.custom_minimum_size = Vector2(620, 150)
	vbox.add_child(lbl_victory_details)

	var btns_hbox = HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btns_hbox)

	var btn_play_again = Button.new()
	btn_play_again.text = "🔄 JUGAR DE NUEVO LA NOCHE"
	btn_play_again.custom_minimum_size = Vector2(280, 50)
	btn_play_again.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_play_again, Color("#2bbd7e"), true)
	btn_play_again.pressed.connect(func():
		victory_modal.visible = false
		load_mission(current_mission, false)
	)
	btns_hbox.add_child(btn_play_again)

	var btn_win_vn = Button.new()
	btn_win_vn.text = "🎭 VER EPÍLOGO / HISTORIA >>"
	btn_win_vn.custom_minimum_size = Vector2(280, 50)
	btn_win_vn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_win_vn, Color("#00f0ff"), false)
	btn_win_vn.pressed.connect(func():
		victory_modal.visible = false
		_launch_outro_vn()
	)
	btns_hbox.add_child(btn_win_vn)

func _launch_outro_vn() -> void:
	if embedded_in_vn_engine:
		hacking_completed.emit(last_outcome_type, affinity)
		return
	var script_to_play = current_mission.vn_outro_mission_script
	if last_outcome_type == "romance":
		script_to_play = current_mission.vn_outro_romance_script
	elif last_outcome_type == "failure":
		script_to_play = current_mission.vn_outro_failure_script
	start_vn_sequence(script_to_play, "outro")

func _update_hud() -> void:
	var total_t = max(1, current_mission.mission_time_seconds if is_instance_valid(current_mission) else 180)
	var elapsed_ratio = clampf(1.0 - (float(time_left) / float(total_t)), 0.0, 1.0)
	var hour_num = int(floor(elapsed_ratio * 6.0))
	var display_hr = 12 if hour_num == 0 else hour_num
	lbl_timer.text = "🕒 %02d:00 AM (%02ds)" % [display_hr, time_left]
	bar_trace.value = time_left
	bar_affinity.value = affinity
	lbl_affinity.text = "♥ VÍNCULO (%s): %d%%  |  VIDAS: %d/5 ♥  |  ETAPA: %d/4" % [
		current_mission.agent_name.to_upper(),
		affinity,
		mia_lives,
		clampi(monster_security_level, 1, TOTAL_SECURITY_LEVELS)
	]
	_update_mia_vitals_ui()
	_update_energy_and_temp_hud()

func _populate_mission_selector() -> void:
	mission_selector.clear()
	for i in range(available_missions.size()):
		var m = available_missions[i]
		var perk_short = "Predicción" if m.companion_perk == "prediction" else "Escudo 1-Brecha"
		mission_selector.add_item("%s (%s)" % [m.agent_name, perk_short], i)

func _create_default_template(p_name: String, p_code: String, p_color: Color, p_pos: Vector2) -> MissionData:
	var m = MissionData.new()
	m.agent_name = p_name
	m.agent_codename = p_code
	m.agent_color = p_color
	m.map_agent_pos = p_pos
	if p_name.to_lower() == "naomi":
		m.companion_perk = "forgive_hack"
		m.security_guard_name = "Mia"
		m.security_guard_codename = "ORACLE-01"
	else:
		m.companion_perk = "prediction"
		m.security_guard_name = "Naomi"
		m.security_guard_codename = "AEGIS-02"
	return m

func _log_chat(sender: String, msg: String, hex_color: String) -> void:
	rtl_chat.append_text("[color=#446688][%02ds][/color] [color=%s][b][%s]:[/b][/color] %s\n\n" % [time_left, hex_color, sender, msg])

# =========================================================
# 8. HELPERS DE ESTILO VISUAL (INDUSTRIAL GRUNGE BUNKER UI KIT)
# =========================================================
func _remap_industrial_color(c: Color) -> Color:
	if c.b > 0.8 and c.g > 0.7 and c.r < 0.2:
		return Color("#3a4245")
	if c.r > 0.7 and c.b > 0.6:
		return Color("#d9382e")
	if c.g > 0.85 and c.r < 0.2:
		return Color("#2bbd7e")
	return c

func _create_cyber_panel(bg_color: Color, border_color: Color, border_w: int = 1, pad: int = 8) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r * 0.55, bg_color.g * 0.55, bg_color.b * 0.55, 0.96)
	style.border_color = _remap_industrial_color(border_color)
	style.set_border_width_all(1)
	style.border_width_top = max(1, border_w)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(pad)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_badge_label(txt: String, _font_col: Color, bg_col: Color) -> Label:
	var lbl = Label.new()
	_update_badge_style(lbl, txt, Color("#d8dedc"), bg_col)
	return lbl

func _update_badge_style(lbl: Label, txt: String, _font_col: Color, bg_col: Color) -> void:
	lbl.text = "  " + txt + "  "
	lbl.add_theme_font_size_override("font_size", 11)
	var mapped = _remap_industrial_color(bg_col)
	lbl.add_theme_color_override("font_color", mapped.lightened(0.35))
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.09, 0.10, 0.95)
	st.border_color = mapped
	st.set_border_width_all(1)
	st.set_corner_radius_all(2)
	st.set_content_margin_all(4)
	lbl.add_theme_stylebox_override("normal", st)

func _apply_styled_button(btn: Button, col: Color, prominent: bool = true) -> void:
	var ind_col = _remap_industrial_color(col)
	var style_normal = StyleBoxFlat.new()
	if prominent and ind_col.r > 0.6 and ind_col.g < 0.4:
		style_normal.bg_color = Color(0.38, 0.09, 0.08, 0.95)
		style_normal.border_color = Color("#e0463a")
	elif prominent:
		style_normal.bg_color = Color(0.11, 0.14, 0.14, 0.95)
		style_normal.border_color = ind_col
	else:
		style_normal.bg_color = Color(0.08, 0.09, 0.10, 0.92)
		style_normal.border_color = Color("#2c3235")

	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(2)
	style_normal.set_content_margin_all(7)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.18, 0.22, 0.21, 0.98)
	style_hover.border_color = ind_col.lightened(0.25)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.06, 0.07, 0.08, 0.75)
	style_disabled.border_color = Color("#1e2224")

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", Color("#d8dfdc"))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("#52585b"))

func _style_matrix_cell(btn: Button, bg_col: Color, border_col: Color, font_col: Color) -> void:
	var st = StyleBoxFlat.new()
	st.bg_color = Color(bg_col.r * 0.6, bg_col.g * 0.6, bg_col.b * 0.6, 0.95)
	st.border_color = _remap_industrial_color(border_col)
	st.set_border_width_all(1)
	st.set_corner_radius_all(2)
	var st_hover = st.duplicate()
	st_hover.bg_color = Color(0.16, 0.22, 0.20, 0.95)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_hover)
	btn.add_theme_stylebox_override("disabled", st)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_disabled_color", font_col)

func _style_progress_bar(bar: ProgressBar, _bg_col: Color, fill_col: Color) -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color("#0c0f10")
	sb_bg.border_color = Color("#262b2d")
	sb_bg.set_border_width_all(1)
	sb_bg.set_corner_radius_all(2)
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color("#2bbd7e") if fill_col.g > 0.6 else _remap_industrial_color(fill_col)
	sb_fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fill)

func _style_tab_container(tc: TabContainer) -> void:
	var panel_st = StyleBoxFlat.new()
	panel_st.bg_color = Color("#090b0c")
	panel_st.border_color = Color("#282d30")
	panel_st.set_border_width_all(1)
	panel_st.set_corner_radius_all(2)
	panel_st.set_content_margin_all(10)

	var tab_sel = StyleBoxFlat.new()
	tab_sel.bg_color = Color("#16191b")
	tab_sel.border_color = Color("#d9382e")
	tab_sel.border_width_top = 2
	tab_sel.set_content_margin_all(8)

	var tab_unsel = StyleBoxFlat.new()
	tab_unsel.bg_color = Color("#0a0c0d")
	tab_unsel.border_color = Color("#1f2326")
	tab_unsel.border_width_top = 1
	tab_unsel.set_content_margin_all(8)

	tc.add_theme_stylebox_override("panel", panel_st)
	tc.add_theme_stylebox_override("tab_selected", tab_sel)
	tc.add_theme_stylebox_override("tab_unselected", tab_unsel)
	tc.add_theme_color_override("font_selected_color", Color("#e0463a"))
	tc.add_theme_color_override("font_unselected_color", Color("#7c8588"))

func _create_doc_tab_wrapper() -> MarginContainer:
	var m = MarginContainer.new()
	m.clip_contents = true
	for side in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	return m

func _draw_3d_monitor_diorama() -> void:
	if not is_instance_valid(monitor_3d_diorama):
		return
	var s: Vector2 = monitor_3d_diorama.size
	if s.x < 100 or s.y < 100:
		return
	var font: Font = ThemeDB.fallback_font

	# Coordenadas de la pantalla física (con leve perspectiva trapezoidal 3D en el chasis exterior)
	var scr_tl := Vector2(70.0, 50.0)
	var scr_tr := Vector2(s.x - 84.0, 50.0)
	var scr_bl := Vector2(70.0, s.y - 64.0)
	var scr_br := Vector2(s.x - 84.0, s.y - 64.0)

	var out_tl := Vector2(36.0, 20.0)
	var out_tr := Vector2(s.x - 24.0, 28.0)
	var out_bl := Vector2(22.0, s.y - 34.0)
	var out_br := Vector2(s.x - 16.0, s.y - 26.0)

	# 1. PARED TRASERA DEL BÚNKER Y TUBERÍAS SUPERIORES
	for pipe_x in [s.x * 0.18, s.x * 0.24, s.x * 0.52, s.x * 0.78, s.x * 0.88]:
		monitor_3d_diorama.draw_rect(Rect2(pipe_x, 0.0, 18.0, 32.0), Color("#121518"), true)
		monitor_3d_diorama.draw_line(Vector2(pipe_x + 4.0, 0.0), Vector2(pipe_x + 4.0, 32.0), Color(1, 1, 1, 0.06), 2.0)

	# Logo circular tipo SCP en la pared superior derecha (como en la imagen)
	var wall_logo_c := Vector2(s.x * 0.76, 18.0)
	monitor_3d_diorama.draw_arc(wall_logo_c, 22.0, 0.0, TAU, 28, Color(0.35, 0.38, 0.40, 0.22), 2.5)
	monitor_3d_diorama.draw_arc(wall_logo_c, 12.0, 0.0, TAU, 20, Color(0.35, 0.38, 0.40, 0.22), 2.0)

	# 2. SIRENA ROJA DE ALARMA EN LA ESQUINA SUPERIOR IZQUIERDA (CON RESPLANDOR VOLUMÉTRICO)
	var alarm_pulse: float = 0.65 + 0.35 * sin(pulse_phase * 1.8)
	if monster_attack_active or _count_active_errors() > 0 or bunker_temperature >= 60.0:
		alarm_pulse = 0.85 + 0.15 * sin(pulse_phase * 4.5)
	var lamp_pos := Vector2(96.0, 18.0)
	for r_i in range(6, 0, -1):
		var rad: float = float(r_i) * 28.0
		monitor_3d_diorama.draw_circle(lamp_pos, rad, Color(0.95, 0.12, 0.08, 0.045 * alarm_pulse))
	monitor_3d_diorama.draw_circle(lamp_pos, 14.0, Color(1.0, 0.22, 0.15, 0.9 * alarm_pulse))
	monitor_3d_diorama.draw_circle(lamp_pos, 7.0, Color(1.0, 0.75, 0.65, 0.95 * alarm_pulse))
	# Jaula metálica de la sirena
	monitor_3d_diorama.draw_arc(lamp_pos, 15.0, 0.0, TAU, 16, Color("#2a1210"), 2.0)
	monitor_3d_diorama.draw_line(lamp_pos + Vector2(-15, 0), lamp_pos + Vector2(15, 0), Color("#2a1210"), 1.5)
	monitor_3d_diorama.draw_line(lamp_pos + Vector2(0, -15), lamp_pos + Vector2(0, 15), Color("#2a1210"), 1.5)

	# 3. ESCRITORIO METÁLICO INFERIOR EN PERSPECTIVA 3D
	var desk_poly := PackedVector2Array([
		Vector2(0.0, s.y - 42.0),
		Vector2(s.x, s.y - 34.0),
		Vector2(s.x, s.y),
		Vector2(0.0, s.y)
	])
	monitor_3d_diorama.draw_colored_polygon(desk_poly, Color("#0a0c0e"))
	monitor_3d_diorama.draw_line(Vector2(0.0, s.y - 42.0), Vector2(s.x, s.y - 34.0), Color("#22282a"), 2.0)

	# Rejilla de ventilación del escritorio y reflejo naranja/rojo de los botones sobre la mesa
	for gx in range(int(s.x * 0.18), int(s.x * 0.52), 16):
		monitor_3d_diorama.draw_line(Vector2(gx, s.y - 28.0), Vector2(gx - 18.0, s.y - 4.0), Color("#15191c"), 2.0)
	monitor_3d_diorama.draw_circle(Vector2(s.x * 0.25, s.y - 12.0), 42.0, Color(0.95, 0.22, 0.12, 0.08 * alarm_pulse))

	# 4. CARCASA EXTERIOR 3D DEL MONITOR (BISEL TRAPEZOIDAL + PANEL "BÚNKER B7" A LA DERECHA)
	var chassis_poly := PackedVector2Array([out_tl, out_tr, out_br, out_bl])
	monitor_3d_diorama.draw_colored_polygon(chassis_poly, Color("#121517"))
	monitor_3d_diorama.draw_polyline(PackedVector2Array([out_tl, out_tr, out_br, out_bl, out_tl]), Color("#2c3336"), 2.5)

	# Bisel interno en perspectiva conectando el chasis exterior con la pantalla hundida
	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([out_tl, out_tr, scr_tr, scr_tl]), Color("#181c1f"))
	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([scr_bl, scr_br, out_br, out_bl]), Color("#0c0e10"))
	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([out_tl, scr_tl, scr_bl, out_bl]), Color("#14181b"))
	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([scr_tr, out_tr, out_br, scr_br]), Color("#101315"))

	# Líneas de unión en las 4 esquinas del bisel 3D
	monitor_3d_diorama.draw_line(out_tl, scr_tl, Color("#2a3033"), 2.0)
	monitor_3d_diorama.draw_line(out_tr, scr_tr, Color("#2a3033"), 2.0)
	monitor_3d_diorama.draw_line(out_bl, scr_bl, Color("#2a3033"), 2.0)
	monitor_3d_diorama.draw_line(out_br, scr_br, Color("#2a3033"), 2.0)

	# Tira LED vertical roja y rótulo "BÚNKER B7" en el marco derecho del monitor (igual a la foto)
	var right_frame_x: float = s.x - 76.0
	monitor_3d_diorama.draw_rect(Rect2(right_frame_x + 12.0, s.y * 0.24, 5.0, s.y * 0.18), Color(0.95, 0.18, 0.12, 0.85 * alarm_pulse), true)
	monitor_3d_diorama.draw_circle(Vector2(right_frame_x + 14.0, s.y * 0.20), 4.0, Color("#d9382e"))
	monitor_3d_diorama.draw_string(font, Vector2(right_frame_x - 2.0, s.y * 0.50), "BÚNKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#5c6466"))
	monitor_3d_diorama.draw_string(font, Vector2(right_frame_x - 2.0, s.y * 0.55), "B7", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#6e777a"))

	# Tornillos/remaches industriales en el marco del monitor
	for rv in [Vector2(52, 36), Vector2(52, s.y - 48), Vector2(s.x - 42, 42), Vector2(s.x - 42, s.y - 44)]:
		monitor_3d_diorama.draw_circle(rv, 3.5, Color("#090b0c"))
		monitor_3d_diorama.draw_arc(rv, 3.5, 0.0, TAU, 10, Color("#2e3538"), 1.2)

	# 5. TAZA DE CAFÉ CON EL LOGO EN LA ESQUINA INFERIOR IZQUIERDA (DELANTE DEL MONITOR)
	var mug_pos := Vector2(18.0, s.y - 118.0)
	var mug_size := Vector2(78.0, 96.0)
	# Asa de la taza
	monitor_3d_diorama.draw_arc(mug_pos + Vector2(mug_size.x + 2.0, mug_size.y * 0.52), 20.0, -PI * 0.45, PI * 0.45, 16, Color("#2c2a29"), 7.0)
	# Cuerpo de la taza sucia
	monitor_3d_diorama.draw_rect(Rect2(mug_pos, mug_size), Color("#252322"), true)
	monitor_3d_diorama.draw_rect(Rect2(mug_pos + Vector2(6, 4), Vector2(14, mug_size.y - 8)), Color(1, 1, 1, 0.05), true)
	monitor_3d_diorama.draw_rect(Rect2(mug_pos, mug_size), Color("#3d3a38"), false, 2.0)
	# Boca elíptica superior de la taza
	monitor_3d_diorama.draw_circle(mug_pos + Vector2(mug_size.x * 0.5, 4.0), 10.0, Color("#121010"))
	# Símbolo circular en la taza
	var mug_logo := mug_pos + Vector2(mug_size.x * 0.48, mug_size.y * 0.56)
	monitor_3d_diorama.draw_arc(mug_logo, 16.0, 0.0, TAU, 20, Color("#121110"), 2.0)
	monitor_3d_diorama.draw_arc(mug_logo, 8.0, 0.0, TAU, 16, Color("#121110"), 1.6)
