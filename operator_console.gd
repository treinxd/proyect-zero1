extends Control

signal hacking_completed(outcome_type: String, final_affinity: int)

@export var available_missions: Array[MissionData] = []
@export var starting_mission_index: int = 0
@export var start_in_vn_mode: bool = false
@export var enable_crt_effect: bool = false
@export_range(0.0, 1.0, 0.05) var crt_intensity: float = 0.55

var embedded_in_vn_engine: bool = false

# --- ESTADO DINÁMICO (FNAF 2D + HACKING + DATING SIM) ---
var current_mission: MissionData
var bpm: int = 95
var max_bpm: int = 175
var affinity: int = 50
var time_left: int = 180
var game_active: bool = false
var reassure_used: bool = false
var pulse_phase: float = 0.0
var radar_angle: float = 0.0
var last_outcome_type: String = "mission" # "mission", "romance", "failure"

# --- ESTADO DE CONTENCIÓN DEL MONSTRUO (TOPOLOGÍA FNAF 1 - 2 - 2 - 1) ---
const TOTAL_SECURITY_LEVELS: int = 4 # 4 etapas: 1 (C1/C1B/C1C) -> 2 (2A/2B) -> 2 (3A/3B) -> 1 (4 Final)
const TOTAL_DEFENSES_REQUIRED: int = 5 # 5 defensas por noche
const CAM_NODE_IDS: Array[String] = ["1", "1B", "1C", "2A", "2B", "3A", "3B", "4"]
var monster_security_level: int = 1 # Etapa actual 1..4 (1 = C1/C1B/C1C, 2 = G2A/G2B, 3 = G3A/G3B, 4 = G4)
var monster_branch: String = "A" # Etapa 1: "A" (C1), "B" (C1B), "C" (C1C) | Etapas 2 y 3: "A" o "B"
var monster_spotted_on_cam: bool = false # Se activa al mirar la cámara donde está el monstruo o con predicción de Mia
var monster_attack_active: bool = false # Ataques intermitentes estilo FNaF (no siempre está atacando)
var monster_cooldown_timer: float = 5.0 # Tiempo impredecible entre ataques
var monster_last_node_id: String = "1" # Última puerta donde quedó el monstruo tras defender
var monster_advance_on_next_wave: bool = false # Si avanza desde la última puerta al iniciar el siguiente ataque
var gates_closed_by_guard: int = 0
var gate_states: Array[String] = ["OPEN", "OPEN", "OPEN", "OPEN", "OPEN"]
var door_node_states: Dictionary = {
	"1": "OPEN",
	"1B": "OPEN",
	"1C": "OPEN",
	"2A": "OPEN",
	"2B": "OPEN",
	"3A": "OPEN",
	"3B": "OPEN",
	"4": "OPEN"
}
var selected_cam_id: String = "1"
var cam_select_buttons: Dictionary = {}
var map_node_positions: Dictionary = {}
var monster_hack_progress: float = 0.0 # 0.0 a 100.0%
var naomi_shield_charges: int = 1 # Si elegís a Naomi, te perdona 1 hackeo del monstruo
var mia_prediction_ready: bool = true # Si elegís a Mia, predice el próximo paso/código del monstruo
var guard_current_gate: int = 1
var guard_current_node_id: String = "1"

# --- AUDIO PROCEDURAL DE LA CAJA DE MÚSICA (SOLO SUENA CUANDO EL MONSTRUO ATACA) ---
var music_audio_player: AudioStreamPlayer
var music_audio_playback: AudioStreamGeneratorPlayback
var music_audio_phase: float = 0.0
var music_melody_timer: float = 0.0
var music_melody_idx: int = 0
const MUSIC_BOX_NOTES: Array[float] = [523.25, 622.25, 783.99, 739.99, 622.25, 987.77, 783.99, 622.25]

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

# --- ESTADO DE VIDA Y PULSO DE MIA (PIERDE VIDA POR CADA PUERTA QUE AVANZA EL MONSTRUO) ---
var mia_max_lives: int = 5
var mia_lives: int = 5 # 5 corazones (100% vida) -> baja 1 por cada puerta que avanza el monstruo
var mia_hp_percent: int = 100
var mia_bpm: int = 92
var mia_pulse_phase: float = 0.0
var mia_damage_flash: float = 0.0

# --- ESTADO DEL MOTOR DE NOVELA VISUAL (VN ENGINE) ---
var vn_layer: Control
var vn_active: bool = false
var vn_phase: String = "intro" # "intro" o "outro"
var vn_parsed_lines: Array[Dictionary] = []
var vn_line_index: int = 0
var vn_typing: bool = false
var vn_char_progress: float = 0.0
var vn_type_speed: float = 52.0 # Caracteres por segundo
var vn_waiting_choice: bool = false
var vn_auto_mode: bool = false
var vn_auto_timer: float = 0.0
var vn_history_entries: Array[String] = []

# Nodos UI de la Novela Visual
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

# --- ESTADO DE TAB 01: CAJA DE MÚSICA (CONTENCIÓN DE LA BESTIA) ---
var music_box_charge: float = 85.0 # 0.0 a 100.0%
var music_box_pulse_grace: float = 0.0 # Mientras > 0 estás pulsando la caja y la bestia NO se mueve
var music_box_holding: bool = false
var monster_is_moving: bool = true
var music_gear_angle: float = 0.0
var bar_music_box: ProgressBar
var bar_music_header: ProgressBar
var lbl_music_status: Label
var lbl_music_beast_state: Label
var music_box_canvas: Control
var btn_wind_music: Button

# --- ESTADO DE TAB 02: PUZZLE DESCIFRADOR DE CÓDIGO (LETRA POR LETRA, NÚMERO POR NÚMERO) ---
const CODE_LETTERS_POOL: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
const CODE_NUMBERS_POOL: String = "0123456789"
var night_secret_chars: Array[String] = ["K", "R", "X", "4", "9", "2"] # 3 Letras + 3 Números
var night_secret_code: String = "KRX-492"
var deciphered_count: int = 0 # 0..6 caracteres descifrados
var decipher_slot_labels: Array[Label] = []
var decipher_slot_panels: Array[PanelContainer] = []
var decipher_candidate_btns: Array[Button] = []
var decipher_current_candidates: Array[String] = []
var lbl_decipher_title: Label
var lbl_decipher_hint: Label
var btn_use_code_in_tab3: Button
var lbl_code_progress_status: Label
var btn_paste_deciphered_code: Button

# --- ESTADO DEL MINIJUEGO DE HACKEO (BREACH MATRIX) ---
var firewall_breached: bool = false
var hex_pool: PackedStringArray = ["1C", "55", "BD", "E9", "7A", "FF"]
var matrix_grid: Array = []
var matrix_buttons: Array = []
var target_sequence: Array[String] = []
var entered_sequence: Array[String] = []
var active_index: int = 0
var selecting_row: bool = true
var used_cells: Dictionary = {}

# --- NODOS UI CONSOLA ---
var lbl_bpm_overlay: Label
var lbl_heart_icon: Label
var lbl_agent1_header: Label
var lbl_affinity: Label
var lbl_timer: Label
var lbl_sector: Label
var lbl_codename: Label
var bar_affinity: ProgressBar
var bar_trace: ProgressBar
var rtl_chat: RichTextLabel
var portrait_rect: TextureRect
var portrait_border_style: StyleBoxFlat
var video_player: VideoStreamPlayer
var tactical_map: Control
var ecg_graph: Control

# Nodos UI del Segundo Sprite (Mia con su Corazón, Pulso y Vida que baja por cada puerta)
var mia_portrait_rect: TextureRect
var mia_portrait_border_style: StyleBoxFlat
var lbl_mia_header: Label
var lbl_mia_hearts: Label
var bar_mia_hp: ProgressBar
var lbl_mia_heart_icon: Label
var lbl_mia_bpm_overlay: Label
var mia_ecg_graph: Control

var opt_employee: OptionButton
var input_code: LineEdit
var btn_reassure: Button
var btn_inject: Button
var btn_abort: Button
var btn_quick_breach: Button
var btn_continue_vn: Button
var status_overlay: Label
var tab_container: TabContainer
var tab_doc_1: RichTextLabel
var tab_doc_2: RichTextLabel
var mission_selector: OptionButton
var game_timer: Timer

# Nodos UI del Minijuego de Hackeo y Contención
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.size_changed.connect(func(): size = get_viewport_rect().size)
	_setup_music_box_audio()
	_build_universal_ui()
	_build_vn_stage_ui()
	_build_death_jumpscare_modal()
	if enable_crt_effect:
		_create_fullscreen_crt_shader()
	size = get_viewport_rect().size

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
	radar_angle = fmod(radar_angle + delta * 1.8, TAU)
	var heart_scale = 1.0 + max(0.0, sin(pulse_phase)) * 0.24
	lbl_heart_icon.scale = Vector2(heart_scale, heart_scale)

	# Pulso y latido del corazón de Mia (se acelera a medida que pierde vida por cada puerta que avanza el monstruo)
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
	if is_instance_valid(ecg_graph):
		ecg_graph.queue_redraw()
	if is_instance_valid(mia_ecg_graph):
		mia_ecg_graph.queue_redraw()
	if is_instance_valid(death_modal) and death_modal.visible and is_instance_valid(death_art_canvas):
		death_art_canvas.queue_redraw()

	# Caja de Música (Tab 01) y Ataques Intermitentes del Monstruo al estilo FNaF
	if game_active and not vn_active:
		if not monster_attack_active:
			# FASE SILENCIOSA / ACECHO INTERMITENTE: La música NO suena y el monstruo espera en la última puerta donde quedó
			monster_is_moving = false
			monster_hack_progress = 0.0
			music_box_charge = 100.0
			music_box_pulse_grace = 0.0
			monster_cooldown_timer -= delta
			_update_music_box_ui()
			if is_instance_valid(music_box_canvas):
				music_box_canvas.queue_redraw()
			if is_instance_valid(bar_monster_hack):
				bar_monster_hack.value = 0.0
			if is_instance_valid(lbl_monster_status):
				lbl_monster_status.text = "👁️ %s [DORMANT // NO ACTIVE ATTACK] LAST AT DOOR [%s]  |  🔇 MUSIC: STANDBY  |  🔐 CODE: %d/6  |  DEFENDED: %d/%d" % [
					current_mission.monster_name,
					monster_last_node_id,
					deciphered_count,
					gates_closed_by_guard,
					TOTAL_DEFENSES_REQUIRED
				]
				lbl_monster_status.modulate = Color("#00f0ff")
			_update_3d_previz(delta)
			if monster_cooldown_timer <= 0.0:
				_start_monster_attack_wave()
		else:
			# FASE DE ATAQUE ACTIVO: La música comienza a sonar y tenés que pulsar [01_MUSIC], descifrar y cerrar la puerta
			if music_box_holding:
				music_box_charge = min(100.0, music_box_charge + delta * 48.0)
				music_box_pulse_grace = 0.75
			else:
				music_box_pulse_grace = max(0.0, music_box_pulse_grace - delta)

			if music_box_pulse_grace > 0.0 and music_box_charge > 0.0:
				# Mientras estás apretando/pulsando la Caja de Música durante el ataque, la bestia se detiene
				monster_is_moving = false
				music_gear_angle = fmod(music_gear_angle + delta * 4.5, TAU)
				monster_hack_progress = max(0.0, monster_hack_progress - delta * 3.0)
			else:
				# En cuanto dejas de pulsar la Caja de Música durante el ataque, la barra baja y la bestia avanza
				monster_is_moving = true
				music_box_charge = max(0.0, music_box_charge - delta * 10.5)
				if music_box_charge > 0.0:
					music_gear_angle = fmod(music_gear_angle + delta * 1.2, TAU)
				var base_move_speed = 3.2 + float(monster_security_level) * 0.45
				if music_box_charge <= 0.0:
					base_move_speed = 10.5 + float(monster_security_level) * 0.85
				elif music_box_charge < 35.0:
					base_move_speed = 6.2 + float(monster_security_level) * 0.65
				monster_hack_progress = min(100.0, monster_hack_progress + delta * base_move_speed)

			_fill_music_box_audio_buffer(delta)
			_update_music_box_ui()
			if is_instance_valid(music_box_canvas):
				music_box_canvas.queue_redraw()
			if is_instance_valid(bar_monster_hack):
				bar_monster_hack.value = monster_hack_progress
			if is_instance_valid(lbl_monster_status):
				var move_state_txt = "🎵 HELD BY MUSIC" if not monster_is_moving else ("🚨 SPRINTING" if music_box_charge <= 0.0 else "⚠️ ATTACKING")
				var cur_node_txt = _get_monster_node_id() if (monster_spotted_on_cam or monster_security_level >= TOTAL_SECURITY_LEVELS) else (_stage_doors_text(monster_security_level) + "?")
				lbl_monster_status.text = "☣️ %s [%s] AT CAM %s: %d%%  |  🔊 MUSIC PLAYING: %d%%  |  🔐 CODE: %d/6  |  DEFENDED: %d/%d" % [
					current_mission.monster_name,
					move_state_txt,
					cur_node_txt,
					int(monster_hack_progress),
					int(music_box_charge),
					deciphered_count,
					gates_closed_by_guard,
					TOTAL_DEFENSES_REQUIRED
				]
				lbl_monster_status.modulate = Color("#00ff9d") if not monster_is_moving else Color("#ff4466")
			_update_3d_previz(delta)
			if monster_hack_progress >= 100.0:
				_on_monster_completed_hack("Subject-Zero reached 100%% advance at Door [%s] while attacking!" % _get_monster_node_id())
	else:
		_update_3d_previz(delta)

	# Procesamiento de máquina de escribir (Typewriter) en modo Novela Visual
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
# 1. CARGADOR DE MISIÓN Y FLUJO NOVELA VISUAL <-> HACKEO
# =========================================================
func load_mission(data: MissionData, launch_vn_intro: bool = false) -> void:
	current_mission = data
	bpm = data.initial_bpm
	max_bpm = data.max_bpm
	affinity = data.initial_affinity
	time_left = data.mission_time_seconds
	reassure_used = false
	firewall_breached = not data.require_firewall_breach
	btn_continue_vn.visible = false
	if is_instance_valid(death_modal):
		death_modal.visible = false

	# Resetear estado de las 4 etapas FNaF (1 - 2 - 2 - 1), ataques intermitentes y ventajas de Mia / Naomi
	monster_security_level = 1
	monster_branch = _random_branch_for_level(1)
	monster_spotted_on_cam = false
	monster_attack_active = false
	monster_cooldown_timer = randf_range(4.2, 6.8)
	monster_last_node_id = _get_monster_node_id()
	monster_advance_on_next_wave = false
	gates_closed_by_guard = 0
	guard_current_gate = 1
	guard_current_node_id = "1"
	monster_hack_progress = 0.0
	gate_states = ["OPEN", "OPEN", "OPEN", "OPEN", "OPEN"]
	door_node_states = {
		"1": "OPEN",
		"1B": "OPEN",
		"1C": "OPEN",
		"2A": "OPEN",
		"2B": "OPEN",
		"3A": "OPEN",
		"3B": "OPEN",
		"4": "OPEN"
	}
	selected_cam_id = "1"
	naomi_shield_charges = 1 if data.companion_perk == "forgive_hack" else 0
	mia_prediction_ready = (data.companion_perk == "prediction")

	# Resetear vida y pulso de Mia (5 corazones)
	mia_max_lives = 5
	mia_lives = 5
	mia_hp_percent = 100
	mia_bpm = 92
	mia_damage_flash = 0.0
	if is_instance_valid(mia_portrait_rect):
		mia_portrait_rect.modulate = Color(1, 1, 1, 1)

	# Cargar retratos del tablero para Naomi (Izquierda) y Mia (Derecha)
	var naomi_board_tex: Texture2D = _load_board_texture("res://assets/sprites/naomi_board.jpg")
	var mia_board_tex: Texture2D = _load_board_texture("res://assets/sprites/mia_board.jpg")

	# Fallback a spritesheet si alguna textura no estuviera disponible
	var sheet_tex_found: Texture2D = null
	var names_to_try = [data.agent_name.to_lower(), "mia", "maria", "naomi"]
	for n_try in names_to_try:
		for ext in ["png", "jpg", "jpeg", "webp"]:
			var candidate = "res://assets/sprites/%s_sheet.%s" % [n_try, ext]
			if ResourceLoader.exists(candidate):
				sheet_tex_found = load(candidate)
				break
		if is_instance_valid(sheet_tex_found):
			break

	if is_instance_valid(sheet_tex_found):
		var sw = sheet_tex_found.get_width()
		var sh = sheet_tex_found.get_height()
		if not is_instance_valid(naomi_board_tex):
			var atlas1 = AtlasTexture.new()
			atlas1.atlas = sheet_tex_found
			atlas1.region = Rect2(sw * 0.04, 0.0, sw * 0.42, sh * 0.72)
			naomi_board_tex = atlas1
		if not is_instance_valid(mia_board_tex):
			var atlas_mia = AtlasTexture.new()
			atlas_mia.atlas = sheet_tex_found
			atlas_mia.region = Rect2(sw * 0.54, 0.0, sw * 0.42, sh * 0.72)
			mia_board_tex = atlas_mia

	if not is_instance_valid(data.agent_portrait):
		data.agent_portrait = naomi_board_tex if data.agent_name.to_lower() == "naomi" else mia_board_tex

	portrait_rect.texture = naomi_board_tex if is_instance_valid(naomi_board_tex) else data.agent_portrait
	if is_instance_valid(mia_portrait_rect):
		mia_portrait_rect.texture = mia_board_tex
	vn_portrait_rect.texture = data.agent_portrait
	vn_bg_rect.texture = data.vn_background
	if is_instance_valid(lbl_agent1_header):
		var p1_label = "NAOMI [AEGIS-02]" if data.agent_name.to_lower() == "naomi" else "%s [%s]" % [data.security_guard_name.to_upper(), data.security_guard_codename]
		lbl_agent1_header.text = "🛡️ " + p1_label
	_update_mia_vitals_ui()

	if data.seedance_video != "" and ResourceLoader.exists(data.seedance_video):
		var stream = load(data.seedance_video)
		video_player.stream = stream
		video_player.visible = true
		video_player.play()
		vn_video_player.stream = stream
		vn_video_player.visible = true
		vn_video_player.play()
	else:
		video_player.stop()
		video_player.visible = false
		vn_video_player.stop()
		vn_video_player.visible = false

	status_overlay.text = "● %s // GUARD: %s // 3-2-2-1 CAMERAS" % [
		data.agent_name.to_upper(),
		data.security_guard_name.to_upper()
	]
	status_overlay.modulate = Color("#00ff9d")
	lbl_sector.text = "3-2-2-1 CONTAINMENT // GUARD: " + data.security_guard_name.to_upper()
	lbl_codename.text = "🔮 MIA PREDICTION" if data.companion_perk == "prediction" else "🛡️ NAOMI 1-HACK SHIELD"
	lbl_codename.modulate = data.agent_color

	# Aplicar color identitario
	lbl_bpm_overlay.modulate = data.agent_color
	portrait_border_style.border_color = Color(data.agent_color.r, data.agent_color.g, data.agent_color.b, 0.75)
	vn_portrait_style.border_color = data.agent_color
	_apply_styled_button(btn_reassure, data.agent_color, true)
	tactical_map.queue_redraw()

	# Títulos simplificados de las 3 pestañas
	tab_container.set_tab_title(0, "🎵 01_MUSIC")
	tab_container.set_tab_title(1, "🔐 02_CODE")
	tab_container.set_tab_title(2, "⚡ 03_HACK")
	tab_container.current_tab = 0

	music_box_charge = 100.0
	music_box_pulse_grace = 0.0
	music_box_holding = false
	monster_is_moving = false
	_generate_night_secret_code(false)
	_update_music_box_ui()

	opt_employee.clear()
	opt_employee.add_item("-- Select Gate Lock Authority --", 0)
	for i in range(data.suspects_list.size()):
		opt_employee.add_item(data.suspects_list[i], i + 1)
	opt_employee.select(data.correct_suspect_index + 1)

	input_code.text = ""
	input_code.placeholder_text = "Code from [02_CODE]..."
	btn_reassure.disabled = false
	btn_reassure.text = "♥ COMFORT (+20 BOND)"
	btn_abort.text = "💖 OVERCHARGE SHIELD"

	bar_trace.max_value = data.mission_time_seconds
	bar_trace.value = data.mission_time_seconds

	rtl_chat.clear()
	_log_chat("SYSTEM", "3-2-2-1 Security Grid online. Subject-Zero attacks intermittently—the Music Box stays silent until an attack begins!", "#00f0ff")
	_log_chat(data.agent_name.to_upper(), "«Wait for the Music Box to start when it attacks! Then pulse [01_MUSIC], solve [02_CODE] + [03_HACK], and seal the door!»", "#" + data.agent_color.to_html(false))

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

func _setup_music_box_audio() -> void:
	music_audio_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.12
	music_audio_player.stream = gen
	music_audio_player.volume_db = -14.0
	add_child(music_audio_player)
	music_audio_player.play()
	music_audio_playback = music_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _fill_music_box_audio_buffer(delta: float) -> void:
	if not is_instance_valid(music_audio_player):
		return
	if not music_audio_player.playing:
		music_audio_player.play()
		music_audio_playback = music_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if music_audio_playback == null:
		return

	var note_dur = 0.28 if not monster_is_moving else (0.14 if music_box_charge <= 0.0 else 0.21)
	music_melody_timer += delta
	if music_melody_timer >= note_dur:
		music_melody_timer = fmod(music_melody_timer, note_dur)
		music_melody_idx = (music_melody_idx + 1) % MUSIC_BOX_NOTES.size()

	var freq: float = MUSIC_BOX_NOTES[music_melody_idx]
	if music_box_charge <= 0.0:
		freq *= 0.75 # Tono de alarma grave cuando la caja de música se vacía

	var frames_avail: int = music_audio_playback.get_frames_available()
	var mix_rate: float = 22050.0
	var env_decay: float = clampf(1.0 - (music_melody_timer / max(0.05, note_dur)) * 0.72, 0.15, 1.0)
	var inc: float = freq / mix_rate
	for _i in range(frames_avail):
		var sample: float = (sin(music_audio_phase * TAU) * 0.7 + sin(music_audio_phase * TAU * 2.0) * 0.3) * 0.18 * env_decay
		music_audio_playback.push_frame(Vector2(sample, sample))
		music_audio_phase = fmod(music_audio_phase + inc, 1.0)

func _start_monster_attack_wave() -> void:
	if not game_active or not is_instance_valid(current_mission):
		return
	var origin_node = monster_last_node_id
	if monster_advance_on_next_wave:
		monster_advance_on_next_wave = false
		if monster_security_level < TOTAL_SECURITY_LEVELS:
			monster_security_level += 1
			monster_branch = _random_branch_for_level(monster_security_level)

	var target_node = _get_monster_node_id()
	door_node_states[target_node] = "OPEN"
	monster_attack_active = true
	monster_hack_progress = 0.0
	music_box_charge = 82.0
	music_box_pulse_grace = 1.35
	monster_is_moving = false
	music_melody_timer = 0.0
	music_melody_idx = 0
	monster_spotted_on_cam = (monster_security_level >= TOTAL_SECURITY_LEVELS) or (selected_cam_id == target_node)

	var branch_msg = ""
	var is_first_attack = (gates_closed_by_guard == 0 and mia_lives == mia_max_lives)
	if is_first_attack and _is_branching_level(monster_security_level):
		branch_msg = " Check CAMS [%s] to find which corridor it's in!" % _stage_doors_text(monster_security_level)
	elif origin_node == target_node:
		branch_msg = " It is attacking Door [%s] again!" % target_node
	elif _is_branching_level(monster_security_level):
		branch_msg = " Check CAMS [%s] to see which branch it took!" % _stage_doors_text(monster_security_level)
	else:
		branch_msg = " Moving from Door [%s] -> Door [%s]!" % [origin_node, target_node]

	_log_chat("ATTACK_ALERT", "🚨 [MUSIC BOX STARTED — BEAST ATTACKING!]: Subject-Zero launched an attack from Door [%s]!%s Pulse [01_MUSIC] and seal the door!" % [
		origin_node,
		branch_msg
	], "#ff4466")

	_update_music_box_ui()
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

	# Fondo oscuro + grilla holográfica animada
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

	# --- BARRA SUPERIOR DE LA NOVELA VISUAL ---
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

	# --- ESCENARIO CENTRAL (RETRATO GRANDE DEL PERSONAJE + OPCIONES DE DECISIÓN) ---
	var stage_center = HBoxContainer.new()
	stage_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_center.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_center.add_theme_constant_override("separation", 28)
	main_vbox.add_child(stage_center)

	# Marco de Retrato / Video Holográfico del Personaje
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

	# Panel de Elecciones de Diálogo (aparece cuando hay un CHOICE en el guion)
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

	# --- CAJA DE DIÁLOGO INFERIOR ESTILO NOVELA VISUAL ---
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

	# --- MODAL DE HISTORIAL DE DIÁLOGOS (LOG) ---
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
			var spk = parts[0].strip_edges()
			var txt = parts[1].strip_edges()
			result.append({
				"type": "line",
				"speaker": spk,
				"text": txt
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

	# Configurar color y badge del hablante
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

	# Registrar en el historial de la novela visual
	var log_line = "[color=#%s][b][%s]:[/b][/color] %s\n\n" % [spk_col.to_html(false), spk_upper, text]
	vn_history_entries.append(log_line)
	vn_log_rtl.append_text(log_line)

func _on_vn_advance_pressed() -> void:
	if not vn_active or vn_waiting_choice:
		return
	if vn_typing:
		# Completar línea instantáneamente si todavía se está escribiendo
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

	# Insertar la respuesta inmediata del agente después de la elección
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
		# Transición de la Novela Visual -> Iniciar Consola de Hackeo en tiempo real
		game_active = true
		game_timer.start()
		_log_chat("SYSTEM", "⚡ TACTICAL CONSOLE MODE ACTIVE. Trace countdown initiated.", "#00f0ff")
	else:
		# Terminó el Epílogo de la misión: si hay otra misión disponible, ofrecer pasar a la siguiente
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
# 3. CONSTRUCCIÓN DE LA CONSOLA DE OPERADOR (CYBERPUNK UI)
# =========================================================
func _build_universal_ui() -> void:
	clip_contents = true
	var bg = ColorRect.new()
	bg.color = Color("#06090e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_margin = MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.clip_contents = true
	for side in ["left", "top", "right", "bottom"]:
		main_margin.add_theme_constant_override("margin_" + side, 12)
	add_child(main_margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	main_margin.add_child(main_vbox)

	# --- HEADER SUPERIOR ---
	var header = _create_cyber_panel(Color("#0c131d"), Color("#00f0ff"), 2, 8)
	main_vbox.add_child(header)
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	header.add_child(header_vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	header_vbox.add_child(header_hbox)

	var badge = _create_badge_label("ZERO // OS", Color("#06090e"), Color("#00f0ff"))
	header_hbox.add_child(badge)

	var title = Label.new()
	title.text = "5-LEVEL CONTAINMENT"
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color("#e0f7ff")
	header_hbox.add_child(title)

	lbl_sector = Label.new()
	lbl_sector.text = "CONTAINMENT: 5 SECURITY LEVELS"
	lbl_sector.modulate = Color("#6688aa")
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
	lbl_sel.text = "ROLE:"
	lbl_sel.modulate = Color("#88aacc")
	header_hbox.add_child(lbl_sel)

	mission_selector = OptionButton.new()
	mission_selector.fit_to_longest_item = false
	mission_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mission_selector.custom_minimum_size = Vector2(155, 28)
	mission_selector.item_selected.connect(func(idx): load_mission(available_missions[idx], start_in_vn_mode))
	header_hbox.add_child(mission_selector)

	var btn_restart = Button.new()
	btn_restart.text = "↻ RESTART"
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

	# Barra de Hackeo del Monstruo y Estado de los 5 Niveles de Seguridad
	var monster_hbox = HBoxContainer.new()
	monster_hbox.add_theme_constant_override("separation", 10)
	header_vbox.add_child(monster_hbox)

	lbl_monster_status = Label.new()
	lbl_monster_status.text = "☣️ SUBJECT-ZERO HACKING GATE L1: 0%  |  BREACH LEVEL: 1/5  |  GUARD GATES SEALED: 0/5"
	lbl_monster_status.add_theme_font_size_override("font_size", 12)
	lbl_monster_status.modulate = Color("#ff4466")
	lbl_monster_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_monster_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	monster_hbox.add_child(lbl_monster_status)

	bar_monster_hack = ProgressBar.new()
	bar_monster_hack.max_value = 100.0
	bar_monster_hack.custom_minimum_size = Vector2(190, 12)
	bar_monster_hack.show_percentage = false
	_style_progress_bar(bar_monster_hack, Color("#1f0910"), Color("#ff1744"))
	monster_hbox.add_child(bar_monster_hack)

	# --- SPLIT CENTRAL ---
	var split = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	main_vbox.add_child(split)

	# COLUMNA IZQUIERDA (MONITOR DE AGENTE + TELEMETRÍA + CHAT)
	var left_vbox = VBoxContainer.new()
	left_vbox.clip_contents = true
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	left_vbox.add_theme_constant_override("separation", 8)
	split.add_child(left_vbox)

	var monitor_panel = _create_cyber_panel(Color("#080d14"), Color("#1e3246"), 1, 8)
	monitor_panel.custom_minimum_size = Vector2(280, 270)
	monitor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_panel.size_flags_stretch_ratio = 1.45
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

	# --- SPRITE 1 (IZQUIERDA: NAOMI CON CRT) ---
	var portrait_frame = PanelContainer.new()
	portrait_border_style = StyleBoxFlat.new()
	portrait_border_style.bg_color = Color("#101620")
	portrait_border_style.border_color = Color("#00ff9d")
	portrait_border_style.set_border_width_all(2)
	portrait_border_style.set_corner_radius_all(4)
	portrait_frame.add_theme_stylebox_override("panel", portrait_border_style)
	portrait_frame.custom_minimum_size = Vector2(118, 0)
	portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_hbox.add_child(portrait_frame)

	var portrait_layer = Control.new()
	portrait_layer.clip_contents = true
	portrait_frame.add_child(portrait_layer)

	var placeholder_label = Label.new()
	placeholder_label.text = "[ NAOMI ]"
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_label.modulate = Color(0.6, 0.75, 0.9, 0.28)
	placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_layer.add_child(placeholder_label)

	portrait_rect = TextureRect.new()
	portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.material = _create_portrait_crt_material(Color(0.86, 1.0, 0.94, 1.0))
	portrait_layer.add_child(portrait_rect)

	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.finished.connect(func(): video_player.play())
	portrait_layer.add_child(video_player)

	var naomi_crt_overlay = _create_portrait_crt_overlay(Color(0.0, 1.0, 0.62, 1.0))
	portrait_layer.add_child(naomi_crt_overlay)

	var p1_top_bar = PanelContainer.new()
	p1_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p1_top_bar.offset_bottom = 24
	var p1_top_st = StyleBoxFlat.new()
	p1_top_st.bg_color = Color(0.03, 0.05, 0.08, 0.82)
	p1_top_st.set_content_margin_all(3)
	p1_top_bar.add_theme_stylebox_override("panel", p1_top_st)
	portrait_layer.add_child(p1_top_bar)

	lbl_agent1_header = Label.new()
	lbl_agent1_header.text = "🛡️ NAOMI"
	lbl_agent1_header.add_theme_font_size_override("font_size", 10)
	lbl_agent1_header.modulate = Color("#00ff9d")
	lbl_agent1_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_agent1_header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p1_top_bar.add_child(lbl_agent1_header)

	var bpm_backdrop = PanelContainer.new()
	bpm_backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bpm_backdrop.offset_top = -38
	var bd_style = StyleBoxFlat.new()
	bd_style.bg_color = Color(0.03, 0.05, 0.08, 0.85)
	bd_style.border_width_top = 1
	bd_style.border_color = Color(1, 1, 1, 0.12)
	bd_style.set_content_margin_all(4)
	bpm_backdrop.add_theme_stylebox_override("panel", bd_style)
	portrait_layer.add_child(bpm_backdrop)

	var bpm_hbox = HBoxContainer.new()
	bpm_hbox.add_theme_constant_override("separation", 4)
	bpm_backdrop.add_child(bpm_hbox)

	lbl_heart_icon = Label.new()
	lbl_heart_icon.text = "♥"
	lbl_heart_icon.add_theme_font_size_override("font_size", 18)
	lbl_heart_icon.modulate = Color("#00ff9d")
	lbl_heart_icon.pivot_offset = Vector2(8, 12)
	bpm_hbox.add_child(lbl_heart_icon)

	lbl_bpm_overlay = Label.new()
	lbl_bpm_overlay.text = "95 BPM"
	lbl_bpm_overlay.add_theme_font_size_override("font_size", 12)
	bpm_hbox.add_child(lbl_bpm_overlay)

	ecg_graph = Control.new()
	ecg_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ecg_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ecg_graph.draw.connect(_draw_ecg_wave)
	bpm_hbox.add_child(ecg_graph)

	# --- SPRITE 2 AL LADO: MIA CON CRT, CORAZÓN, PULSO Y VIDA ---
	var mia_portrait_frame = PanelContainer.new()
	mia_portrait_border_style = StyleBoxFlat.new()
	mia_portrait_border_style.bg_color = Color("#140d1c")
	mia_portrait_border_style.border_color = Color("#f600ff")
	mia_portrait_border_style.set_border_width_all(2)
	mia_portrait_border_style.set_corner_radius_all(4)
	mia_portrait_frame.add_theme_stylebox_override("panel", mia_portrait_border_style)
	mia_portrait_frame.custom_minimum_size = Vector2(124, 0)
	mia_portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_hbox.add_child(mia_portrait_frame)

	var mia_portrait_layer = Control.new()
	mia_portrait_layer.clip_contents = true
	mia_portrait_frame.add_child(mia_portrait_layer)

	var mia_placeholder = Label.new()
	mia_placeholder.text = "[ MIA ]"
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
	lbl_mia_header.text = "🔮 MIA"
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
	lbl_mia_bpm_overlay.text = "92 BPM"
	lbl_mia_bpm_overlay.add_theme_font_size_override("font_size", 12)
	lbl_mia_bpm_overlay.modulate = Color("#f600ff")
	mia_bpm_hbox.add_child(lbl_mia_bpm_overlay)

	mia_ecg_graph = Control.new()
	mia_ecg_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mia_ecg_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mia_ecg_graph.draw.connect(_draw_mia_ecg_wave)
	mia_bpm_hbox.add_child(mia_ecg_graph)

	# --- MONITOR PREVIZ 3D DE CÁMARA DE SEGURIDAD (PREVISUALIZA AL MONSTRUO MOVIÉNDOSE) ---
	var previz_3d_panel = _build_3d_camera_previz()
	monitor_hbox.add_child(previz_3d_panel)

	# --- MAPA INTERACTIVO 1 - 2 - 2 - 1 DE CÁMARAS Y PUERTAS ---
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

	# Barra rápida de selección de cámaras (1 - 2 - 2 - 1)
	var cam_bar_hbox = HBoxContainer.new()
	cam_bar_hbox.add_theme_constant_override("separation", 5)
	monitor_vbox.add_child(cam_bar_hbox)

	var lbl_cam_bar = Label.new()
	lbl_cam_bar.text = "🎥 3D CAMS (3-2-2-1):"
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

	# --- BARRA SIMPLIFICADA DE VÍNCULO Y HABILIDAD DE ACOMPAÑANTE ---
	var bio_panel = _create_cyber_panel(Color("#0a1018"), Color("#1c2d3f"), 1, 6)
	left_vbox.add_child(bio_panel)
	var bio_vbox = VBoxContainer.new()
	bio_vbox.add_theme_constant_override("separation", 4)
	bio_panel.add_child(bio_vbox)

	var bio_header = HBoxContainer.new()
	bio_header.add_theme_constant_override("separation", 8)
	bio_vbox.add_child(bio_header)

	lbl_affinity = Label.new()
	lbl_affinity.modulate = Color("#00f0ff")
	lbl_affinity.add_theme_font_size_override("font_size", 12)
	lbl_affinity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_affinity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bio_header.add_child(lbl_affinity)

	lbl_perk_status = Label.new()
	lbl_perk_status.text = "🔮 PERK READY"
	lbl_perk_status.add_theme_font_size_override("font_size", 12)
	lbl_perk_status.modulate = Color("#f600ff")
	lbl_perk_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bio_header.add_child(lbl_perk_status)

	bar_affinity = ProgressBar.new()
	bar_affinity.max_value = 100
	bar_affinity.custom_minimum_size = Vector2(0, 6)
	bar_affinity.show_percentage = false
	_style_progress_bar(bar_affinity, Color("#121d2b"), Color("#00f0ff"))
	bio_vbox.add_child(bar_affinity)

	var perk_hbox = HBoxContainer.new()
	perk_hbox.add_theme_constant_override("separation", 8)
	bio_vbox.add_child(perk_hbox)

	btn_companion_perk = Button.new()
	btn_companion_perk.text = "🔮 USE COMPANION PERK"
	btn_companion_perk.custom_minimum_size = Vector2(0, 30)
	btn_companion_perk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_companion_perk.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_companion_perk.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_companion_perk, Color("#f600ff"), true)
	btn_companion_perk.pressed.connect(_on_companion_perk_pressed)
	perk_hbox.add_child(btn_companion_perk)

	btn_reassure = Button.new()
	btn_reassure.custom_minimum_size = Vector2(0, 30)
	btn_reassure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reassure.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_reassure.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_reassure.pressed.connect(_on_reassure_pressed)
	perk_hbox.add_child(btn_reassure)

	# --- CHAT / LOG SIMPLIFICADO ---
	var chat_panel = _create_cyber_panel(Color("#090e16"), Color("#1e2d3d"), 1, 8)
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_panel.size_flags_stretch_ratio = 0.85
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
	btn_continue_vn.text = "🎭 VIEW EPILOGUE (VISUAL NOVEL) >>"
	btn_continue_vn.custom_minimum_size = Vector2(0, 34)
	btn_continue_vn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_continue_vn, Color("#00ff9d"), true)
	btn_continue_vn.visible = false
	btn_continue_vn.pressed.connect(_launch_outro_vn)
	chat_vbox.add_child(btn_continue_vn)

	# COLUMNA DERECHA SIMPLIFICADA (3 TABS + PANEL DE DECISIÓN DE PUERTAS 3-2-2-1)
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

	var music_tab = _build_music_box_tab()
	tab_container.add_child(music_tab)

	var decipher_tab = _build_code_decipher_tab()
	tab_container.add_child(decipher_tab)

	var hack_tab = _build_hacking_minigame_tab()
	tab_container.add_child(hack_tab)

	# PANEL SIMPLIFICADO DE CONTROL DE PUERTAS (1 - 2 - 2 - 1)
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
	lbl_term.text = "🔒 DOOR CONTROL (3-2-2-1)"
	lbl_term.modulate = Color("#00f0ff")
	lbl_term.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_term.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	term_header_hbox.add_child(lbl_term)

	lbl_code_progress_status = Label.new()
	lbl_code_progress_status.text = "CODE: [ ? ? ? - ? ? ? ] (0/6)"
	lbl_code_progress_status.modulate = Color("#ffcc00")
	lbl_code_progress_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	term_header_hbox.add_child(lbl_code_progress_status)

	lock_banner = _create_cyber_panel(Color("#1b111c"), Color("#ffaa00"), 1, 5)
	term_vbox.add_child(lock_banner)

	lbl_lock_banner = Label.new()
	lbl_lock_banner.text = "Check 3D Cams to locate Subject-Zero, decipher [02_CODE] + [03_HACK], then seal the right door!"
	lbl_lock_banner.modulate = Color("#ffcc44")
	lbl_lock_banner.add_theme_font_size_override("font_size", 12)
	lbl_lock_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_lock_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_banner.add_child(lbl_lock_banner)

	# Controles ocultos para compatibilidad interna
	opt_employee = OptionButton.new()
	opt_employee.visible = false
	term_vbox.add_child(opt_employee)

	input_code = LineEdit.new()
	input_code.visible = false
	term_vbox.add_child(input_code)

	var hbox_btns = HBoxContainer.new()
	hbox_btns.add_theme_constant_override("separation", 8)
	term_vbox.add_child(hbox_btns)

	btn_inject = Button.new()
	btn_inject.custom_minimum_size = Vector2(0, 42)
	btn_inject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_inject.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_inject.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_inject, Color("#00f0ff"), true)
	btn_inject.pressed.connect(func(): _on_seal_door_choice_pressed("A"))
	hbox_btns.add_child(btn_inject)

	btn_seal_door_b = Button.new()
	btn_seal_door_b.custom_minimum_size = Vector2(0, 42)
	btn_seal_door_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seal_door_b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_seal_door_b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_seal_door_b, Color("#00ff9d"), true)
	btn_seal_door_b.visible = false
	btn_seal_door_b.pressed.connect(func(): _on_seal_door_choice_pressed("B"))
	hbox_btns.add_child(btn_seal_door_b)

	btn_seal_door_c = Button.new()
	btn_seal_door_c.custom_minimum_size = Vector2(0, 42)
	btn_seal_door_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seal_door_c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_seal_door_c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_seal_door_c, Color("#ffcc00"), true)
	btn_seal_door_c.visible = false
	btn_seal_door_c.pressed.connect(func(): _on_seal_door_choice_pressed("C"))
	hbox_btns.add_child(btn_seal_door_c)

	btn_abort = Button.new()
	btn_abort.custom_minimum_size = Vector2(135, 42)
	btn_abort.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_abort.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_abort, Color("#ff4d94"), false)
	btn_abort.pressed.connect(_on_protect_agent)
	hbox_btns.add_child(btn_abort)

	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_second_tick)
	add_child(game_timer)

# =========================================================
# 4A. TAB 01: DISPOSITIVO DE CAJA DE MÚSICA (FRENA A LA BESTIA)
# =========================================================
func _build_music_box_tab() -> Control:
	var wrapper = _create_doc_tab_wrapper()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	wrapper.add_child(vbox)

	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var lbl_mb_title = Label.new()
	lbl_mb_title.text = "🎵 SONIC CONTAINMENT MUSIC BOX // PLAYS ONLY WHEN BEAST ATTACKS"
	lbl_mb_title.modulate = Color("#00f0ff")
	lbl_mb_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_mb_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_hbox.add_child(lbl_mb_title)

	lbl_music_status = Label.new()
	lbl_music_status.text = "🔇 STANDBY"
	lbl_music_status.modulate = Color("#00f0ff")
	top_hbox.add_child(lbl_music_status)

	var lbl_desc = Label.new()
	lbl_desc.text = "FNaF INTERMITTENT ATTACKS: The Music Box stays silent until Subject-Zero begins an attack. As soon as the music starts playing, press/hold the button below to keep the beast frozen while you decipher the code and close the door!"
	lbl_desc.modulate = Color("#99badd")
	lbl_desc.add_theme_font_size_override("font_size", 12)
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_desc)

	bar_music_box = ProgressBar.new()
	bar_music_box.max_value = 100.0
	bar_music_box.value = 100.0
	bar_music_box.custom_minimum_size = Vector2(0, 20)
	bar_music_box.show_percentage = true
	_style_progress_bar(bar_music_box, Color("#0a1420"), Color("#00ff9d"))
	vbox.add_child(bar_music_box)

	lbl_music_beast_state = Label.new()
	lbl_music_beast_state.text = "🔇 STANDBY — MUSIC WILL START WHEN SUBJECT-ZERO ATTACKS"
	lbl_music_beast_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_music_beast_state.add_theme_font_size_override("font_size", 15)
	lbl_music_beast_state.modulate = Color("#00f0ff")
	lbl_music_beast_state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(lbl_music_beast_state)

	var canvas_frame = _create_cyber_panel(Color("#060b12"), Color("#1b3248"), 1, 6)
	canvas_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(canvas_frame)

	music_box_canvas = Control.new()
	music_box_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_box_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	music_box_canvas.draw.connect(_draw_music_box_device)
	canvas_frame.add_child(music_box_canvas)

	btn_wind_music = Button.new()
	btn_wind_music.text = "🔇 STANDBY — MUSIC ONLY PLAYS WHEN BEAST ATTACKS"
	btn_wind_music.custom_minimum_size = Vector2(0, 56)
	btn_wind_music.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_wind_music.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_wind_music, Color("#00ff9d"), true)
	btn_wind_music.pressed.connect(_on_wind_music_pressed)
	btn_wind_music.button_down.connect(func():
		music_box_holding = true
		_on_wind_music_pressed()
	)
	btn_wind_music.button_up.connect(func(): music_box_holding = false)
	vbox.add_child(btn_wind_music)

	var nav_hbox = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(nav_hbox)

	var btn_to_tab2 = Button.new()
	btn_to_tab2.text = "🔐 GO DECIPHER CODE [TAB 02] >>"
	btn_to_tab2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_to_tab2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_styled_button(btn_to_tab2, Color("#00f0ff"), false)
	btn_to_tab2.pressed.connect(func(): tab_container.current_tab = 1)
	nav_hbox.add_child(btn_to_tab2)

	var btn_to_tab3 = Button.new()
	btn_to_tab3.text = "⚡ GO TO COUNTER-HACK [TAB 03] >>"
	btn_to_tab3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_to_tab3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_styled_button(btn_to_tab3, Color("#f600ff"), false)
	btn_to_tab3.pressed.connect(func(): tab_container.current_tab = 2)
	nav_hbox.add_child(btn_to_tab3)

	return wrapper

func _on_wind_music_pressed() -> void:
	if not game_active:
		return
	if not monster_attack_active:
		_update_music_box_ui()
		return
	music_box_charge = min(100.0, music_box_charge + 16.0)
	music_box_pulse_grace = 0.85
	monster_is_moving = false
	_update_music_box_ui()
	if is_instance_valid(music_box_canvas):
		music_box_canvas.queue_redraw()

func _update_music_box_ui() -> void:
	if is_instance_valid(bar_music_box):
		bar_music_box.value = music_box_charge
	if not monster_attack_active:
		if is_instance_valid(lbl_music_status):
			lbl_music_status.text = "🔇 STANDBY (SILENT)"
			lbl_music_status.modulate = Color("#00f0ff")
		if is_instance_valid(lbl_music_beast_state):
			lbl_music_beast_state.text = "🔇 MUSIC SILENT — NO ACTIVE ATTACK (BEAST LAST AT DOOR [%s])" % monster_last_node_id
			lbl_music_beast_state.modulate = Color("#00f0ff")
		if is_instance_valid(btn_wind_music):
			btn_wind_music.text = "🔇 STANDBY — MUSIC AUTO-STARTS WHEN BEAST ATTACKS"
			_apply_styled_button(btn_wind_music, Color("#00f0ff"), false)
		return

	if is_instance_valid(btn_wind_music):
		btn_wind_music.text = "🔊 PULSE / WIND MUSIC BOX (+16% MUSIC BAR — KEEP PRESSING!)"
		_apply_styled_button(btn_wind_music, Color("#00ff9d"), true)
	if is_instance_valid(lbl_music_status):
		lbl_music_status.text = "🔊 PLAYING: %d%%" % int(music_box_charge)
		lbl_music_status.modulate = Color("#00ff9d") if not monster_is_moving else Color("#ff4466")
	if is_instance_valid(lbl_music_beast_state):
		if not monster_is_moving:
			lbl_music_beast_state.text = "🎵 PULSING MUSIC BOX — SUBJECT-ZERO IS STOPPED (%d%% CHARGE)" % int(music_box_charge)
			lbl_music_beast_state.modulate = Color("#00ff9d")
		elif music_box_charge <= 0.0:
			lbl_music_beast_state.text = "🚨 MUSIC BAR EMPTY (0%) — BEAST IS SPRINTING TOWARD DOOR [%s]!" % _get_monster_node_id()
			lbl_music_beast_state.modulate = Color("#ff1744")
		else:
			lbl_music_beast_state.text = "⚠️ MUSIC PLAYING — PULSE NOW! BEAST ATTACKING (%d%% CHARGE)" % int(music_box_charge)
			lbl_music_beast_state.modulate = Color("#ffaa00")

func _draw_music_box_device() -> void:
	if not is_instance_valid(music_box_canvas):
		return
	var s = music_box_canvas.size
	if s.x < 30 or s.y < 30:
		return
	var font = ThemeDB.fallback_font
	var center = Vector2(s.x * 0.24, s.y * 0.5)
	var radius = min(s.x * 0.16, s.y * 0.36)
	var col = Color("#00f0ff") if not monster_attack_active else (Color("#00ff9d") if not monster_is_moving else (Color("#ff1744") if music_box_charge <= 0.0 else Color("#ffaa00")))

	# Rueda / Engranaje de la Caja de Música
	music_box_canvas.draw_circle(center, radius, Color(col.r, col.g, col.b, 0.12))
	music_box_canvas.draw_arc(center, radius, 0, TAU, 32, col, 2.5)
	music_box_canvas.draw_arc(center, radius * 0.55, 0, TAU, 24, col, 1.5)
	for i in range(8):
		var ang = music_gear_angle + float(i) * (TAU / 8.0)
		var p1 = center + Vector2(cos(ang), sin(ang)) * (radius * 0.55)
		var p2 = center + Vector2(cos(ang), sin(ang)) * (radius * 1.12)
		music_box_canvas.draw_line(p1, p2, col, 3.0)

	# Ondas sonoras de contención a la derecha
	var wave_start_x = s.x * 0.46
	var wave_end_x = s.x * 0.94
	var mid_y = s.y * 0.5
	var pts = PackedVector2Array()
	var steps = 48
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var wx = lerpf(wave_start_x, wave_end_x, t)
		var amp = 0.0
		if monster_attack_active:
			amp = (s.y * 0.32 * (music_box_charge / 100.0)) if not monster_is_moving else (s.y * 0.12 * max(0.2, music_box_charge / 100.0))
		var wy = mid_y + sin(t * 18.0 - music_gear_angle * 4.0) * amp
		pts.append(Vector2(wx, wy))
	music_box_canvas.draw_polyline(pts, col, 2.2)

	var state_str = "STANDBY — SILENT UNTIL MONSTER ATTACKS" if not monster_attack_active else ("LULLABY FREQUENCY LOCKED — BEAST FROZEN" if not monster_is_moving else "MUSIC PLAYING — PULSE TO STOP THE ATTACK!")
	music_box_canvas.draw_string(font, Vector2(wave_start_x, 20), state_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

# =========================================================
# 4B. TAB 02: PUZZLE DESCIFRADOR DE CÓDIGO (LETRA POR LETRA, NÚMERO POR NÚMERO)
# =========================================================
func _build_code_decipher_tab() -> Control:
	var wrapper = _create_doc_tab_wrapper()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	wrapper.add_child(vbox)

	lbl_decipher_title = Label.new()
	lbl_decipher_title.text = "🔐 NIGHT CODE DECIPHER PUZZLE // UNLOCK LETTER BY LETTER & NUMBER BY NUMBER"
	lbl_decipher_title.modulate = Color("#00f0ff")
	lbl_decipher_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(lbl_decipher_title)

	var slots_panel = _create_cyber_panel(Color("#070c14"), Color("#1e3448"), 1, 10)
	vbox.add_child(slots_panel)

	var slots_hbox = HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 6)
	slots_panel.add_child(slots_hbox)

	decipher_slot_labels.clear()
	decipher_slot_panels.clear()
	for i in range(6):
		if i == 3:
			var dash_lbl = Label.new()
			dash_lbl.text = "—"
			dash_lbl.add_theme_font_size_override("font_size", 22)
			dash_lbl.modulate = Color("#5588aa")
			slots_hbox.add_child(dash_lbl)

		var slot_box = _create_cyber_panel(Color("#0c1624"), Color("#00f0ff"), 2, 6)
		slot_box.custom_minimum_size = Vector2(46, 50)
		slots_hbox.add_child(slot_box)
		decipher_slot_panels.append(slot_box)

		var sl_vbox = VBoxContainer.new()
		sl_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_box.add_child(sl_vbox)

		var type_tag = Label.new()
		type_tag.text = ("LTR %d" % (i + 1)) if i < 3 else ("NUM %d" % (i - 2))
		type_tag.add_theme_font_size_override("font_size", 9)
		type_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_tag.modulate = Color("#6688aa")
		sl_vbox.add_child(type_tag)

		var char_lbl = Label.new()
		char_lbl.text = "?"
		char_lbl.add_theme_font_size_override("font_size", 20)
		char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		char_lbl.modulate = Color("#ffcc00")
		sl_vbox.add_child(char_lbl)
		decipher_slot_labels.append(char_lbl)

	lbl_decipher_hint = Label.new()
	lbl_decipher_hint.text = "Select the matching Letter or Number frequency below to decipher each slot of tonight's code:"
	lbl_decipher_hint.modulate = Color("#00ff9d")
	lbl_decipher_hint.add_theme_font_size_override("font_size", 13)
	lbl_decipher_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_decipher_hint)

	var center_cand = CenterContainer.new()
	center_cand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center_cand)

	var cand_grid = GridContainer.new()
	cand_grid.columns = 4
	cand_grid.add_theme_constant_override("h_separation", 8)
	cand_grid.add_theme_constant_override("v_separation", 8)
	center_cand.add_child(cand_grid)

	decipher_candidate_btns.clear()
	for i in range(8):
		var cbtn = Button.new()
		cbtn.custom_minimum_size = Vector2(78, 44)
		cbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cbtn.pressed.connect(_on_decipher_candidate_pressed.bind(i))
		cand_grid.add_child(cbtn)
		decipher_candidate_btns.append(cbtn)

	btn_use_code_in_tab3 = Button.new()
	btn_use_code_in_tab3.text = "🔓 CODE DECIPHERED! CLICK TO SEND TO TAB 03 & USE IT >>"
	btn_use_code_in_tab3.custom_minimum_size = Vector2(0, 44)
	btn_use_code_in_tab3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_use_code_in_tab3.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_use_code_in_tab3, Color("#00ff9d"), true)
	btn_use_code_in_tab3.visible = false
	btn_use_code_in_tab3.pressed.connect(func():
		input_code.text = night_secret_code
		tab_container.current_tab = 2
	)
	vbox.add_child(btn_use_code_in_tab3)

	return wrapper

func _generate_night_secret_code(keep_letters_for_next_gate: bool = false) -> void:
	if not keep_letters_for_next_gate or night_secret_chars.size() != 6:
		night_secret_chars.clear()
		for i in range(3):
			var l_idx = randi() % CODE_LETTERS_POOL.length()
			night_secret_chars.append(CODE_LETTERS_POOL.substr(l_idx, 1))
		for i in range(3):
			var n_idx = randi() % CODE_NUMBERS_POOL.length()
			night_secret_chars.append(CODE_NUMBERS_POOL.substr(n_idx, 1))
		deciphered_count = 0
	else:
		# Al pasar a la siguiente puerta, mantiene las 3 letras y rota los últimos 2 números para mantener tensión
		for i in range(4, 6):
			var n_idx = randi() % CODE_NUMBERS_POOL.length()
			night_secret_chars[i] = CODE_NUMBERS_POOL.substr(n_idx, 1)
		deciphered_count = 4

	night_secret_code = "%s%s%s-%s%s%s" % [
		night_secret_chars[0],
		night_secret_chars[1],
		night_secret_chars[2],
		night_secret_chars[3],
		night_secret_chars[4],
		night_secret_chars[5]
	]
	if is_instance_valid(current_mission):
		current_mission.correct_token_code = night_secret_code
	_setup_current_decipher_slot()

func _setup_current_decipher_slot() -> void:
	decipher_current_candidates.clear()
	if deciphered_count >= 6:
		_refresh_decipher_ui()
		return

	var target_char = night_secret_chars[deciphered_count]
	var is_letter_slot = (deciphered_count < 3)
	var pool = CODE_LETTERS_POOL if is_letter_slot else CODE_NUMBERS_POOL

	decipher_current_candidates.append(target_char)
	while decipher_current_candidates.size() < 8:
		var pick = pool.substr(randi() % pool.length(), 1)
		if not decipher_current_candidates.has(pick):
			decipher_current_candidates.append(pick)
	decipher_current_candidates.sort()

	var target_idx_in_cand = decipher_current_candidates.find(target_char)
	var low_bound = decipher_current_candidates[max(0, target_idx_in_cand - 1)]
	var high_bound = decipher_current_candidates[min(decipher_current_candidates.size() - 1, target_idx_in_cand + 1)]
	var kind_str = ("LETTER #%d" % (deciphered_count + 1)) if is_letter_slot else ("NUMBER #%d" % (deciphered_count - 2))
	if is_instance_valid(lbl_decipher_hint):
		lbl_decipher_hint.text = "🔍 DECIPHERING %s (SLOT %d/6)  |  SIGNAL WINDOW: Between [ %s ] and [ %s ]" % [
			kind_str,
			deciphered_count + 1,
			low_bound,
			high_bound
		]
		lbl_decipher_hint.modulate = Color("#00f0ff")

	_refresh_decipher_ui()

func _on_decipher_candidate_pressed(btn_idx: int) -> void:
	if not game_active or deciphered_count >= 6 or btn_idx >= decipher_current_candidates.size():
		return
	var picked = decipher_current_candidates[btn_idx]
	var target_char = night_secret_chars[deciphered_count]

	if picked == target_char:
		deciphered_count += 1
		monster_hack_progress = max(0.0, monster_hack_progress - 8.0)
		if deciphered_count >= 6:
			input_code.text = night_secret_code
			_log_chat("CODE_DECIPHERED", "🔓 Night Code [ %s ] fully deciphered! It has been loaded into Tab 03—complete the Matrix and seal the Gate!" % night_secret_code, "#00ff9d")
			_refresh_decipher_ui()
		else:
			_setup_current_decipher_slot()
		_update_companion_perk_ui()
		_update_terminal_lock_state()
	else:
		# Pista Mayor / Menor para ayudar a descifrar letra por letra / número por número
		var dir_hint = ("AFTER [%s]" % picked) if picked < target_char else ("BEFORE [%s]" % picked)
		if is_instance_valid(lbl_decipher_hint):
			lbl_decipher_hint.text = "⚠️ WRONG FREQUENCY [%s]! Signal is %s! (+7%% Beast Advance)" % [picked, dir_hint]
			lbl_decipher_hint.modulate = Color("#ffaa00")
		decipher_candidate_btns[btn_idx].disabled = true
		monster_hack_progress = min(100.0, monster_hack_progress + 7.0)

func _refresh_decipher_ui() -> void:
	var is_mia = is_instance_valid(current_mission) and current_mission.companion_perk == "prediction"
	var partial_str = ""
	for i in range(6):
		if i == 3:
			partial_str += "-"
		var is_unlocked = (i < deciphered_count)
		var ch = night_secret_chars[i] if is_unlocked else "?"
		partial_str += ch
		if i < decipher_slot_labels.size() and is_instance_valid(decipher_slot_labels[i]):
			decipher_slot_labels[i].text = ch
			if is_unlocked:
				decipher_slot_labels[i].modulate = Color("#00ff9d")
			elif i == deciphered_count:
				decipher_slot_labels[i].modulate = Color("#00f0ff")
			else:
				decipher_slot_labels[i].modulate = Color("#667788")

	if is_instance_valid(lbl_code_progress_status):
		if deciphered_count >= 6:
			lbl_code_progress_status.text = "CODE: [ %s ] ✓" % night_secret_code
			lbl_code_progress_status.modulate = Color("#00ff9d")
		else:
			lbl_code_progress_status.text = "CODE: [ %s ] (%d/6)" % [partial_str, deciphered_count]
			lbl_code_progress_status.modulate = Color("#ffcc00")

	if is_instance_valid(btn_use_code_in_tab3):
		btn_use_code_in_tab3.visible = (deciphered_count >= 6)
		btn_use_code_in_tab3.text = "🔓 CODE [ %s ] READY! GO TO [03_HACK] >>" % night_secret_code

	if is_instance_valid(lbl_decipher_hint) and deciphered_count >= 6:
		lbl_decipher_hint.text = "✓ CODE [ %s ] READY! Complete [03_HACK] and choose the right door to seal!" % night_secret_code
		lbl_decipher_hint.modulate = Color("#00ff9d")

	var target_char = night_secret_chars[deciphered_count] if deciphered_count < 6 else ""
	for i in range(decipher_candidate_btns.size()):
		var btn: Button = decipher_candidate_btns[i]
		if deciphered_count >= 6 or i >= decipher_current_candidates.size():
			btn.text = "✓"
			btn.disabled = true
			_style_matrix_cell(btn, Color("#0a291e"), Color("#00ff9d"), Color("#00ff9d"))
		else:
			var cand = decipher_current_candidates[i]
			var is_mia_hint = is_mia and (cand == target_char)
			btn.text = ("🔮 " + cand) if is_mia_hint else cand
			btn.disabled = false
			if is_mia_hint:
				_style_matrix_cell(btn, Color("#2e1038"), Color("#f600ff"), Color("#ffffff"))
			else:
				_style_matrix_cell(btn, Color("#112638"), Color("#00f0ff"), Color("#ffffff"))

# =========================================================
# 4C. TAB 03: MINIJUEGO DE HACKEO: BREACH MATRIX (SECUENCIA HEXADECIMAL)
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
	lbl_breach_status.text = "⚡ ICE INTRUSION PROTOCOL // HEXADECIMAL MATRIX"
	lbl_breach_status.modulate = Color("#00f0ff")
	lbl_breach_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_breach_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_bar.add_child(lbl_breach_status)

	btn_reset_matrix = Button.new()
	btn_reset_matrix.text = "↻ REGENERATE MATRIX"
	_apply_styled_button(btn_reset_matrix, Color("#00f0ff"), false)
	btn_reset_matrix.pressed.connect(_on_manual_reset_matrix)
	top_bar.add_child(btn_reset_matrix)

	lbl_breach_hint = Label.new()
	lbl_breach_hint.text = "INSTRUCTION: Replicate the TARGET SEQUENCE by alternating selection between highlighted ROW → highlighted COLUMN."
	lbl_breach_hint.modulate = Color("#88aacc")
	lbl_breach_hint.add_theme_font_size_override("font_size", 13)
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

	for step in range(seq_len):
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
	if not game_active or firewall_breached:
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
		monster_hack_progress = max(0.0, monster_hack_progress - 12.0)
		if selecting_row:
			active_index = c
		else:
			active_index = r
		selecting_row = not selecting_row

		if entered_sequence.size() >= target_sequence.size():
			firewall_breached = true
			bpm = max(70, bpm - 10)
			monster_hack_progress = max(0.0, monster_hack_progress - 35.0)
			var door_hint = ("Check CAMS [%s] and choose which door to seal below!" % _stage_doors_text(monster_security_level)) if _is_branching_level(monster_security_level) else ("Click [🔒 SEAL DOOR %d] below!" % monster_security_level)
			_log_chat("HACK_OK", "✓ Counter-Hack complete! %s" % door_hint, "#00ff9d")
			_update_terminal_lock_state()
			_update_hud()
		_refresh_matrix_ui()
		_update_companion_perk_ui()
	else:
		if not monster_attack_active:
			# Sin ataque activo, un error en la matriz solo reinicia la matriz (el monstruo no avanza)
			_log_chat("SYSTEM", "⚠️ Wrong Hex Cell! Matrix reset (no active attack, Subject-Zero stays at Door [%s])." % monster_last_node_id, "#ffcc00")
			_generate_breach_matrix()
			return
		_on_monster_completed_hack("Wrong Hex Cell selected in Counter-Hack Matrix!")

func _on_manual_reset_matrix() -> void:
	if not game_active or firewall_breached:
		return
	_generate_breach_matrix()

func _refresh_matrix_ui() -> void:
	var is_mia = is_instance_valid(current_mission) and current_mission.companion_perk == "prediction"
	var target_str = "[b][color=#88aacc]COUNTER-HACK SEQUENCE (STAGE %d/4):[/color][/b]\n" % clampi(monster_security_level, 1, TOTAL_SECURITY_LEVELS)
	for i in range(target_sequence.size()):
		if i < entered_sequence.size():
			target_str += "[b][color=#00ff9d][ %s ][/color][/b] " % target_sequence[i]
		elif i == entered_sequence.size() and not firewall_breached:
			target_str += "[b][color=#f600ff][ 🔮%s ][/color][/b] " % target_sequence[i] if is_mia else "[b][color=#00f0ff][ %s ][/color][/b] " % target_sequence[i]
		else:
			target_str += "[color=#667788][ %s ][/color] " % target_sequence[i]
	lbl_target_seq.text = target_str

	var buf_str = "[b][color=#88aacc]GATE LOCK BUFFER:[/color][/b]\n"
	if firewall_breached:
		buf_str += "[b][color=#00ff9d]✓ JAMMING CLEARED — READY FOR GUARD TO CLOSE GATE![/color][/b]"
		lbl_breach_status.text = "✓ COUNTER-HACK COMPLETE // ORDER GUARD TO SEAL GATE BELOW"
		lbl_breach_status.modulate = Color("#00ff9d")
	else:
		for t in entered_sequence:
			buf_str += "[b][color=#00ff9d]%s[/color][/b]  " % t
		for _i in range(target_sequence.size() - entered_sequence.size()):
			buf_str += "[color=#445566]__[/color]  "
		var mode_txt = ("ROW %d" % (active_index + 1)) if selecting_row else ("COLUMN %d" % (active_index + 1))
		lbl_breach_status.text = "⚡ SELECT IN %s // STEP %d/%d (GATES SEALED: %d/5)" % [
			mode_txt,
			entered_sequence.size() + 1,
			target_sequence.size(),
			gates_closed_by_guard
		]
		lbl_breach_status.modulate = Color("#00f0ff")
	lbl_buffer_seq.text = buf_str

	var next_expected = target_sequence[entered_sequence.size()] if entered_sequence.size() < target_sequence.size() else ""
	for r in range(5):
		for c in range(5):
			var btn: Button = matrix_buttons[r][c]
			var cell_key = Vector2i(r, c)
			var is_used = used_cells.has(cell_key)
			var is_selectable = (not firewall_breached) and (not is_used) and ((selecting_row and r == active_index) or (not selecting_row and c == active_index))

			var cell_txt = String(matrix_grid[r][c])
			var is_predicted_match = is_selectable and (cell_txt == next_expected)
			if is_used:
				btn.text = "✓"
			elif is_mia and is_predicted_match:
				btn.text = "🔮" + cell_txt
			else:
				btn.text = cell_txt
			btn.disabled = not is_selectable

			if firewall_breached or is_used:
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

func _get_monster_node_id() -> String:
	return _node_id_for(monster_security_level, monster_branch)

# Etapa 1: 3 pasillos (C1 / C1B / C1C) | Etapas 2 y 3: 2 ramas (A / B) | Etapa 4: puerta final única
func _node_id_for(level: int, branch: String) -> String:
	if level <= 1:
		return "1" if branch == "A" else "1" + branch
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
			var col = Color("#00f0ff")
			if d_state == "LOCKED":
				col = Color("#00ff9d")
			elif d_state == "BREACHED":
				col = Color("#ff1744")
			elif is_sel:
				col = Color("#ffcc00")
			_apply_styled_button(btn, col, is_sel)

	if is_instance_valid(tactical_map):
		tactical_map.queue_redraw()
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
	env.background_color = Color("#03060c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#182b3d")
	env.ambient_light_energy = 0.95
	env_node.environment = env
	root_3d.add_child(env_node)

	previz_cam_3d = Camera3D.new()
	previz_cam_3d.position = Vector3(0.0, 1.35, 3.0)
	previz_cam_3d.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	previz_cam_3d.fov = 62.0
	root_3d.add_child(previz_cam_3d)

	previz_room_light = OmniLight3D.new()
	previz_room_light.position = Vector3(0.0, 2.3, -1.2)
	previz_room_light.light_color = Color("#55ccff")
	previz_room_light.light_energy = 1.6
	previz_room_light.omni_range = 9.5
	root_3d.add_child(previz_room_light)

	# --- CORREDOR 3D SIMPLE DE CÁMARA DE SEGURIDAD ---
	var corridor = Node3D.new()
	root_3d.add_child(corridor)

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color("#0c1522")
	wall_mat.roughness = 0.85

	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#080e17")
	floor_mat.roughness = 0.7

	var rib_mat = StandardMaterial3D.new()
	rib_mat.albedo_color = Color("#1b334b")
	rib_mat.emission_enabled = true
	rib_mat.emission = Color("#00aaff") * 0.25

	# Piso y techo
	var floor_mi = MeshInstance3D.new()
	var floor_box = BoxMesh.new()
	floor_box.size = Vector3(3.4, 0.15, 11.0)
	floor_mi.mesh = floor_box
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(0.0, 0.0, -2.2)
	corridor.add_child(floor_mi)

	var ceil_mi = MeshInstance3D.new()
	ceil_mi.mesh = floor_box
	ceil_mi.material_override = wall_mat
	ceil_mi.position = Vector3(0.0, 2.75, -2.2)
	corridor.add_child(ceil_mi)

	# Paredes laterales y pared de fondo
	var side_box = BoxMesh.new()
	side_box.size = Vector3(0.15, 2.8, 11.0)
	for side_x in [-1.65, 1.65]:
		var w_mi = MeshInstance3D.new()
		w_mi.mesh = side_box
		w_mi.material_override = wall_mat
		w_mi.position = Vector3(side_x, 1.38, -2.2)
		corridor.add_child(w_mi)

	var back_mi = MeshInstance3D.new()
	var back_box = BoxMesh.new()
	back_box.size = Vector3(3.4, 2.8, 0.2)
	back_mi.mesh = back_box
	back_mi.material_override = wall_mat
	back_mi.position = Vector3(0.0, 1.38, -7.2)
	corridor.add_child(back_mi)

	# Arcos de profundidad a lo largo del pasillo 3D
	var pillar_box = BoxMesh.new()
	pillar_box.size = Vector3(0.18, 2.7, 0.18)
	for z_pos in [-0.4, -2.1, -3.8, -5.5]:
		for px in [-1.48, 1.48]:
			var p_mi = MeshInstance3D.new()
			p_mi.mesh = pillar_box
			p_mi.material_override = rib_mat
			p_mi.position = Vector3(px, 1.35, z_pos)
			corridor.add_child(p_mi)

	# Puerta Blindada 3D (baja cuando la puerta de esa cámara está LOCKED)
	previz_door_mesh = MeshInstance3D.new()
	var door_box = BoxMesh.new()
	door_box.size = Vector3(3.1, 2.6, 0.18)
	previz_door_mesh.mesh = door_box
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color("#133a2c")
	door_mat.emission_enabled = true
	door_mat.emission = Color("#00ff9d") * 0.22
	previz_door_mesh.material_override = door_mat
	previz_door_mesh.position = Vector3(0.0, 3.85, 1.15)
	corridor.add_child(previz_door_mesh)

	# --- MONSTRUO 3D PREVIZ SIMPLE (SE MUEVE POR EL PASILLO) ---
	previz_monster_root = Node3D.new()
	previz_monster_root.position = Vector3(0.0, 0.0, -4.5)
	root_3d.add_child(previz_monster_root)

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color("#120509")
	body_mat.roughness = 0.9

	var eye_mat = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color("#ff1744")

	# Torso encorvado
	var torso_mi = MeshInstance3D.new()
	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.34
	torso_mesh.height = 1.25
	torso_mi.mesh = torso_mesh
	torso_mi.material_override = body_mat
	torso_mi.position = Vector3(0.0, 1.25, 0.0)
	previz_monster_root.add_child(torso_mi)

	# Cabeza + 2 ojos rojos brillantes
	previz_monster_head = Node3D.new()
	previz_monster_head.position = Vector3(0.0, 1.92, 0.14)
	previz_monster_root.add_child(previz_monster_head)

	var head_mi = MeshInstance3D.new()
	var head_sphere = SphereMesh.new()
	head_sphere.radius = 0.24
	head_sphere.height = 0.48
	head_mi.mesh = head_sphere
	head_mi.material_override = body_mat
	previz_monster_head.add_child(head_mi)

	var eye_sphere = SphereMesh.new()
	eye_sphere.radius = 0.055
	eye_sphere.height = 0.11
	for ex in [-0.09, 0.09]:
		var eye_mi = MeshInstance3D.new()
		eye_mi.mesh = eye_sphere
		eye_mi.material_override = eye_mat
		eye_mi.position = Vector3(ex, 0.03, 0.21)
		previz_monster_head.add_child(eye_mi)

	var monster_glow = OmniLight3D.new()
	monster_glow.light_color = Color("#ff1744")
	monster_glow.light_energy = 1.5
	monster_glow.omni_range = 3.2
	monster_glow.position = Vector3(0.0, 0.05, 0.35)
	previz_monster_head.add_child(monster_glow)

	# Brazos largos articulados
	var limb_box = BoxMesh.new()
	limb_box.size = Vector3(0.14, 0.95, 0.14)

	previz_monster_arm_l = Node3D.new()
	previz_monster_arm_l.position = Vector3(-0.42, 1.65, 0.0)
	previz_monster_root.add_child(previz_monster_arm_l)
	var arm_l_mi = MeshInstance3D.new()
	arm_l_mi.mesh = limb_box
	arm_l_mi.material_override = body_mat
	arm_l_mi.position = Vector3(0.0, -0.42, 0.08)
	previz_monster_arm_l.add_child(arm_l_mi)

	previz_monster_arm_r = Node3D.new()
	previz_monster_arm_r.position = Vector3(0.42, 1.65, 0.0)
	previz_monster_root.add_child(previz_monster_arm_r)
	var arm_r_mi = MeshInstance3D.new()
	arm_r_mi.mesh = limb_box
	arm_r_mi.material_override = body_mat
	arm_r_mi.position = Vector3(0.0, -0.42, 0.08)
	previz_monster_arm_r.add_child(arm_r_mi)

	# Piernas articuladas
	var leg_box = BoxMesh.new()
	leg_box.size = Vector3(0.16, 0.85, 0.16)

	previz_monster_leg_l = Node3D.new()
	previz_monster_leg_l.position = Vector3(-0.18, 0.78, 0.0)
	previz_monster_root.add_child(previz_monster_leg_l)
	var leg_l_mi = MeshInstance3D.new()
	leg_l_mi.mesh = leg_box
	leg_l_mi.material_override = body_mat
	leg_l_mi.position = Vector3(0.0, -0.38, 0.0)
	previz_monster_leg_l.add_child(leg_l_mi)

	previz_monster_leg_r = Node3D.new()
	previz_monster_leg_r.position = Vector3(0.18, 0.78, 0.0)
	previz_monster_root.add_child(previz_monster_leg_r)
	var leg_r_mi = MeshInstance3D.new()
	leg_r_mi.mesh = leg_box
	leg_r_mi.material_override = body_mat
	leg_r_mi.position = Vector3(0.0, -0.38, 0.0)
	previz_monster_leg_r.add_child(leg_r_mi)

	# Overlay CRT encima del Previz 3D
	var cam_crt = _create_portrait_crt_overlay(Color(0.0, 0.94, 1.0, 1.0))
	layer.add_child(cam_crt)

	# HUD superior e inferior de la cámara 3D
	var cam_top_bar = PanelContainer.new()
	cam_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cam_top_bar.offset_bottom = 24
	var ct_st = StyleBoxFlat.new()
	ct_st.bg_color = Color(0.02, 0.05, 0.09, 0.82)
	ct_st.set_content_margin_all(3)
	cam_top_bar.add_theme_stylebox_override("panel", ct_st)
	layer.add_child(cam_top_bar)

	lbl_previz_cam_title = Label.new()
	lbl_previz_cam_title.text = "🎥 3D PREVIZ // CAM 1"
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
	lbl_previz_cam_alert.text = "☣️ SUBJECT-ZERO SPOTTED"
	lbl_previz_cam_alert.add_theme_font_size_override("font_size", 10)
	lbl_previz_cam_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_previz_cam_alert.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cam_bot_bar.add_child(lbl_previz_cam_alert)

	return frame

func _update_3d_previz(delta: float) -> void:
	if not is_instance_valid(previz_monster_root) or not is_instance_valid(previz_cam_3d):
		return
	var monster_node = _get_monster_node_id() if monster_attack_active else monster_last_node_id
	# Mientras no hay ataque (música apagada) el monstruo NO aparece en ninguna cámara
	var monster_in_this_cam = monster_attack_active and (selected_cam_id == monster_node)
	previz_monster_root.visible = monster_in_this_cam
	if monster_in_this_cam:
		monster_spotted_on_cam = true

	# paneo suave de cámara de seguridad 3D
	previz_cam_3d.rotation_degrees.y = sin(pulse_phase * 0.25) * 4.0

	# Estado de la puerta 3D en esta cámara
	var d_state = door_node_states.get(selected_cam_id, "OPEN")
	if is_instance_valid(previz_door_mesh):
		var target_door_y = 1.32 if d_state == "LOCKED" else 3.85
		previz_door_mesh.position.y = lerpf(previz_door_mesh.position.y, target_door_y, clampf(delta * 8.0 if delta > 0.0 else 1.0, 0.1, 1.0))

	if monster_in_this_cam:
		if monster_attack_active and monster_is_moving and game_active:
			var walk_spd = 9.5 if music_box_charge <= 0.0 else 5.2
			previz_walk_phase = fmod(previz_walk_phase + delta * walk_spd, TAU)
		# Posición Z en el pasillo 3D según monster_hack_progress (0% = fondo -5.6, 100% = cerca de cámara +0.75)
		var t = clampf(monster_hack_progress / 100.0, 0.0, 1.0) if monster_attack_active else 0.0
		var z_pos = lerpf(-5.6, 0.75, t)
		var x_sway = (sin(previz_walk_phase) * 0.22) if (monster_attack_active and monster_is_moving) else 0.0
		var y_bob = (abs(sin(previz_walk_phase * 2.0)) * 0.12) if (monster_attack_active and monster_is_moving) else 0.0
		previz_monster_root.position = Vector3(x_sway, y_bob, z_pos)
		previz_monster_root.rotation.z = (sin(previz_walk_phase) * 0.09) if (monster_attack_active and monster_is_moving) else 0.0

		if is_instance_valid(previz_monster_arm_l) and is_instance_valid(previz_monster_arm_r):
			var arm_swing = sin(previz_walk_phase) * 0.55 if monster_attack_active else 0.0
			previz_monster_arm_l.rotation.x = -0.55 + arm_swing
			previz_monster_arm_r.rotation.x = -0.55 - arm_swing
		if is_instance_valid(previz_monster_leg_l) and is_instance_valid(previz_monster_leg_r):
			var leg_swing = sin(previz_walk_phase) * 0.5 if monster_attack_active else 0.0
			previz_monster_leg_l.rotation.x = -leg_swing
			previz_monster_leg_r.rotation.x = leg_swing
		if is_instance_valid(previz_monster_head):
			previz_monster_head.rotation.y = sin(pulse_phase * 1.7) * 0.25

		if is_instance_valid(previz_room_light):
			if not monster_attack_active:
				previz_room_light.light_color = Color("#00f0ff")
				previz_room_light.light_energy = 1.15
			else:
				previz_room_light.light_color = Color("#ff2244") if monster_is_moving else Color("#00ff9d")
				previz_room_light.light_energy = 1.4 + sin(pulse_phase * 3.0) * 0.4
	else:
		if is_instance_valid(previz_room_light):
			previz_room_light.light_color = Color("#00ff9d") if d_state == "LOCKED" else Color("#44aaff")
			previz_room_light.light_energy = 1.2

	if is_instance_valid(lbl_previz_cam_title):
		lbl_previz_cam_title.text = "🎥 3D CAM %s // DOOR: %s" % [selected_cam_id, d_state]
	if is_instance_valid(lbl_previz_cam_alert):
		if not monster_attack_active:
			lbl_previz_cam_alert.text = "🔇 NO SIGNAL — NO ACTIVE ATTACK IN CAM %s" % selected_cam_id
			lbl_previz_cam_alert.modulate = Color("#557799")
		elif monster_in_this_cam:
			if monster_is_moving:
				lbl_previz_cam_alert.text = "☣️ ATTACKING IN CAM %s (%d%%)" % [selected_cam_id, int(monster_hack_progress)]
				lbl_previz_cam_alert.modulate = Color("#ff1744")
			else:
				lbl_previz_cam_alert.text = "🎵 HELD BY MUSIC IN CAM %s (%d%%)" % [selected_cam_id, int(monster_hack_progress)]
				lbl_previz_cam_alert.modulate = Color("#00ff9d")
		else:
			lbl_previz_cam_alert.text = "CLEAR — NO MOVEMENT IN CAM %s" % selected_cam_id
			lbl_previz_cam_alert.modulate = Color("#7799bb")

func _update_terminal_lock_state() -> void:
	if not is_instance_valid(current_mission) or not is_instance_valid(btn_inject):
		return
	var guard_upper = current_mission.security_guard_name.to_upper()
	var ready_to_seal = firewall_breached and deciphered_count >= 6

	if not monster_attack_active:
		btn_inject.text = "⏳ STANDBY (LAST DOOR: C%s — WAIT FOR ATTACK)" % monster_last_node_id
		if is_instance_valid(btn_seal_door_b):
			btn_seal_door_b.visible = false
		if is_instance_valid(btn_seal_door_c):
			btn_seal_door_c.visible = false
		if ready_to_seal:
			lbl_lock_banner.text = "✓ Code & Hack Ready! Subject-Zero is dormant at Door [C%s]—wait for the Music Box & next attack!" % monster_last_node_id
			lbl_lock_banner.modulate = Color("#00f0ff")
		else:
			lbl_lock_banner.text = "🔇 No active attack (Last at Door [C%s]). You can pre-decipher [02_CODE] (%d/6) & [03_HACK] now!" % [monster_last_node_id, deciphered_count]
			lbl_lock_banner.modulate = Color("#88ccee")
		btn_inject.modulate = Color(0.75, 0.85, 0.95, 0.85)
		return

	# Un botón de sellado por cada pasillo de la etapa actual (3 en etapa 1, 2 en etapas 2-3, 1 en la final)
	var stage_branches = _branches_for_level(monster_security_level)
	var seal_btns: Array = [btn_inject, btn_seal_door_b, btn_seal_door_c]
	for i in range(seal_btns.size()):
		var sb: Button = seal_btns[i]
		if not is_instance_valid(sb):
			continue
		if i < stage_branches.size():
			sb.visible = true
			var node_label = "C" + _node_id_for(monster_security_level, stage_branches[i])
			sb.text = ("🔒 SEAL FINAL [DOOR %s]" % node_label) if monster_security_level >= TOTAL_SECURITY_LEVELS else ("🔒 SEAL [%s]" % node_label)
		else:
			sb.visible = false

	if ready_to_seal:
		if _is_branching_level(monster_security_level):
			var hint_cam = ("Detected in CAM C%s! Seal that corridor!" % _get_monster_node_id()) if monster_spotted_on_cam else ("Check CAMS [%s] to see where the monster is, then choose which door to seal!" % _stage_doors_text(monster_security_level))
			lbl_lock_banner.text = "✓ READY! %s" % hint_cam
			lbl_lock_banner.modulate = Color("#00ff9d")
		else:
			lbl_lock_banner.text = "✓ CODE [%s] & HACK READY! Click below so %s seals Door %d!" % [night_secret_code, guard_upper, monster_security_level]
			lbl_lock_banner.modulate = Color("#00ff9d")
		for sb in seal_btns:
			if is_instance_valid(sb):
				sb.modulate = Color(1, 1, 1, 1)
	else:
		if deciphered_count < 6:
			lbl_lock_banner.text = "🚨 ATTACK ACTIVE! Pulse [01_MUSIC] | Decipher [02_CODE] (%d/6) | [03_HACK] & Seal Door!" % deciphered_count
		else:
			lbl_lock_banner.text = "🚨 ATTACK ACTIVE! Code [%s] Ready—Finish [03_HACK], check 3D Cams, and seal the door!" % night_secret_code
		lbl_lock_banner.modulate = Color("#ffcc44")
		for sb in seal_btns:
			if is_instance_valid(sb):
				sb.modulate = Color(0.8, 0.88, 0.92, 0.9)

func _update_companion_perk_ui() -> void:
	if not is_instance_valid(current_mission) or not is_instance_valid(lbl_perk_status) or not is_instance_valid(btn_companion_perk):
		return
	if current_mission.companion_perk == "prediction":
		var next_cipher_ch = night_secret_chars[deciphered_count] if deciphered_count < 6 else night_secret_code
		lbl_perk_status.text = "🔮 MIA: Cam [%s] | Key [%s]" % [_get_monster_node_id(), next_cipher_ch]
		lbl_perk_status.modulate = Color("#f600ff")
		btn_companion_perk.text = "🔮 MIA: PREDICT CAM & CODE" if mia_prediction_ready else "🔮 PREDICTION USED"
		btn_companion_perk.disabled = not mia_prediction_ready
		_apply_styled_button(btn_companion_perk, Color("#f600ff"), mia_prediction_ready)
	else:
		if naomi_shield_charges > 0:
			lbl_perk_status.text = "🛡️ NAOMI: 1-HACK SHIELD READY"
			lbl_perk_status.modulate = Color("#00ff9d")
			btn_companion_perk.text = "🛡️ NAOMI: JAM BEAST (+MUSIC)"
			btn_companion_perk.disabled = false
			_apply_styled_button(btn_companion_perk, Color("#00ff9d"), true)
		else:
			lbl_perk_status.text = "🛡️ NAOMI: SHIELD USED"
			lbl_perk_status.modulate = Color("#ffcc00")
			btn_companion_perk.text = "🛡️ SHIELD CONSUMED"
			btn_companion_perk.disabled = true
			_apply_styled_button(btn_companion_perk, Color("#667788"), false)

func _on_companion_perk_pressed() -> void:
	if not game_active or not is_instance_valid(current_mission):
		return
	if current_mission.companion_perk == "prediction":
		if not mia_prediction_ready:
			return
		mia_prediction_ready = false
		monster_spotted_on_cam = true
		_select_camera(_get_monster_node_id())
		music_box_charge = min(100.0, music_box_charge + 25.0)
		music_box_pulse_grace = 1.2
		monster_hack_progress = max(0.0, monster_hack_progress - 20.0)
		if deciphered_count < 6:
			var target_ch = night_secret_chars[deciphered_count]
			var c_idx = decipher_current_candidates.find(target_ch)
			if c_idx >= 0:
				_on_decipher_candidate_pressed(c_idx)
		if not firewall_breached and entered_sequence.size() < target_sequence.size():
			var expected_token: String = target_sequence[entered_sequence.size()]
			for idx in range(5):
				var rr = active_index if selecting_row else idx
				var cc = idx if selecting_row else active_index
				if not used_cells.has(Vector2i(rr, cc)) and matrix_grid[rr][cc] == expected_token:
					_on_matrix_cell_pressed(rr, cc)
					break
		_log_chat("MIA_PERK", "🔮 [MIA]: «Subject-Zero is on Camera [%s]! I switched your 3D Cam there and solved the next step!»" % _get_monster_node_id(), "#f600ff")
		_update_companion_perk_ui()
	else:
		if naomi_shield_charges <= 0:
			return
		music_box_charge = min(100.0, music_box_charge + 35.0)
		music_box_pulse_grace = 1.4
		monster_hack_progress = max(0.0, monster_hack_progress - 30.0)
		bpm = max(75, bpm - 12)
		_log_chat("NAOMI_PERK", "🛡️ [NAOMI]: «Wound Music Box +35% and pushed Subject-Zero back! My shield still forgives 1 breach!»", "#00ff9d")
		_update_hud()

# =========================================================
# 5. DIBUJO DEL MAPA FNAF 1 - 2 - 2 - 1 (CÁMARAS Y PUERTAS) Y ECG
# =========================================================
func _draw_ecg_wave() -> void:
	var s = ecg_graph.size
	if s.x <= 10 or s.y <= 10:
		return
	var mid_y = s.y * 0.55
	var col = current_mission.agent_color if is_instance_valid(current_mission) else Color("#00f0ff")

	ecg_graph.draw_line(Vector2(0, mid_y), Vector2(s.x, mid_y), Color(col.r, col.g, col.b, 0.2), 1.0)

	var pts = PackedVector2Array()
	var steps = 42
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var x = t * s.x
		var phase = fmod(t * 2.5 - (pulse_phase / TAU), 1.0)
		if phase < 0.0:
			phase += 1.0
		var y_offset = 0.0
		if bpm > 0:
			if phase > 0.42 and phase < 0.48:
				y_offset = -s.y * 0.38
			elif phase >= 0.48 and phase < 0.54:
				y_offset = s.y * 0.28
			elif phase >= 0.54 and phase < 0.62:
				y_offset = -s.y * 0.14
		pts.append(Vector2(x, mid_y + y_offset))

	ecg_graph.draw_polyline(pts, col, 2.0)

func _draw_mia_ecg_wave() -> void:
	if not is_instance_valid(mia_ecg_graph):
		return
	var s = mia_ecg_graph.size
	if s.x <= 10 or s.y <= 10:
		return
	var mid_y = s.y * 0.55
	var col = Color("#f600ff")
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

	if is_instance_valid(lbl_mia_bpm_overlay):
		if mia_lives <= 0 or mia_bpm <= 0:
			lbl_mia_bpm_overlay.text = "0 BPM"
			lbl_mia_bpm_overlay.modulate = Color("#ff1744")
		else:
			lbl_mia_bpm_overlay.text = "%d BPM" % mia_bpm
			lbl_mia_bpm_overlay.modulate = Color("#ff1744") if mia_lives <= 2 else Color("#f600ff")

	if is_instance_valid(mia_portrait_border_style):
		if mia_lives <= 2:
			mia_portrait_border_style.border_color = Color("#ff1744")
		elif mia_lives <= 3:
			mia_portrait_border_style.border_color = Color("#ffaa00")
		else:
			mia_portrait_border_style.border_color = Color("#f600ff")

func _draw_tactical_map() -> void:
	var s = tactical_map.size
	if s.x < 40 or s.y < 40:
		return
	var font = ThemeDB.fallback_font
	var grid_col = Color(0.0, 0.94, 1.0, 0.05)

	var step = 22.0
	var x = 0.0
	while x < s.x:
		tactical_map.draw_line(Vector2(x, 0), Vector2(x, s.y), grid_col, 1.0)
		x += step
	var y = 0.0
	while y < s.y:
		tactical_map.draw_line(Vector2(0, y), Vector2(s.x, y), grid_col, 1.0)
		y += step

	tactical_map.draw_string(font, Vector2(8, 15), "3-2-2-1 CAMERAS (CLICK NODE TO VIEW 3D CAM)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#88ccee"))

	var mid_y = s.y * 0.50
	var top_y = s.y * 0.27
	var bot_y = s.y * 0.73

	# Posiciones de los 8 nodos de la red 3 - 2 - 2 - 1 (3 pasillos en el lugar 1: C1 / C1B / C1C)
	var p_core = Vector2(s.x * 0.07, mid_y)
	var p_1 = Vector2(s.x * 0.22, s.y * 0.24)
	var p_1b = Vector2(s.x * 0.22, mid_y)
	var p_1c = Vector2(s.x * 0.22, s.y * 0.76)
	var p_2a = Vector2(s.x * 0.44, top_y)
	var p_2b = Vector2(s.x * 0.44, bot_y)
	var p_3a = Vector2(s.x * 0.67, top_y)
	var p_3b = Vector2(s.x * 0.67, bot_y)
	var p_4 = Vector2(s.x * 0.84, mid_y)
	var p_you = Vector2(s.x * 0.95, mid_y)

	map_node_positions = {
		"1": p_1,
		"1B": p_1b,
		"1C": p_1c,
		"2A": p_2a,
		"2B": p_2b,
		"3A": p_3a,
		"3B": p_3b,
		"4": p_4
	}

	# Conexiones de pasillos CORE -> 3 (C1, C1B, C1C) -> 2 (2A, 2B) -> 2 (3A, 3B) -> 1 (4) -> YOU
	var line_col = Color(0.18, 0.52, 0.72, 0.55)
	var edges = [
		[p_core, p_1],
		[p_core, p_1b],
		[p_core, p_1c],
		[p_1, p_2a],
		[p_1, p_2b],
		[p_1b, p_2a],
		[p_1b, p_2b],
		[p_1c, p_2a],
		[p_1c, p_2b],
		[p_2a, p_3a],
		[p_2b, p_3b],
		[p_2a, p_3b],
		[p_2b, p_3a],
		[p_3a, p_4],
		[p_3b, p_4],
		[p_4, p_you]
	]
	for e in edges:
		tactical_map.draw_line(e[0], e[1], line_col, 2.2)

	# Dibujar CORE (Izquierda) y YOU (Derecha)
	tactical_map.draw_circle(p_core, 10.0, Color(0.3, 0.05, 0.1, 0.9))
	tactical_map.draw_arc(p_core, 10.0, 0, TAU, 16, Color("#ff1744"), 1.8)
	tactical_map.draw_string(font, p_core + Vector2(-14, 21), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ff6688"))

	var you_col = current_mission.agent_color if is_instance_valid(current_mission) else Color("#00f0ff")
	tactical_map.draw_circle(p_you, 10.0, Color(0.05, 0.18, 0.28, 0.9))
	tactical_map.draw_arc(p_you, 10.0, 0, TAU, 16, you_col, 1.8)
	tactical_map.draw_string(font, p_you + Vector2(-12, 21), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, you_col)

	var monster_node = _get_monster_node_id()
	# Dibujar las 6 Cámaras / Puertas (1 - 2 - 2 - 1)
	for node_id in CAM_NODE_IDS:
		var npos: Vector2 = map_node_positions[node_id]
		var d_state: String = door_node_states.get(node_id, "OPEN")
		var is_cam_sel: bool = (selected_cam_id == node_id)
		var is_monster_here: bool = (monster_node == node_id)

		var ncol = Color("#00f0ff")
		var nfill = Color(0.06, 0.16, 0.26, 0.92)
		if d_state == "LOCKED":
			ncol = Color("#00ff9d")
			nfill = Color(0.04, 0.28, 0.16, 0.95)
		elif d_state == "BREACHED":
			ncol = Color("#ff1744")
			nfill = Color(0.32, 0.04, 0.09, 0.95)
		elif is_monster_here and monster_spotted_on_cam:
			ncol = Color("#ffaa00")
			nfill = Color(0.28, 0.16, 0.04, 0.95)

		var box_r = Rect2(npos - Vector2(18, 13), Vector2(36, 26))
		tactical_map.draw_rect(box_r, nfill, true)
		tactical_map.draw_rect(box_r, Color("#ffcc00") if is_cam_sel else ncol, false, 2.5 if is_cam_sel else 1.6)
		tactical_map.draw_string(font, npos + Vector2(-11, 4), "C" + node_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE if is_cam_sel else ncol)

		# Indicador del monstruo si fue avistado en la cámara 3D (o en etapas de 1 sola puerta)
		if is_monster_here and (monster_spotted_on_cam or not _is_branching_level(monster_security_level)):
			var pulse_r = 5.0 + sin(pulse_phase * 2.5) * 2.0
			var m_dot = npos + Vector2(0, -18)
			tactical_map.draw_circle(m_dot, pulse_r + 2.0, Color(1.0, 0.08, 0.2, 0.35))
			tactical_map.draw_circle(m_dot, 5.0, Color("#ff1744"))
		elif _is_branching_level(monster_security_level) and node_id.begins_with(str(monster_security_level)) and not monster_spotted_on_cam:
			tactical_map.draw_string(font, npos + Vector2(-4, -15), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffcc00"))

	# Leyenda inferior compacta
	var stage_desc = "STAGE %d/4" % clampi(monster_security_level, 1, TOTAL_SECURITY_LEVELS)
	var footer_txt = "%s  |  VIEWING: CAM %s  |  DEFENDED: %d/%d" % [
		stage_desc,
		selected_cam_id,
		gates_closed_by_guard,
		TOTAL_DEFENSES_REQUIRED
	]
	tactical_map.draw_string(font, Vector2(8, s.y - 7), footer_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#aaddff"))

# =========================================================
# 6. SHADER CRT Y MODAL DE MUERTE / REINICIO DE NOCHE (FNAF 2D)
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
	lbl_death_title.text = "☣️ SECURITY LEVEL 5 BREACHED — CONTAINMENT LOST"
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
	btn_retry_night.text = "🔄 RESTART NIGHT SHIFT (12:00 AM)"
	btn_retry_night.custom_minimum_size = Vector2(310, 52)
	btn_retry_night.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_retry_night, Color("#00ff9d"), true)
	btn_retry_night.pressed.connect(func():
		death_modal.visible = false
		load_mission(current_mission, false)
	)
	btns_hbox.add_child(btn_retry_night)

	var btn_death_vn = Button.new()
	btn_death_vn.text = "🎭 CHANGE COMPANION / STORY"
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
	# Ojos carmesí brillantes del monstruo Subject-Zero en la oscuridad
	var left_eye = Vector2(cx - 110, cy) + jitter
	var right_eye = Vector2(cx + 110, cy) + jitter
	death_art_canvas.draw_circle(left_eye, 28.0, Color(1.0, 0.0, 0.15, 0.25))
	death_art_canvas.draw_circle(right_eye, 28.0, Color(1.0, 0.0, 0.15, 0.25))
	death_art_canvas.draw_circle(left_eye, 11.0, Color("#ff1744"))
	death_art_canvas.draw_circle(right_eye, 11.0, Color("#ff1744"))
	death_art_canvas.draw_circle(left_eye, 4.0, Color.WHITE)
	death_art_canvas.draw_circle(right_eye, 4.0, Color.WHITE)
	# Garras / líneas de distorsión roja
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
uniform float intensity : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 uv = SCREEN_UV;
	float shift = 0.0009 * intensity;
	float r = texture(SCREEN_TEXTURE, uv + vec2(shift, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(shift, 0.0)).b;
	vec3 col = vec3(r, g, b);

	float scanline = sin(uv.y * 900.0) * (0.04 * intensity);
	col -= scanline;

	float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	float vig_factor = clamp(pow(16.0 * vig, 0.16), 0.0, 1.0);
	col *= mix(1.0, vig_factor, intensity);

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
# 7. LÓGICA DEL MONSTRUO, GUARDIA Y RESOLUCIÓN DE LA NOCHE
# =========================================================
func _on_monster_completed_hack(reason_msg: String) -> void:
	if not game_active or not is_instance_valid(current_mission):
		return
	monster_hack_progress = 0.0
	var breached_node = _get_monster_node_id()

	# VENTAJA DE NAOMI: Te perdona al menos 1 hackeo del monstruo deteniéndolo por vos
	if current_mission.companion_perk == "forgive_hack" and naomi_shield_charges > 0:
		naomi_shield_charges -= 1
		bpm = max(85, bpm - 10)
		_log_chat("NAOMI_SAVED_YOU", "🛡️ [NAOMI BLOCKED BREACH AT CAM %s!]: «%s I intercepted its hack for you! (0/1 Shield left)»" % [
			breached_node,
			reason_msg
		], "#00ff9d")
		_update_companion_perk_ui()
		_update_hud()
		_generate_breach_matrix()
		return

	# El monstruo vulnera la puerta actual de la red 3-2-2-1 y avanza a la siguiente etapa
	door_node_states[breached_node] = "BREACHED"
	monster_last_node_id = breached_node
	var breached_lvl = clampi(monster_security_level, 1, TOTAL_SECURITY_LEVELS)
	gate_states[breached_lvl - 1] = "BREACHED"
	monster_security_level += 1
	monster_branch = _random_branch_for_level(monster_security_level)
	monster_spotted_on_cam = (monster_security_level >= TOTAL_SECURITY_LEVELS) or (selected_cam_id == _get_monster_node_id())
	bpm = min(max_bpm, bpm + 22)

	# Mia pierde 1 corazón y su pulso se acelera por cada puerta que vulnera el monstruo
	mia_lives = max(0, mia_lives - 1)
	mia_bpm = min(195, mia_bpm + 24)
	mia_damage_flash = 1.0
	_update_mia_vitals_ui()

	if mia_lives <= 0 or monster_security_level > TOTAL_SECURITY_LEVELS:
		_trigger_level_5_fatal_breach()
		return

	var next_stage_hint = ("Check CAMS [%s] to see which branch it took!" % _stage_doors_text(monster_security_level)) if _is_branching_level(monster_security_level) else ("It reached Final Door 4!")
	_log_chat("BREACH", "☣️ [DOOR C%s BREACHED!]: %s 💔 Mia lost 1 Heart (%d/%d left)! %s" % [
		breached_node,
		reason_msg,
		mia_lives,
		mia_max_lives,
		next_stage_hint
	], "#ff1744")
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()
	_generate_breach_matrix()

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

	_log_chat("FATAL_BREACH", "💀 %s BREACHED FINAL DOOR 4! MIA LOST ALL HER LIFE, %s WAS KILLED, AND THEN IT KILLED YOU!" % [m_name, comp_name], "#ff1744")
	status_overlay.text = "● CRITICAL BREACH // MIA: 0% HP // OPERATOR: DECEASED"
	status_overlay.modulate = Color("#ff1744")
	lbl_bpm_overlay.text = "0 BPM (DEAD)"
	btn_continue_vn.visible = true

	if is_instance_valid(death_modal):
		lbl_death_title.text = "☣️ 3-2-2-1 CONTAINMENT BREACHED — NIGHT FAILED"
		lbl_death_details.text = "[center][color=#ff6688][b]%s[/b] broke through the [b]3-2-2-1 Security Doors[/b] before Guard [b]%s[/b] could seal the final blast door.[/color]\n\n[color=#ff1744][b]1. Your Hacking Companion (%s) was killed right in front of your console.[/b]\n[b]2. Moments later, %s tore through the terminal and killed YOU.[/b][/color]\n\n[color=#00ff9d]Click below to restart the Night Shift from 12:00 AM![/color][/center]" % [
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
		var base_mia_bpm = 90 + (mia_max_lives - mia_lives) * 22
		mia_bpm = clampi(base_mia_bpm + randi_range(-2, 4), 75, 195)
	_update_hud()

	if bpm >= int(max_bpm * 0.85) and time_left % 9 == 0:
		_log_chat(current_mission.agent_name.to_upper(), current_mission.agent_panic_line, "#ff3366")

	if bpm >= max_bpm:
		bpm = int(max_bpm * 0.78)
		if monster_attack_active:
			_on_monster_completed_hack("%s panicked at max BPM, letting Subject-Zero slip through!" % current_mission.agent_name)
	elif time_left <= 0:
		_end_game(true, "mission", "06:00 AM REACHED! You and %s held off Subject-Zero all night!" % current_mission.agent_name)

func _on_reassure_pressed() -> void:
	if not game_active or reassure_used:
		return
	reassure_used = true
	btn_reassure.disabled = true
	btn_reassure.text = "♥ COMFORTED (+20)"

	bpm = max(68, bpm - 25)
	affinity = min(100, affinity + 20)
	monster_hack_progress = max(0.0, monster_hack_progress - 15.0)
	_update_hud()
	_log_chat("OPERATOR", current_mission.operator_reassure_line, "#00ff9d")
	_log_chat(current_mission.agent_name.to_upper(), current_mission.agent_reassure_reply, "#" + current_mission.agent_color.to_html(false))

func _on_inject_credential() -> void:
	_on_seal_door_choice_pressed("A")

func _on_seal_door_choice_pressed(branch_choice: String) -> void:
	if not game_active:
		return
	if not monster_attack_active:
		_log_chat("SYSTEM", "🔇 No active attack right now — Subject-Zero is dormant at Door [%s]. Wait for the Music Box to start!" % monster_last_node_id, "#88ccee")
		return
	if deciphered_count < 6:
		tab_container.current_tab = 1
		_log_chat("SYSTEM", "⚠️ Decipher the 6-char Night Code in [🔐 02_CODE] first (%d/6)!" % deciphered_count, "#ffcc00")
		return
	if not firewall_breached:
		tab_container.current_tab = 2
		_log_chat("SYSTEM", "⚠️ Complete the Hex Matrix in [⚡ 03_HACK] first so %s can lock the door!" % current_mission.security_guard_name, "#ffcc00")
		return

	var chosen_node_id = _node_id_for(monster_security_level, branch_choice)

	var actual_monster_node = _get_monster_node_id()
	door_node_states[chosen_node_id] = "LOCKED"
	_select_camera(chosen_node_id)

	# Si la etapa tiene varios pasillos (C1/C1B/C1C, 2A/2B, 3A/3B) y el jugador cerró la puerta equivocada:
	if _is_branching_level(monster_security_level) and chosen_node_id != actual_monster_node:
		firewall_breached = false
		_generate_night_secret_code(true)
		_on_monster_completed_hack("You sealed Door [C%s], but Subject-Zero was in [C%s] and slipped through the unsealed corridor!" % [chosen_node_id, actual_monster_node])
		return

	# ¡Cerró la puerta correcta donde estaba el monstruo!
	gate_states[clampi(gates_closed_by_guard, 0, gate_states.size() - 1)] = "LOCKED"
	gates_closed_by_guard += 1
	monster_hack_progress = 0.0
	music_box_charge = min(100.0, music_box_charge + 22.0)
	music_box_pulse_grace = 1.1
	affinity = min(100, affinity + 12)
	bpm = max(70, bpm - 12)
	mia_prediction_ready = (current_mission.companion_perk == "prediction")

	if gates_closed_by_guard >= TOTAL_DEFENSES_REQUIRED:
		_update_hud()
		var final_route = "romance" if affinity >= 75 else "mission"
		var win_txt = current_mission.romance_success_text if final_route == "romance" else current_mission.mission_success_text
		_end_game(true, final_route, win_txt)
		return

	# Terminar el ataque actual: el monstruo se QUEDA en la misma puerta (no avanza).
	# Solo avanza de puerta cuando logra hackearte. Tras un cooldown impredecible vuelve a atacar desde acá.
	monster_attack_active = false
	monster_is_moving = false
	monster_hack_progress = 0.0
	music_box_charge = 100.0
	music_box_pulse_grace = 0.0
	music_box_holding = false
	monster_last_node_id = chosen_node_id
	monster_advance_on_next_wave = false
	monster_cooldown_timer = randf_range(7.0, 14.0)

	_log_chat("GUARD_" + current_mission.security_guard_name.to_upper(), "🔒 «Door [%s] SEALED! Attack repelled (%d/%d). Subject-Zero is still behind Door [%s]... it will try again soon.»" % [chosen_node_id, gates_closed_by_guard, TOTAL_DEFENSES_REQUIRED, chosen_node_id], "#00ff9d")

	firewall_breached = false
	input_code.text = ""
	_generate_night_secret_code(true)
	_generate_breach_matrix()
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()

func _on_protect_agent() -> void:
	if not game_active:
		return
	if not firewall_breached and gates_closed_by_guard < 2:
		tab_container.current_tab = 2
		_log_chat("SYSTEM", "⚠️ Seal at least 2 Doors or complete [03_HACK] before overcharging the Romance Shield!", "#ffcc00")
		return
	for node_key in CAM_NODE_IDS:
		door_node_states[node_key] = "LOCKED"
	gates_closed_by_guard = TOTAL_SECURITY_LEVELS
	affinity = min(100, affinity + 35)
	bpm = 78
	_update_hud()
	_log_chat("OPERATOR", current_mission.operator_protect_line, "#00ff9d")
	_log_chat(current_mission.agent_name.to_upper(), current_mission.agent_protect_reply, "#" + current_mission.agent_color.to_html(false))
	_end_game(true, "romance", current_mission.romance_success_text)

func _end_game(victory: bool, outcome_type: String, reason: String) -> void:
	game_active = false
	game_timer.stop()
	last_outcome_type = outcome_type
	var color = "#00ff9d" if victory else "#ff3366"
	_log_chat("OUTCOME", reason, color)
	status_overlay.text = "● CONTAINMENT: " + ("ALL 3-2-2-1 DOORS SEALED (SURVIVED)" if victory else "BREACHED")
	status_overlay.modulate = Color(color)
	btn_continue_vn.visible = true

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
	lbl_bpm_overlay.text = "%d BPM" % bpm
	bar_affinity.value = affinity
	lbl_affinity.text = "♥ BOND (%s): %d%%  |  MIA: %d/5 ♥  |  STAGE: %d/4" % [
		current_mission.agent_name.to_upper(),
		affinity,
		mia_lives,
		clampi(monster_security_level, 1, TOTAL_SECURITY_LEVELS)
	]
	_update_mia_vitals_ui()

func _populate_mission_selector() -> void:
	mission_selector.clear()
	for i in range(available_missions.size()):
		var m = available_missions[i]
		var perk_short = "Prediction" if m.companion_perk == "prediction" else "1-Hack Shield"
		mission_selector.add_item("Companion: %s (%s) / Guard: %s" % [m.agent_name, perk_short, m.security_guard_name], i)

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
# 8. HELPERS DE ESTILO VISUAL (CYBERPUNK UI KIT)
# =========================================================
func _create_cyber_panel(bg_color: Color, border_color: Color, border_w: int = 1, pad: int = 8) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_w)
	style.border_width_left = max(border_w, 3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(pad)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_badge_label(txt: String, font_col: Color, bg_col: Color) -> Label:
	var lbl = Label.new()
	_update_badge_style(lbl, txt, font_col, bg_col)
	return lbl

func _update_badge_style(lbl: Label, txt: String, font_col: Color, bg_col: Color) -> void:
	lbl.text = "  " + txt + "  "
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", font_col)
	var st = StyleBoxFlat.new()
	st.bg_color = bg_col
	st.set_corner_radius_all(3)
	st.set_content_margin_all(4)
	lbl.add_theme_stylebox_override("normal", st)

func _apply_styled_button(btn: Button, col: Color, prominent: bool = true) -> void:
	var bg_alpha = 0.22 if prominent else 0.12
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(col.r * bg_alpha, col.g * bg_alpha, col.b * bg_alpha, 0.95)
	style_normal.border_color = col
	style_normal.set_border_width_all(2 if prominent else 1)
	style_normal.set_corner_radius_all(4)
	style_normal.set_content_margin_all(8)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(col.r * 0.38, col.g * 0.38, col.b * 0.38, 1.0)
	style_hover.border_color = col.lightened(0.3)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.08, 0.1, 0.14, 0.7)
	style_disabled.border_color = Color(0.25, 0.3, 0.38, 0.6)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", col.lightened(0.38))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("#556677"))

func _style_matrix_cell(btn: Button, bg_col: Color, border_col: Color, font_col: Color) -> void:
	var st = StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	var st_hover = st.duplicate()
	st_hover.bg_color = border_col.darkened(0.55)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_hover)
	btn.add_theme_stylebox_override("disabled", st)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_disabled_color", font_col)

func _style_progress_bar(bar: ProgressBar, bg_col: Color, fill_col: Color) -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = bg_col
	sb_bg.set_corner_radius_all(3)
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = fill_col
	sb_fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fill)

func _style_tab_container(tc: TabContainer) -> void:
	var panel_st = StyleBoxFlat.new()
	panel_st.bg_color = Color("#090f18")
	panel_st.border_color = Color("#1e3448")
	panel_st.set_border_width_all(1)
	panel_st.border_width_top = 2
	panel_st.set_corner_radius_all(4)
	panel_st.set_content_margin_all(10)

	var tab_sel = StyleBoxFlat.new()
	tab_sel.bg_color = Color("#122436")
	tab_sel.border_color = Color("#00f0ff")
	tab_sel.border_width_top = 2
	tab_sel.set_content_margin_all(8)

	var tab_unsel = StyleBoxFlat.new()
	tab_unsel.bg_color = Color("#070b12")
	tab_unsel.border_color = Color("#162230")
	tab_unsel.border_width_top = 1
	tab_unsel.set_content_margin_all(8)

	tc.add_theme_stylebox_override("panel", panel_st)
	tc.add_theme_stylebox_override("tab_selected", tab_sel)
	tc.add_theme_stylebox_override("tab_unselected", tab_unsel)
	tc.add_theme_color_override("font_selected_color", Color("#00f0ff"))
	tc.add_theme_color_override("font_unselected_color", Color("#6688aa"))

func _create_doc_tab_wrapper() -> MarginContainer:
	var m = MarginContainer.new()
	m.clip_contents = true
	for side in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	return m
