extends Control

signal hacking_completed(outcome_type: String, final_affinity: int)

@export var available_missions: Array[MissionData] = []
@export var starting_mission_index: int = 0
@export var start_in_vn_mode: bool = false

# --- CÁMARAS (PANEO + LENTE ESTIRADO + ESTADOS) ---
@export_group("Cámaras Estilo FNAF (Imágenes por Estado)")
@export var tex_cam_empty = load("res://assets/bunker/hall1.png")
@export var tex_cam_door_locked: Texture2D    # Compuerta cerrada
@export var tex_monster_stage_1: = load("res://assets/bunker/hall1_m1.png")
@export var tex_monster_stage_2: = load("res://assets/bunker/hall1_m2.png") # Fase 2 (40-74%): Monstruo a mitad del pasillo
@export var tex_monster_stage_3: = load("res://assets/bunker/hall1_m3.png")  # Fase 3 (75-100%): Monstruo pegado a la cámara
@export var tex_ghost_girl_state: Texture2D   # Niña Fantasma mirando a la cámara

# Video de la Niña (1824x768), UN solo archivo: 0:00-1:00 mirando a cámara, 1:00-2:00 jumpscare
@export_file("*.ogv") var ghost_video_path: String = "res://assets/videos/jumpscare_fg.ogv"

# --- VIDEOS DE LA COMPAÑERA EN EL PANEL IZQUIERDO (8s CADA UNO) ---
@export_group("Videos de Compañera (Panel Izquierdo)")
## Video 1 (8s): Idle normal
@export_file("*.ogv") var naomi_idle_1_video_path: String = "res://assets/videos/nmidle.ogv"
## Video 2 (8s): Mirando alrededor
@export_file("*.ogv") var naomi_idle_2_video_path: String = "res://assets/videos/nmlook.ogv"
## Video 3 (8s en loop): Preocupada mirando hacia abajo tratando de arreglar la terminal
@export_file("*.ogv") var naomi_hacked_video_path: String = "res://assets/videos/nmhack.ogv"
@export var naomi_idle_wait_seconds: float = 5.0 # Espera de 5s entre el Video 1 y el Video 2

var companion_video_player: VideoStreamPlayer
var companion_static_burst_rect: ColorRect
var companion_idle_1_stream: VideoStream
var companion_idle_2_stream: VideoStream
var companion_hacked_stream: VideoStream
var companion_idle_wait_timer: float = 0.0
var companion_static_timer: float = 0.0
var companion_was_hacked_state: bool = false
var companion_next_is_look_around: bool = false # Alterna entre Video 1 (Idle) y Video 2 (Mirando alrededor)

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
var last_outcome_type: String = "mission"

# --- ENERGÍA, TEMPERATURA Y SABOTAJES ---
var power_energy: float = 100.0
var bunker_temperature: float = 24.0
const NORMAL_TEMP: float = 24.0
const CRITICAL_TEMP: float = 100.0
var temp_hacked_by_monster: bool = false
var light_hacked_by_monster: bool = false
var companion_pc_unlocked: bool = true

# --- TEMPORIZADORES DE EVENTOS ---
var next_cooling_hack_timer: float = 22.0
var next_pc_hack_timer: float = 25.0

# --- TEMPORIZADOR OCULTO AL CERRARLE LA PUERTA ---
var door_hold_timer: float = 0.0
var door_hold_target_time: float = -1.0

# --- ESTADO DE SUBJECT-ZERO (TOPOLOGÍA 3 - 2 - 2 - 1) ---
const TOTAL_SECURITY_LEVELS: int = 4
const TOTAL_DEFENSES_REQUIRED: int = 5
const CAM_NODE_IDS: Array[String] = ["1A", "1", "1B", "2A", "2B", "3A", "3B", "4"]
var monster_security_level: int = 1
var monster_branch: String = "B"
var monster_spotted_on_cam: bool = false
var monster_attack_active: bool = false
var monster_cooldown_timer: float = 4.0
var monster_last_node_id: String = "1"
var monster_advance_on_next_wave: bool = false
var gates_closed_by_guard: int = 0
var door_node_states: Dictionary = {
	"1A": "OPEN", "1": "OPEN", "1B": "OPEN",
	"2A": "OPEN", "2B": "OPEN",
	"3A": "OPEN", "3B": "OPEN",
	"4": "OPEN"
}
var selected_cam_id: String = "1"
var cam_select_buttons: Dictionary = {}
var map_node_positions: Dictionary = {}
var monster_hack_progress: float = 0.0
var naomi_shield_charges: int = 1
var mia_prediction_ready: bool = true

# --- ESTADO DE LA NIÑA FANTASMA (ESTILO PHANTOM FNAF 3) ---
var ghost_active_cam: String = ""
var ghost_stare_timer: float = 0.0
const GHOST_MAX_STARE_TIME: float = 1.0 # = duración del clip idle (0:00-1:00)
var ghost_encounters_count: int = 0
const GHOST_MAX_ENCOUNTERS: int = 3
var ghost_forced_attack_timer: float = 0.0
var camera_disabled_timer: float = 0.0
var ghost_jumpscare_flash: float = 0.0
var ghost_video_container: AspectRatioContainer
var ghost_video_player: VideoStreamPlayer
var ghost_stream: VideoStream
var ghost_seek_check_timer: float = 0.0
var ghost_video_mode: String = "" # "", "idle" o "jumpscare"
var ghost_jumpscare_playing: bool = false
var ghost_jumpscare_timer: float = 0.0
var ghost_jumpscare_reason: String = ""
const GHOST_JUMPSCARE_START: float = 1.0 # segundo donde empieza el jumpscare dentro del video
const GHOST_VIDEO_LENGTH: float = 2.0
var previz_ghost_root: Node3D
var previz_ghost_head: Node3D
var previz_screen_blackout_overlay: ColorRect
var lbl_previz_blackout_msg: Label

# --- AUDIO ---
@export_file("*.mp3", "*.wav", "*.ogg") var bgm_music_path: String = "res://Music/in_game.mp3"
@export_range(-30.0, 6.0, 0.5) var bgm_volume_db: float = 0.00
@export_file("*.mp3", "*.wav", "*.ogg") var button_click_mp3_path: String = "res://Music/sound effects/click.mp3"
@export_file("*.mp3", "*.wav", "*.ogg") var turbine_mp3_path: String = "res://Music/sound effects/fan.mp3"
@export_file("*.mp3", "*.wav", "*.ogg") var alarm_mp3_path: String = "res://Music/sound effects/alarm.mp3"
@export_file("*.mp3", "*.wav", "*.ogg") var light_mp3_path: String = "res://Music/sound effects/light.mp3"
@export_file("*.mp3", "*.wav", "*.ogg") var ghost_laugh_mp3_path: String = "res://Music/sound effects/laugh.mp3"
@export var is_turbine_oneshot: bool = true

var sfx_click_player: AudioStreamPlayer
var bgm_audio_player: AudioStreamPlayer
var music_audio_player: AudioStreamPlayer
var alarm_audio_player: AudioStreamPlayer
var light_audio_player: AudioStreamPlayer
var ghost_laugh_player: AudioStreamPlayer 
var sfx_thud_player: AudioStreamPlayer
var sfx_scare_player: AudioStreamPlayer
var turbine_beat_timer: float = 0.0
var alarm_beat_timer: float = 0.0

# --- NODOS DEL PREVIZ 3D DE CÁMARAS ---
var cam_pan_root: Control
var cam_state_tex_rect: TextureRect
var cam_door_bars_overlay: Control
var cam_ghost_overlay: Control
var cam_static_burst_rect: ColorRect
var cam_lens_mat: ShaderMaterial
var cam_static_timer: float = 0.0
var cam_pan_time: float = 0.0 # Reloj propio del paneo: 0 = centro
var cam_pan_last_cam_id: String = ""
const CAM_PAN_INITIAL_HOLD: float = 2.0 # Segundos quietos en el centro antes de empezar a moverse
var current_fnaf_state_key: String = ""
var current_monster_stage: int = 0


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
var btn_quick_flash: Button
var btn_open_all_doors: Button

# --- ESTADO DE VIDA Y PULSO DE LA COMPAÑERA ---
var mia_max_lives: int = 3
var mia_lives: int = 3
var mia_hp_percent: int = 100
var mia_bpm: int = 92
var mia_pulse_phase: float = 0.0
var mia_damage_flash: float = 0.0

# --- MOTOR VN INTERNO ---
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

# --- TAB 01: TURBINA (MANTENER PRESIONADO) ---
var music_box_charge: float = 90.0
var is_holding_turbine_btn: bool = false
var monster_is_moving: bool = true
var music_gear_angle: float = 0.0
var bar_music_box: ProgressBar
var lbl_music_status: Label
var lbl_music_beast_state: Label
var music_box_canvas: Control
var btn_wind_music: Button

# --- TAB 02: CALIBRACIÓN DE PERILLAS Y ÓPTICA ---
const KNOB_COUNT: int = 4
const KNOB_MAX_STEPS: int = 8
var knob_Target_values: Array[int] = [2, 5, 1, 6]
var knob_Current_values: Array[int] = [2, 5, 1, 6]
var knob_canvases: Array[Control] = []
var knob_val_labels: Array[Label] = []
var dragging_knob_index: int = -1

# --- BANNER DE ALERTA ---
var hack_alert_banner: PanelContainer
var hack_alert_style: StyleBoxFlat
var lbl_hack_alert_banner: Label
var btn_hack_alert_goto: Button

var flash_stun_grace: float = 0.0
var flash_cooldown: float = 0.0
var lbl_lure_title: Label
var lbl_lure_selected_cam: Label
var lbl_lure_hint: Label
var lbl_sys_audio_badge: Label
var lbl_sys_video_badge: Label
var lbl_sys_door_badge: Label
var btn_hallway_light: Button
var btn_goto_reboot: Button
var lbl_code_progress_status: Label

# --- TAB 03: MATRIZ HEX ---
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

var tactical_map: Control
var monitor_3d_diorama: Control
var matrix_stream_panel: PanelContainer
var matrix_stream_style: StyleBoxFlat
var matrix_rain_canvas: Control

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

# --- BARRA DE GUÍA PARA EL JUGADOR ---
var guide_panel: PanelContainer
var guide_style: StyleBoxFlat
var lbl_guide_title: Label
var lbl_guide_text: Label
var lbl_guide_goal: Label
var btn_guide_action: Button
var guide_action_tab: int = -1
var guide_tick: float = 0.0
var guide_level: int = 0
var guide_focus: Array[Control] = []
var guide_prev_focus: Array[Control] = []
var help_dialog: AcceptDialog
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
	_bind_all_tablet_button_sounds(self)
	var vp_s: Vector2 = Vector2(get_viewport().size)
	if vp_s.x > 100 and vp_s.y > 100:
		size = vp_s

	if available_missions.is_empty():
		available_missions.append(_create_default_template("Mia", "ORACLE-01", Color("#f600ff")))
		available_missions.append(_create_default_template("Naomi", "AEGIS-02", Color("#00ff9d")))
	elif available_missions.size() == 1:
		available_missions.append(_create_default_template("Naomi", "AEGIS-02", Color("#00ff9d")))

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
	if is_instance_valid(matrix_rain_canvas):
		matrix_rain_canvas.queue_redraw()
	_update_hack_alert_visual_pulse()
	if is_instance_valid(monitor_3d_diorama):
		monitor_3d_diorama.queue_redraw()
	if is_instance_valid(mia_ecg_graph):
		mia_ecg_graph.queue_redraw()
	if is_instance_valid(death_modal) and death_modal.visible and is_instance_valid(death_art_canvas):
		death_art_canvas.queue_redraw()

	if game_active and not vn_active:
		_update_guidance(delta)
		if flash_stun_grace > 0.0:
			flash_stun_grace = max(0.0, flash_stun_grace - delta)
		if flash_cooldown > 0.0:
			flash_cooldown = max(0.0, flash_cooldown - delta)
		if ghost_jumpscare_flash > 0.0:
			ghost_jumpscare_flash = max(0.0, ghost_jumpscare_flash - delta * 2.5)

		# ¡ACTUALIZAR LOS 3 VIDEOS DE NAOMI / COMPAÑERA EN CADA FRAME!
		_update_companion_left_video(delta)
			
		# Actualizar fase de caminata 3D cuando Subject-Zero se mueve
		if monster_attack_active and monster_is_moving:
			previz_walk_phase = fmod(previz_walk_phase + delta * 7.5, TAU)

		# Descontar el timer del 3er encuentro inevitable con la Niña Fantasma
		if ghost_forced_attack_timer > 0.0:
			ghost_forced_attack_timer = max(0.0, ghost_forced_attack_timer - delta)
			if ghost_forced_attack_timer <= 0.0:
				_trigger_ghost_girl_jumpscare("¡3er encuentro con la Anomalía Fantasma en [C%s]!" % selected_cam_id)

		# Jumpscare en video de la Niña: al terminar el clip recién se aplica el castigo
		if ghost_seek_check_timer > 0.0:
			ghost_seek_check_timer -= delta
			if ghost_seek_check_timer <= 0.0 and is_instance_valid(ghost_video_player) \
					and ghost_video_player.stream_position < GHOST_JUMPSCARE_START * 0.6:
				push_warning("Ghost video: este formato/versión no soporta seek; el jumpscare directo arrancará desde 0:00.")
				ghost_jumpscare_timer += GHOST_JUMPSCARE_START
		if ghost_jumpscare_playing:
			ghost_jumpscare_timer -= delta
			if ghost_jumpscare_timer <= 0.0:
				_finish_ghost_jumpscare()

		# --- PROCESAR CEGUERA DE CÁMARA Y LA NIÑA FANTASMA ---
		if camera_disabled_timer > 0.0:
			camera_disabled_timer = max(0.0, camera_disabled_timer - delta)
			if camera_disabled_timer <= 0.0 and not light_hacked_by_monster:
				_refresh_lure_tab_ui()

		if ghost_active_cam != "" and selected_cam_id == ghost_active_cam and camera_disabled_timer <= 0.0 and not light_hacked_by_monster and not ghost_jumpscare_playing:
			ghost_stare_timer += delta
			if ghost_stare_timer >= GHOST_MAX_STARE_TIME:
				_begin_ghost_jumpscare("¡Miraste demasiado tiempo a la Anomalía Fantasma en [C%s]!" % selected_cam_id)
		else:
			ghost_stare_timer = max(0.0, ghost_stare_timer - delta * 2.0)

		# --- EVENTOS DE SABOTAJE ---
		next_cooling_hack_timer -= delta
		if next_cooling_hack_timer <= 0.0:
			next_cooling_hack_timer = randf_range(18.0, 34.0)
			if not temp_hacked_by_monster and randf() < 0.70:
				temp_hacked_by_monster = true
				companion_pc_unlocked = false # <-- Pone el radar y el binario en ROJO
				_generate_breach_matrix()     # <-- Genera código en Tab 03 para repararlo
				_refresh_lure_tab_ui()
				mia_bpm = min(195, mia_bpm + 34)
				_update_mia_vitals_ui()

		next_pc_hack_timer -= delta
		if next_pc_hack_timer <= 0.0:
			next_pc_hack_timer = randf_range(20.0, 36.0)
			if companion_pc_unlocked and monster_attack_active and randf() < 0.70:
				companion_pc_unlocked = false
				_generate_breach_matrix()
				_refresh_lure_tab_ui()

		# 1. PROCESAR TURBINA (MANTENER PRESIONADO PARA CARGAR)
		if is_holding_turbine_btn and power_energy > 0.0:
			music_box_charge = min(100.0, music_box_charge + delta * 28.0)
			power_energy = max(0.0, power_energy - delta * 1.1)
			if music_box_charge >= 88.0 and temp_hacked_by_monster and companion_pc_unlocked:
				temp_hacked_by_monster = false
		else:
			var turb_drain: float = 2.0
			if monster_attack_active:
				turb_drain = 3.1
			if temp_hacked_by_monster:
				turb_drain += 2.2
			music_box_charge = max(0.0, music_box_charge - delta * turb_drain)

		var turbine_working: bool = (music_box_charge >= 40.0 and power_energy > 0.0)
		if turbine_working:
			var gear_spd: float = 8.5 if is_holding_turbine_btn else 3.8 * (music_box_charge / 100.0)
			music_gear_angle = fmod(music_gear_angle + delta * gear_spd, TAU)

		_update_custom_turbine_audio(delta)

		# 2. PROCESAR TEMPERATURA
		var temp_rate: float = 0.0
		if not turbine_working:
			temp_rate += 4.6
		if temp_hacked_by_monster:
			temp_rate += 2.8
		if turbine_working and not temp_hacked_by_monster:
			temp_rate = -3.8

		bunker_temperature = clampf(bunker_temperature + delta * temp_rate, NORMAL_TEMP, CRITICAL_TEMP)

		# 3. PROCESAR ENERGÍA (UNA SOLA PUERTA CONSUME BASTANTE)
		var closed_doors_cnt: int = _count_locked_doors()
		var energy_drain: float = float(closed_doors_cnt) * 2.4
		if not turbine_working:
			energy_drain += 3.2
		if bunker_temperature >= 70.0:
			energy_drain += 1.5
		if closed_doors_cnt == 0 and turbine_working and bunker_temperature < 50.0 and not is_holding_turbine_btn:
			energy_drain = -0.9

		power_energy = clampf(power_energy - delta * energy_drain, 0.0, 100.0)

		if power_energy <= 0.0 and closed_doors_cnt > 0:
			_force_open_all_doors_on_power_outage()

		if bunker_temperature >= CRITICAL_TEMP:
			bunker_temperature = 75.0
			power_energy = max(0.0, power_energy - 25.0)

		# 4. PROCESAR ATAQUE DE SUBJECT-ZERO (SIN SPOILERS DE PUERTA NI DE UBICACIÓN)
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
				var sys_txt = ("⚠️ %d SABOTAJE(S)!" % err_cnt) if err_cnt > 0 else "✓ FIREWALL OK"
				lbl_monster_status.text = "👁️ CÁMARAS EN LÍNEA // %s  |  CONTENCIONES: %d/%d" % [
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
					door_hold_target_time = randf_range(2.5, 6.5)
					door_hold_timer = 0.0
				door_hold_timer += delta

				if companion_pc_unlocked:
					monster_hack_progress = max(0.0, monster_hack_progress - 6.0 * delta)
				monster_hack_progress = min(monster_hack_progress, 92.0)

				if door_hold_timer >= door_hold_target_time:
					_on_monster_left_after_closed_door(cur_monster_node, door_hold_target_time)
					return
			else:
				monster_is_moving = true
				door_hold_timer = 0.0
				door_hold_target_time = -1.0

				# 1. Velocidad base aumentada un +30%
				var hack_speed: float = (4.6 + float(monster_security_level) * 0.55) * 1.30
				if not turbine_working:
					hack_speed += 2.2
				if temp_hacked_by_monster:
					hack_speed += 1.4
				if is_holding_turbine_btn and monster_security_level >= 3:
					hack_speed += 1.8

				# 2. ¡EL MONSTRUO AVANZA MUCHO MÁS RÁPIDO SI TAB 02 O TAB 03 ESTÁN HACKEADAS!
				if light_hacked_by_monster or camera_disabled_timer > 0.0:
					hack_speed *= 1.25 # +25% de velocidad si la Niña tiró las perillas (Tab 02)
				if not companion_pc_unlocked:
					hack_speed *= 2.00 # +35% de velocidad si el Radar/Firewall está hackeado (Tab 03)

				var companion_reduction: float = 1.8 if companion_pc_unlocked else 0.0
				var net_delta: float = (hack_speed - companion_reduction) * delta
				monster_hack_progress = clampf(monster_hack_progress + net_delta, 0.0, 100.0)

			_update_turbine_ui()
			_update_energy_and_temp_hud()
			_update_terminal_lock_state()
			if is_instance_valid(music_box_canvas):
				music_box_canvas.queue_redraw()

			var cameras_working: bool = (camera_disabled_timer <= 0.0 and not light_hacked_by_monster and companion_pc_unlocked)
			var seeing_monster_now: bool = (selected_cam_id == cur_monster_node and cameras_working)
			if is_instance_valid(bar_monster_hack):
				bar_monster_hack.value = monster_hack_progress if seeing_monster_now else 0.0
			if is_instance_valid(lbl_monster_status):
				var fw_txt: String = "🛡️ SISTEMA: OK" if companion_pc_unlocked else "🚨 TAB 03 HACKEADA"
				var frenzy_tag: String = " ⚡[¡FRENESÍ: CÁMARAS CAÍDAS!]" if not cameras_working else ""
				if seeing_monster_now:
					lbl_monster_status.text = "☣️ ¡%s DETECTADO EN CAM C%s!%s  |  %s  |  DEFENSAS: %d/%d" % [
						current_mission.monster_name,
						cur_monster_node,
						frenzy_tag,
						fw_txt,
						gates_closed_by_guard,
						TOTAL_DEFENSES_REQUIRED
					]
					lbl_monster_status.modulate = Color("#ff1744")
				else:
					lbl_monster_status.text = "👁️ CÁMARAS EN LÍNEA%s  |  %s  |  CONTENCIONES: %d/%d" % [
						frenzy_tag,
						fw_txt,
						gates_closed_by_guard,
						TOTAL_DEFENSES_REQUIRED
					]
					lbl_monster_status.modulate = Color("#ffaa00") if (not companion_pc_unlocked or frenzy_tag != "") else Color("#00f0ff")
			_update_3d_previz(delta)

			if monster_hack_progress >= 100.0 and not door_is_closed_on_monster:
				_on_monster_completed_hack("Subject-Zero vulneró el sector [C%s]!" % cur_monster_node)
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
# 1. CARGADOR DE MISIÓN Y SONIDOS PROCEDURALES
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
	next_cooling_hack_timer = randf_range(16.0, 28.0)
	next_pc_hack_timer = randf_range(18.0, 30.0)
	door_hold_timer = 0.0
	door_hold_target_time = -1.0
	is_holding_turbine_btn = false

	ghost_active_cam = ""
	ghost_stare_timer = 0.0
	ghost_encounters_count = 0
	ghost_forced_attack_timer = 0.0
	camera_disabled_timer = 0.0
	ghost_jumpscare_flash = 0.0
	_reset_ghost_video()

	monster_security_level = 1
	monster_branch = _random_branch_for_level(1)
	monster_spotted_on_cam = false
	monster_attack_active = false
	monster_cooldown_timer = randf_range(3.0, 5.5)
	monster_last_node_id = _get_monster_node_id()
	monster_advance_on_next_wave = false
	gates_closed_by_guard = 0
	monster_hack_progress = 0.0
	door_node_states = {
		"1A": "OPEN", "1": "OPEN", "1B": "OPEN",
		"2A": "OPEN", "2B": "OPEN",
		"3A": "OPEN", "3B": "OPEN",
		"4": "OPEN"
	}
	selected_cam_id = "1"
	naomi_shield_charges = 1 if data.companion_perk == "forgive_hack" else 0
	mia_prediction_ready = (data.companion_perk == "prediction")
	flash_stun_grace = 0.0
	flash_cooldown = 0.0

	mia_max_lives = 3
	mia_lives = 3
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
	_setup_companion_left_video(data)
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

	status_overlay.text = "● FLASH EN CÁMARAS // ¡EVITÁ MIRAR A LA NIÑA FANTASMA!"
	status_overlay.modulate = Color("#00ff9d")
	lbl_sector.text = "SI VES A LA NIÑA EN CÁMARA, CAMBIÁ DE CÁMARA EN <1.4s"
	lbl_codename.text = "🔮 MIA PREDICTION" if data.companion_perk == "prediction" else "🛡️ NAOMI 1-HACK SHIELD"
	lbl_codename.modulate = data.agent_color

	vn_portrait_style.border_color = data.agent_color
	tactical_map.queue_redraw()

	tab_container.set_tab_title(0, "🌀 01_TURBINA")
	tab_container.set_tab_title(1, "🎛️ 02_ÓPTICA / PERILLAS")
	tab_container.set_tab_title(2, "💻 03_RADAR COMPAÑERA")
	tab_container.current_tab = 0

	music_box_charge = 92.0
	monster_is_moving = false
	_sync_knobs_aligned()
	_update_turbine_ui()
	_refresh_lure_tab_ui()
	_update_energy_and_temp_hud()

	bar_trace.max_value = data.mission_time_seconds
	bar_trace.value = data.mission_time_seconds

	_generate_breach_matrix()
	entered_sequence = target_sequence.duplicate()
	_refresh_matrix_ui()
	_setup_companion_left_video(data) # <-- Ponelo acá abajo
	_select_camera("1")
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()

	if launch_vn_intro and data.vn_intro_script.strip_edges() != "":
		game_active = false
		game_timer.stop()
		if is_instance_valid(bgm_audio_player):
			bgm_audio_player.stop()
		start_vn_sequence(data.vn_intro_script, "intro")
	else:
		vn_active = false
		vn_layer.visible = false
		game_active = true
		game_timer.start()
		if is_instance_valid(bgm_audio_player) and bgm_audio_player.stream != null and not bgm_audio_player.playing:
			bgm_audio_player.play()

func _setup_turbine_audio() -> void:
	
	# --- MÚSICA IN-GAME EN LOOP ---
	bgm_audio_player = AudioStreamPlayer.new()
	bgm_audio_player.volume_db = bgm_volume_db
	bgm_audio_player.finished.connect(func():
		if game_active and is_instance_valid(bgm_audio_player):
			bgm_audio_player.play()
	)
	add_child(bgm_audio_player)

	if bgm_music_path != "" and ResourceLoader.exists(bgm_music_path):
		var bgm_stream: AudioStream = load(bgm_music_path)
		if bgm_stream is AudioStreamMP3 or bgm_stream is AudioStreamOggVorbis:
			bgm_stream.loop = true
		bgm_audio_player.stream = bgm_stream
	
	
	music_audio_player = AudioStreamPlayer.new()
	music_audio_player.volume_db = -8.0
	add_child(music_audio_player)

	if turbine_mp3_path != "" and ResourceLoader.exists(turbine_mp3_path):
		music_audio_player.stream = load(turbine_mp3_path)
	else:
		music_audio_player.stream = _create_fallback_oneshot_wav("turbine")

	alarm_audio_player = AudioStreamPlayer.new()
	alarm_audio_player.volume_db = -6.0
	add_child(alarm_audio_player)

	if alarm_mp3_path != "" and ResourceLoader.exists(alarm_mp3_path):
		alarm_audio_player.stream = load(alarm_mp3_path)
	else:
		alarm_audio_player.stream = _create_fallback_oneshot_wav("alarm")

	light_audio_player = AudioStreamPlayer.new()
	light_audio_player.volume_db = -4.0
	add_child(light_audio_player)

	if light_mp3_path != "" and ResourceLoader.exists(light_mp3_path):
		light_audio_player.stream = load(light_mp3_path)
	else:
		light_audio_player.stream = _create_fallback_oneshot_wav("flash")
		
	ghost_laugh_player = AudioStreamPlayer.new()
	ghost_laugh_player.volume_db = -2.0
	add_child(ghost_laugh_player)

	if ghost_laugh_mp3_path != "" and ResourceLoader.exists(ghost_laugh_mp3_path):
		ghost_laugh_player.stream = load(ghost_laugh_mp3_path)
	else:
		ghost_laugh_player.stream = _create_fallback_oneshot_wav("scare")	

	sfx_thud_player = AudioStreamPlayer.new()
	sfx_thud_player.volume_db = 0.0
	sfx_thud_player.stream = _create_fallback_oneshot_wav("thud")
	add_child(sfx_thud_player)

	sfx_scare_player = AudioStreamPlayer.new()
	sfx_scare_player.volume_db = 1.0
	sfx_scare_player.stream = _create_fallback_oneshot_wav("scare")
	add_child(sfx_scare_player)
	
	sfx_click_player = AudioStreamPlayer.new()
	sfx_click_player.volume_db = -5.0
	sfx_click_player.max_polyphony = 4 # Permite varios clics rápidos seguidos sin cortarse
	if button_click_mp3_path != "" and ResourceLoader.exists(button_click_mp3_path):
		sfx_click_player.stream = load(button_click_mp3_path)
	else:
		sfx_click_player.stream = _create_fallback_oneshot_wav("click")
	add_child(sfx_click_player)

func _update_custom_turbine_audio(delta: float) -> void:
	if not is_instance_valid(music_audio_player):
		return

	var charge_norm: float = clampf(music_box_charge / 100.0, 0.0, 1.0)
	if power_energy <= 0.0:
		charge_norm = 0.0

	if music_audio_player.stream != null and charge_norm > 0.02:
		if is_turbine_oneshot:
			var current_bpm: float = lerpf(25.0, 220.0, pow(charge_norm, 1.3))
			var beat_interval: float = 60.0 / current_bpm
			turbine_beat_timer -= delta
			if turbine_beat_timer <= 0.0:
				turbine_beat_timer = beat_interval
				music_audio_player.pitch_scale = lerpf(0.45, 1.15, charge_norm) + randf_range(-0.03, 0.03)
				music_audio_player.volume_db = lerpf(-16.0, -6.0, charge_norm)
				music_audio_player.play()
		else:
			music_audio_player.pitch_scale = lerpf(0.30, 1.20, charge_norm)
			music_audio_player.volume_db = lerpf(-18.0, -6.0, charge_norm)
			if not music_audio_player.playing:
				music_audio_player.play()
	else:
		music_audio_player.stop()

	var turbine_in_red: bool = (music_box_charge < 40.0 or power_energy <= 0.0)
	if is_instance_valid(alarm_audio_player) and alarm_audio_player.stream != null:
		if turbine_in_red:
			var danger: float = clampf(1.0 - (music_box_charge / 40.0), 0.0, 1.0)
			var alarm_bpm: float = lerpf(80.0, 180.0, danger)
			alarm_beat_timer -= delta
			if alarm_beat_timer <= 0.0:
				alarm_beat_timer = 60.0 / alarm_bpm
				alarm_audio_player.pitch_scale = lerpf(0.95, 1.25, danger)
				alarm_audio_player.play()
		else:
			alarm_audio_player.stop()
			alarm_beat_timer = 0.0

func _create_fallback_oneshot_wav(sound_type: String) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.22
	if sound_type == "thud":
		duration = 0.38
	elif sound_type == "scare":
		duration = 0.55

	var total_samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(mix_rate)
		var sig: float = 0.0
		match sound_type:
			"click":
				var env: float = exp(-t * 65.0)
				var beep: float = sin(t * 1450.0 * TAU) * 0.55 + sin(t * 2900.0 * TAU) * 0.25
				var tick: float = randf_range(-1.0, 1.0) * exp(-t * 140.0) * 0.45
				sig = clampf((beep + tick) * env, -1.0, 1.0) * 0.75
			"alarm":
				var env: float = exp(-t * 14.0)
				var freq: float = lerpf(780.0, 520.0, t / duration)
				sig = clampf(sin(t * freq * TAU) * 2.5, -1.0, 1.0) * env * 0.35
			"thud":
				# Golpe metálico grave cuando el monstruo golpea la puerta cerrada y se va
				var env: float = exp(-t * 11.0)
				var sub: float = sin(t * lerpf(115.0, 38.0, t / duration) * TAU) * 0.85
				var clang: float = sin(t * 280.0 * TAU) * exp(-t * 28.0) * 0.45
				var noise: float = randf_range(-1.0, 1.0) * exp(-t * 32.0) * 0.5
				sig = clampf((sub + clang + noise) * env, -1.0, 1.0) * 0.85
			"scare":
				# Chillido de interferencia de la Niña Fantasma
				var env: float = exp(-t * 4.5)
				var shriek: float = sin(t * (1350.0 + sin(t * 65.0) * 420.0) * TAU) * 0.55
				var static_n: float = randf_range(-1.0, 1.0) * 0.65
				sig = clampf((shriek + static_n) * env, -1.0, 1.0) * 0.75
			"flash":
				var env: float = exp(-t * 16.0)
				var zap: float = sin(t * lerpf(1800.0, 420.0, t / duration) * TAU) * 0.5
				sig = (zap + randf_range(-0.4, 0.4)) * env * 0.5
			_:
				var env: float = exp(-t * 18.0)
				var blade_hum: float = sin(t * 95.0 * TAU) * 0.65
				var air_whoosh: float = randf_range(-1.0, 1.0) * 0.55
				sig = (blade_hum + air_whoosh) * env * 0.45

		var pcm16: int = clampi(int(sig * 32767.0), -32768, 32767)
		data[i * 2] = pcm16 & 0xFF
		data[i * 2 + 1] = (pcm16 >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

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
	monster_hack_progress = randf_range(10.0, 22.0)
	monster_is_moving = true
	door_hold_timer = 0.0
	door_hold_target_time = -1.0

	if door_node_states.get(target_node, "OPEN") == "LOCKED" and power_energy > 0.0:
		door_hold_target_time = randf_range(2.5, 6.5)
		monster_is_moving = false

	# No se revela gratis: necesitás mirarlo con el Flash o en cámara
	monster_spotted_on_cam = (selected_cam_id == target_node and camera_disabled_timer <= 0.0 and not light_hacked_by_monster)

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
	vn_lbl_affinity_chip.text = "♥ BOND: 50%"
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

	vn_speaker_badge = _create_badge_label("MIA", Color("#05080d"), Color("#b829ff"))
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
# 3. CONSTRUCCIÓN DE LA CONSOLA DE OPERADOR
# =========================================================
func _build_universal_ui() -> void:
	clip_contents = true

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
	var root_split = HSplitContainer.new()
	root_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_split.add_theme_constant_override("separation", 10)
	screen_bezel_frame.add_child(root_split)
	main_vbox.size_flags_stretch_ratio = 1.08
	root_split.add_child(main_vbox)

	# --- HEADER SUPERIOR ---
	var header = _create_cyber_panel(Color("#0c0e10"), Color("#d9382e"), 2, 7)
	main_vbox.add_child(header)
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	header.add_child(header_vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	header_vbox.add_child(header_hbox)

	var right_top_bar = HFlowContainer.new()
	right_top_bar.add_theme_constant_override("h_separation", 8)
	right_top_bar.add_theme_constant_override("v_separation", 6)

	var badge = _create_badge_label("▲ FACILITY STATUS: CRITICAL", Color("#ffffff"), Color("#d9382e"))
	header_hbox.add_child(badge)

	var title = Label.new()
	title.text = "////  SUBJECT-ZERO + PHANTOM ANOMALY"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color("#d9382e")
	header_hbox.add_child(title)

	lbl_sector = Label.new()
	lbl_sector.text = "SI VES A LA NIÑA EN CÁMARA, CAMBIÁ DE CÁMARA EN <1.4s"
	lbl_sector.modulate = Color("#88aacc")
	lbl_sector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_hbox.add_child(lbl_sector)
	lbl_sector.visible = false  # UI limpia: aviso de la niña

	var btn_open_vn = Button.new()
	btn_open_vn.text = "🎭 VN INTRO"
	_apply_styled_button(btn_open_vn, Color("#b829ff"), false)
	btn_open_vn.pressed.connect(func(): load_mission(current_mission, true))
	right_top_bar.add_child(btn_open_vn)

	var lbl_sel = Label.new()
	lbl_sel.text = "COMPAÑERA:"
	lbl_sel.modulate = Color("#88aacc")
	right_top_bar.add_child(lbl_sel)

	mission_selector = OptionButton.new()
	mission_selector.fit_to_longest_item = false
	mission_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mission_selector.custom_minimum_size = Vector2(155, 28)
	mission_selector.item_selected.connect(func(idx): load_mission(available_missions[idx], start_in_vn_mode))
	right_top_bar.add_child(mission_selector)

	var btn_restart = Button.new()
	btn_restart.text = "↻ REINICIAR"
	btn_restart.custom_minimum_size = Vector2(0, 40)
	_apply_styled_button(btn_restart, Color("#00f0ff"), false)
	btn_restart.pressed.connect(func(): load_mission(current_mission, false))
	right_top_bar.add_child(btn_restart)

	var btn_help = Button.new()
	btn_help.text = "❓ AYUDA"
	btn_help.custom_minimum_size = Vector2(0, 40)
	btn_help.tooltip_text = "Cómo se juega: qué hace cada botón y qué hacer en cada situación"
	_apply_styled_button(btn_help, Color("#ffcc44"), false)
	btn_help.pressed.connect(_show_help_dialog)
	right_top_bar.add_child(btn_help)

	lbl_timer = Label.new()
	lbl_timer.text = "12:00 AM (180s)"
	lbl_timer.add_theme_font_size_override("font_size", 15)
	lbl_timer.modulate = Color("#00ff9d")
	lbl_timer.add_theme_font_size_override("font_size", 18)
	right_top_bar.add_child(lbl_timer)

	bar_trace = ProgressBar.new()
	bar_trace.custom_minimum_size = Vector2(0, 4)
	bar_trace.show_percentage = false
	_style_progress_bar(bar_trace, Color("#121c29"), Color("#00ff9d"))
	header_vbox.add_child(bar_trace)

	var monster_hbox = HBoxContainer.new()
	monster_hbox.add_theme_constant_override("separation", 10)
	header_vbox.add_child(monster_hbox)
	monster_hbox.visible = false  # UI limpia: fila CÁMARAS EN LÍNEA / CONTENCIONES

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
	lbl_hack_alert_banner.text = "🚨 ¡ALERTA DE SABOTAJE! SISTEMAS HACKEADOS"
	lbl_hack_alert_banner.add_theme_font_size_override("font_size", 13)
	lbl_hack_alert_banner.modulate = Color("#ffccd5")
	lbl_hack_alert_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_hack_alert_banner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	alert_hbox.add_child(lbl_hack_alert_banner)

	btn_hack_alert_goto = Button.new()
	btn_hack_alert_goto.text = "🛠️ IR A REPARAR >>"
	btn_hack_alert_goto.custom_minimum_size = Vector2(170, 44)
	btn_hack_alert_goto.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_hack_alert_goto, Color("#ff1744"), true)
	btn_hack_alert_goto.pressed.connect(_on_hack_alert_goto_pressed)
	alert_hbox.add_child(btn_hack_alert_goto)

	# --- BARRA DE GUÍA: SIEMPRE DICE QUÉ HACER AHORA ---
	guide_panel = PanelContainer.new()
	guide_style = StyleBoxFlat.new()
	guide_style.bg_color = Color(0.04, 0.10, 0.08, 0.96)
	guide_style.border_color = Color("#00ff9d")
	guide_style.set_border_width_all(2)
	guide_style.border_width_left = 6
	guide_style.set_corner_radius_all(4)
	guide_style.set_content_margin_all(8)
	guide_panel.add_theme_stylebox_override("panel", guide_style)
	guide_panel.custom_minimum_size = Vector2(0, 86)   # alto FIJO: evita que los botones de abajo se muevan
	guide_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	guide_panel.clip_contents = true
	main_vbox.add_child(guide_panel)

	var guide_hbox = HBoxContainer.new()
	guide_hbox.add_theme_constant_override("separation", 10)
	guide_panel.add_child(guide_hbox)

	var guide_vbox = VBoxContainer.new()
	guide_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_vbox.add_theme_constant_override("separation", 2)
	guide_hbox.add_child(guide_vbox)

	lbl_guide_title = Label.new()
	lbl_guide_title.text = "✅ TODO ESTABLE"
	lbl_guide_title.add_theme_font_size_override("font_size", 18)
	lbl_guide_title.clip_text = true                    # ancho fijo: no empuja la columna
	lbl_guide_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_guide_title.custom_minimum_size = Vector2(0, 26)
	guide_vbox.add_child(lbl_guide_title)

	lbl_guide_text = Label.new()
	lbl_guide_text.text = ""
	lbl_guide_text.add_theme_font_size_override("font_size", 14)
	lbl_guide_text.modulate = Color("#d8dfdc")
	lbl_guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_guide_text.custom_minimum_size = Vector2(120, 38)
	lbl_guide_text.max_lines_visible = 2               # alto fijo: máximo 2 líneas
	lbl_guide_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	guide_vbox.add_child(lbl_guide_text)

	lbl_guide_goal = Label.new()
	lbl_guide_goal.add_theme_font_size_override("font_size", 14)
	lbl_guide_goal.modulate = Color("#b829ff")
	lbl_guide_goal.tooltip_text = "Objetivo: contener a Subject-Zero con las compuertas / sobrevivir hasta las 6 AM"
	lbl_guide_goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_guide_goal.visible = false  # UI limpia: sin contador de contenciones
	guide_hbox.add_child(lbl_guide_goal)

	btn_guide_action = Button.new()
	btn_guide_action.custom_minimum_size = Vector2(150, 48)
	btn_guide_action.clip_text = true
	btn_guide_action.add_theme_font_size_override("font_size", 15)
	btn_guide_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_guide_action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_guide_action, Color("#ffaa00"), true)
	btn_guide_action.visible = false
	btn_guide_action.pressed.connect(func():
		if guide_action_tab >= 0 and is_instance_valid(tab_container):
			tab_container.current_tab = guide_action_tab)
	guide_hbox.add_child(btn_guide_action)

	# --- SPLIT CENTRAL ---

	# COLUMNA IZQUIERDA
	var left_vbox = VBoxContainer.new()
	left_vbox.clip_contents = true
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.08
	left_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(left_vbox)

	var monitor_panel = _create_cyber_panel(Color("#080d14"), Color("#1e3246"), 1, 8)
	monitor_panel.custom_minimum_size = Vector2(280, 260)
	monitor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_panel.size_flags_stretch_ratio = 3.2
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
	lbl_codename.text = "ID: ORACLE-01"
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
	mia_portrait_frame.custom_minimum_size = Vector2(170, 0)
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

	# --- REPRODUCTOR DE VIDEO DE COMPAÑERA (768x1376 SIN ESTIRAR) ---
	var companion_video_aspect = AspectRatioContainer.new()
	companion_video_aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	companion_video_aspect.ratio = 768.0 / 1376.0
	companion_video_aspect.stretch_mode = AspectRatioContainer.STRETCH_COVER
	companion_video_aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mia_portrait_layer.add_child(companion_video_aspect)

	companion_video_player = VideoStreamPlayer.new()
	companion_video_player.expand = true
	companion_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	companion_video_player.visible = false
	companion_video_player.finished.connect(_on_companion_video_finished)
	companion_video_aspect.add_child(companion_video_player)

	# --- NUEVO: ESTÁTICA DE TRANSICIÓN AL HACKEAR / REPARAR TERMINAL ---
	companion_static_burst_rect = ColorRect.new()
	companion_static_burst_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	companion_static_burst_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	companion_static_burst_rect.material = _create_fnaf_static_burst_material()
	companion_static_burst_rect.visible = false
	mia_portrait_layer.add_child(companion_static_burst_rect)

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
	lbl_mia_hearts.text = "♥♥♥"
	lbl_mia_hearts.add_theme_font_size_override("font_size", 11)
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

	# --- MONITOR PREVIZ 3D DE CÁMARA DE SEGURIDAD +NIÑA FANTASMA ---
	var previz_3d_panel = _build_3d_camera_previz()
	monitor_hbox.add_child(previz_3d_panel)

	# --- MAPA INTERACTIVO 3 - 2 - 2 - 1 ---
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

	# BARRA DE CÁMARAS + BOTÓN RÁPIDO DE FLASH EN EL MONITOR
	var cam_bar_hbox = HBoxContainer.new()
	cam_bar_hbox.add_theme_constant_override("separation", 4)
	monitor_vbox.add_child(cam_bar_hbox)

	var lbl_cam_bar = Label.new()
	lbl_cam_bar.text = "🎥 CAM:"
	lbl_cam_bar.add_theme_font_size_override("font_size", 11)
	lbl_cam_bar.modulate = Color("#88ccee")
	cam_bar_hbox.add_child(lbl_cam_bar)

	cam_select_buttons.clear()
	for cam_id in CAM_NODE_IDS:
		var c_btn = Button.new()
		c_btn.text = "C" + cam_id
		c_btn.custom_minimum_size = Vector2(0, 46)
		c_btn.add_theme_font_size_override("font_size", 15)
		c_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_btn.clip_text = true
		c_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c_btn.pressed.connect(func(): _select_camera(cam_id))
		cam_bar_hbox.add_child(c_btn)
		cam_select_buttons[cam_id] = c_btn

	btn_quick_flash = Button.new()
	btn_quick_flash.text = "🔦 FLASH (-6%⚡)"
	btn_quick_flash.custom_minimum_size = Vector2(150, 46)
	btn_quick_flash.add_theme_font_size_override("font_size", 15)
	btn_quick_flash.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_quick_flash, Color("#00ff9d"), true)
	btn_quick_flash.pressed.connect(_on_hallway_light_pressed)
	btn_quick_flash.tooltip_text = "Ahuyenta a Subject-Zero en C1–C3. En C4 solo lo frena. ¡NUNCA en la cámara de la Niña!"
	cam_bar_hbox.add_child(btn_quick_flash)

	# --- PANEL INFERIOR: ENERGÍA + TEMPERATURA ---
	var bio_panel = _create_cyber_panel(Color("#0a1018"), Color("#1c2d3f"), 2, 12)
	bio_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bio_panel.size_flags_stretch_ratio = 1.0
	left_vbox.add_child(bio_panel)

	matrix_stream_panel = PanelContainer.new()
	matrix_stream_style = StyleBoxFlat.new()
	matrix_stream_style.bg_color = Color(0.02, 0.05, 0.04, 0.96)
	matrix_stream_style.border_color = Color("#00ff9d")
	matrix_stream_style.set_border_width_all(1)
	matrix_stream_style.border_width_top = 2
	matrix_stream_style.set_corner_radius_all(3)
	matrix_stream_style.set_content_margin_all(6)
	matrix_stream_panel.add_theme_stylebox_override("panel", matrix_stream_style)
	matrix_stream_panel.custom_minimum_size = Vector2(0, 90)
	matrix_stream_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matrix_stream_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	matrix_stream_panel.size_flags_stretch_ratio = 0.68
	matrix_stream_panel.clip_contents = true
	left_vbox.add_child(matrix_stream_panel)

	matrix_rain_canvas = Control.new()
	matrix_rain_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matrix_rain_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	matrix_rain_canvas.clip_contents = true
	matrix_rain_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	matrix_rain_canvas.draw.connect(_draw_companion_matrix_stream)
	matrix_rain_canvas.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var matrix_pending: bool = (target_sequence.size() > 0 and entered_sequence.size() < target_sequence.size())
			if (not companion_pc_unlocked or temp_hacked_by_monster or matrix_pending) and is_instance_valid(tab_container):
				tab_container.current_tab = 2
	)
	matrix_stream_panel.add_child(matrix_rain_canvas)

	var bio_vbox = VBoxContainer.new()
	bio_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bio_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bio_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bio_vbox.add_theme_constant_override("separation", 10)
	bio_panel.add_child(bio_vbox)

	var gauges_hbox = HBoxContainer.new()
	gauges_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauges_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gauges_hbox.add_theme_constant_override("separation", 12)
	bio_vbox.add_child(gauges_hbox)

	var nrg_card = _create_cyber_panel(Color("#070c12"), Color("#2bbd7e"), 2, 10)
	nrg_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrg_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gauges_hbox.add_child(nrg_card)

	var nrg_vbox = VBoxContainer.new()
	nrg_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nrg_vbox.add_theme_constant_override("separation", 6)
	nrg_card.add_child(nrg_vbox)

	var nrg_top = HBoxContainer.new()
	nrg_vbox.add_child(nrg_top)

	var lbl_nrg_title = Label.new()
	lbl_nrg_title.text = "⚡ ENERGÍA RESTANTE"
	lbl_nrg_title.add_theme_font_size_override("font_size", 13)
	lbl_nrg_title.modulate = Color("#aaddff")
	lbl_nrg_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrg_top.add_child(lbl_nrg_title)

	lbl_energy_val = Label.new()
	lbl_energy_val.text = "100%"
	lbl_energy_val.add_theme_font_size_override("font_size", 22)
	lbl_energy_val.modulate = Color("#00ff9d")
	nrg_top.add_child(lbl_energy_val)

	bar_energy = ProgressBar.new()
	bar_energy.max_value = 100.0
	bar_energy.value = 100.0
	bar_energy.custom_minimum_size = Vector2(0, 18)
	bar_energy.show_percentage = false
	_style_progress_bar(bar_energy, Color("#101b24"), Color("#00ff9d"))
	nrg_vbox.add_child(bar_energy)

	var tmp_card = _create_cyber_panel(Color("#070c12"), Color("#00f0ff"), 2, 10)
	tmp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tmp_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gauges_hbox.add_child(tmp_card)

	var tmp_vbox = VBoxContainer.new()
	tmp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tmp_vbox.add_theme_constant_override("separation", 6)
	tmp_card.add_child(tmp_vbox)

	var tmp_top = HBoxContainer.new()
	tmp_vbox.add_child(tmp_top)

	var lbl_tmp_title = Label.new()
	lbl_tmp_title.text = "🌡️ TEMPERATURA SALA"
	lbl_tmp_title.add_theme_font_size_override("font_size", 13)
	lbl_tmp_title.modulate = Color("#aaddff")
	lbl_tmp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tmp_top.add_child(lbl_tmp_title)

	lbl_temp_val = Label.new()
	lbl_temp_val.text = "24°C"
	lbl_temp_val.add_theme_font_size_override("font_size", 22)
	lbl_temp_val.modulate = Color("#00f0ff")
	tmp_top.add_child(lbl_temp_val)

	bar_temperature = ProgressBar.new()
	bar_temperature.min_value = 20.0
	bar_temperature.max_value = 100.0
	bar_temperature.value = 24.0
	bar_temperature.custom_minimum_size = Vector2(0, 18)
	bar_temperature.show_percentage = false
	_style_progress_bar(bar_temperature, Color("#101b24"), Color("#00f0ff"))
	tmp_vbox.add_child(bar_temperature)

	var bio_header = HBoxContainer.new()
	bio_header.add_theme_constant_override("separation", 8)
	bio_vbox.add_child(bio_header)

	lbl_affinity = Label.new()
	lbl_affinity.modulate = Color("#00f0ff")
	lbl_affinity.add_theme_font_size_override("font_size", 12)
	lbl_affinity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_affinity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bio_header.add_child(lbl_affinity)

	lbl_companion_hack_status = Label.new()
	lbl_companion_hack_status.text = "👩‍💻 RADAR: ACTIVO"
	lbl_companion_hack_status.add_theme_font_size_override("font_size", 12)
	lbl_companion_hack_status.modulate = Color("#00ff9d")
	bio_header.add_child(lbl_companion_hack_status)

	lbl_perk_status = Label.new()
	lbl_perk_status.text = "🔮 PERK LISTO"
	lbl_perk_status.add_theme_font_size_override("font_size", 12)
	lbl_perk_status.modulate = Color("#f600ff")
	bio_header.add_child(lbl_perk_status)

	bar_affinity = ProgressBar.new()
	bar_affinity.max_value = 100
	bar_affinity.custom_minimum_size = Vector2(0, 5)
	bar_affinity.show_percentage = false
	_style_progress_bar(bar_affinity, Color("#121d2b"), Color("#00f0ff"))
	bio_vbox.add_child(bar_affinity)

	var bottom_actions_hbox = HBoxContainer.new()
	bottom_actions_hbox.add_theme_constant_override("separation", 8)
	bio_vbox.add_child(bottom_actions_hbox)

	btn_companion_perk = Button.new()
	btn_companion_perk.text = "🔮 USAR HABILIDAD DE COMPAÑERA"
	btn_companion_perk.custom_minimum_size = Vector2(0, 58)
	btn_companion_perk.add_theme_font_size_override("font_size", 16)
	btn_companion_perk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_companion_perk.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_companion_perk.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_companion_perk, Color("#f600ff"), true)
	btn_companion_perk.pressed.connect(_on_companion_perk_pressed)
	bottom_actions_hbox.add_child(btn_companion_perk)

	btn_continue_vn = Button.new()
	btn_continue_vn.text = "🎭 VER EPÍLOGO (NOVELA VISUAL) >>"
	btn_continue_vn.custom_minimum_size = Vector2(0, 52)
	btn_continue_vn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_continue_vn, Color("#00ff9d"), true)
	btn_continue_vn.visible = false
	btn_continue_vn.pressed.connect(_launch_outro_vn)
	bio_vbox.add_child(btn_continue_vn)

	# COLUMNA DERECHA
	var right_vbox = VBoxContainer.new()
	right_vbox.clip_contents = true
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.92
	right_vbox.add_theme_constant_override("separation", 8)
	root_split.add_child(right_vbox)

	# Barra superior de la columna derecha: reloj, compañera, reiniciar, ayuda
	var right_top_panel = _create_cyber_panel(Color("#0c0e10"), Color("#2c3235"), 1, 6)
	right_vbox.add_child(right_top_panel)
	right_top_panel.add_child(right_top_bar)
	right_top_bar.move_child(lbl_timer, 0)

	tab_container = TabContainer.new()
	tab_container.clip_contents = true
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tab_container(tab_container)
	right_vbox.add_child(tab_container)

	tab_container.add_child(_build_turbine_tab())
	tab_container.add_child(_build_light_and_knobs_tab())
	tab_container.add_child(_build_hacking_minigame_tab())

	# PANEL DE CONTROL DE PUERTA BLINDADA (MÁXIMO 1 ACTIVA A LA VEZ)
	var term_panel = _create_cyber_panel(Color("#0c131f"), Color("#00f0ff"), 2, 10)
	term_panel.clip_contents = true
	right_vbox.add_child(term_panel)

	var term_vbox = VBoxContainer.new()
	term_vbox.add_theme_constant_override("separation", 6)
	term_panel.add_child(term_vbox)

	var term_header_hbox = HBoxContainer.new()
	term_header_hbox.add_theme_constant_override("separation", 8)
	term_vbox.add_child(term_header_hbox)
	term_header_hbox.visible = false  # UI limpia: título COMPUERTA MAGNÉTICA

	var lbl_term = Label.new()
	lbl_term.text = "🚪 COMPUERTA MAGNÉTICA (1 SOLA ACTIVA A LA VEZ // ESCUCHÁ EL GOLPE)"
	lbl_term.modulate = Color("#00f0ff")
	lbl_term.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_term.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	term_header_hbox.add_child(lbl_term)

	lbl_code_progress_status = Label.new()
	lbl_code_progress_status.text = "PUERTA: ABIERTA"
	lbl_code_progress_status.modulate = Color("#00ff9d")
	lbl_code_progress_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	term_header_hbox.add_child(lbl_code_progress_status)

	lock_banner = _create_cyber_panel(Color("#1b111c"), Color("#ffaa00"), 1, 5)
	term_vbox.add_child(lock_banner)
	lock_banner.visible = false  # UI limpia: texto de ayuda de la compuerta

	lbl_lock_banner = Label.new()
	lbl_lock_banner.text = "En C1..C3 usá el [🔦 FLASH] para ahuyentar a Subject-Zero. Cuando llegue a C4 (o esté por romper tu pasillo), cerrá su compuerta y esperá a escuchar el golpe metálico."
	lbl_lock_banner.modulate = Color("#ffcc44")
	lbl_lock_banner.add_theme_font_size_override("font_size", 11)
	lbl_lock_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_lock_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_banner.add_child(lbl_lock_banner)

	var hbox_btns = HBoxContainer.new()
	hbox_btns.add_theme_constant_override("separation", 6)
	term_vbox.add_child(hbox_btns)

	btn_inject = Button.new()
	btn_inject.custom_minimum_size = Vector2(0, 64)
	btn_inject.add_theme_font_size_override("font_size", 18)
	btn_inject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_inject.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_inject.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_inject, Color("#00f0ff"), true)
	btn_inject.pressed.connect(_on_seal_door_choice_pressed)
	btn_inject.tooltip_text = "Cierra/abre la compuerta de la cámara elegida. Solo 1 a la vez y gasta energía."
	hbox_btns.add_child(btn_inject)

	btn_open_all_doors = Button.new()
	btn_open_all_doors.text = "🔓 ABRIR PUERTA (AHORRAR ⚡)"
	btn_open_all_doors.custom_minimum_size = Vector2(145, 40)
	btn_open_all_doors.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_open_all_doors.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_open_all_doors, Color("#ffaa00"), false)
	btn_open_all_doors.pressed.connect(_on_open_all_doors_pressed)
	hbox_btns.add_child(btn_open_all_doors)
	btn_open_all_doors.visible = false  # el botón principal ya alterna CERRAR/ABRIR

	# UI limpia: etiqueta de compañera, fila de vínculo/radar/rastreo y su barra
	if is_instance_valid(lbl_codename):
		lbl_codename.visible = false
	if is_instance_valid(lbl_affinity) and lbl_affinity.get_parent():
		lbl_affinity.get_parent().visible = false
	if is_instance_valid(bar_affinity):
		bar_affinity.visible = false

	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_second_tick)
	add_child(game_timer)

# =========================================================
# 4A. TAB 01: TURBINA (MANTENER PRESIONADO CON RIESGO DE RUIDO)
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
	lbl_mb_title.text = "🌀 TURBINA DE REFRIGERACIÓN (MANTENER PRESIONADO)"
	lbl_mb_title.modulate = Color("#00f0ff")
	lbl_mb_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_mb_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_hbox.add_child(lbl_mb_title)

	lbl_music_status = Label.new()
	lbl_music_status.text = "🌀 RPM: 90%"
	lbl_music_status.modulate = Color("#00ff9d")
	top_hbox.add_child(lbl_music_status)

	var lbl_desc = Label.new()
	lbl_desc.text = "• MANTENÉ APRETADO el botón de abajo para dar cuerda a la turbina (>40%).\n• ¡CUIDADO!: Si el búnker pasa de 45°C, la Niña Fantasma aparece mucho más seguido en las cámaras. Y si acelerás la turbina cuando Subject-Zero está en Nivel 3 o 4, el ruido lo atrae más rápido."
	lbl_desc.modulate = Color("#99badd")
	lbl_desc.add_theme_font_size_override("font_size", 11)
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
	lbl_music_beast_state.add_theme_font_size_override("font_size", 13)
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
	btn_wind_music.text = "🌀 MANTENER APRETADO PARA ACELERAR TURBINA (+28% RPM/s)"
	btn_wind_music.custom_minimum_size = Vector2(0, 76)
	btn_wind_music.add_theme_font_size_override("font_size", 17)
	btn_wind_music.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_wind_music.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_wind_music, Color("#00ff9d"), true)
	btn_wind_music.tooltip_text = "Mantené apretado para subir la turbina. Debajo de 40% la sala se calienta."
	btn_wind_music.button_down.connect(func(): is_holding_turbine_btn = true)
	btn_wind_music.button_up.connect(func(): is_holding_turbine_btn = false)
	btn_wind_music.mouse_exited.connect(func(): is_holding_turbine_btn = false)
	vbox.add_child(btn_wind_music)

	var nav_hbox = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 10)
	nav_hbox.visible = false  # UI limpia: botones IR A ÓPTICA / DESBLOQUEAR RADAR
	vbox.add_child(nav_hbox)

	var btn_to_tab2 = Button.new()
	btn_to_tab2.text = "🎛️ IR A ÓPTICA Y PERILLAS [TAB 02] >>"
	btn_to_tab2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_to_tab2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_styled_button(btn_to_tab2, Color("#00f0ff"), false)
	btn_to_tab2.pressed.connect(func(): tab_container.current_tab = 1)
	nav_hbox.add_child(btn_to_tab2)

	var btn_to_tab3 = Button.new()
	btn_to_tab3.text = "💻 DESBLOQUEAR RADAR [TAB 03] >>"
	btn_to_tab3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_to_tab3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_styled_button(btn_to_tab3, Color("#f600ff"), false)
	btn_to_tab3.pressed.connect(func(): tab_container.current_tab = 2)
	nav_hbox.add_child(btn_to_tab3)

	return wrapper

func _update_turbine_ui() -> void:
	if is_instance_valid(bar_music_box):
		bar_music_box.value = music_box_charge

	var turbine_ok: bool = (music_box_charge >= 40.0 and power_energy > 0.0)
	if is_instance_valid(lbl_music_status):
		lbl_music_status.text = ("🌀 ACTIVA: %d%%" % int(music_box_charge)) if turbine_ok else ("🚨 CAÍDA (<40%%): %d%%" % int(music_box_charge))
		lbl_music_status.modulate = Color("#00ff9d") if turbine_ok else Color("#ff1744")

	if is_instance_valid(lbl_music_beast_state):
		if is_holding_turbine_btn:
			lbl_music_beast_state.text = "⚡ ACELERANDO TURBINA (%d%%)... ¡CUIDADO CON EL RUIDO SI ESTÁ CERCA!" % int(music_box_charge)
			lbl_music_beast_state.modulate = Color("#00f0ff")
		elif not turbine_ok:
			lbl_music_beast_state.text = "🚨 ¡TURBINA PARADA! CALOR SUBIENDO (%d°C) Y APARICIONES FANTASMA ACTIVAS!" % int(bunker_temperature)
			lbl_music_beast_state.modulate = Color("#ff1744")
		else:
			lbl_music_beast_state.text = "🌀 TURBINA REFRIGERANDO (%d%%) — TEMP: %d°C  |  ENERGÍA: %d%%" % [int(music_box_charge), int(bunker_temperature), int(power_energy)]
			lbl_music_beast_state.modulate = Color("#00ff9d")

	if is_instance_valid(btn_wind_music):
		btn_wind_music.text = "⚡ CARGANDO TURBINA... (SOLTÁ PARA SILENCIAR)" if is_holding_turbine_btn else "🌀 MANTENER APRETADO PARA IMPULSAR TURBINA (>40%)"
		_apply_styled_button(btn_wind_music, Color("#00f0ff") if is_holding_turbine_btn else (Color("#00ff9d") if turbine_ok else Color("#ff1744")), true)

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
	var col = Color("#00f0ff") if is_holding_turbine_btn else (Color("#00ff9d") if turbine_ok else Color("#ff1744"))

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
# 4B. TAB 02: CALIBRACIÓN DE PERILLAS (RECUPERA VIDEO ANTE LA NIÑA)
# =========================================================
func _build_light_and_knobs_tab() -> Control:
	var wrapper = _create_doc_tab_wrapper()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	wrapper.add_child(vbox)

	lbl_lure_title = Label.new()
	lbl_lure_title.text = "🎛️ CALIBRACIÓN DE VIDEO Y FLASH (ANTI-PHANTOM)"
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

	lbl_sys_video_badge = _create_badge_label("🎥 VIDEO: ONLINE", Color("#05080d"), Color("#00ff9d"))
	sys_hbox.add_child(lbl_sys_video_badge)

	lbl_sys_door_badge = _create_badge_label("💻 RADAR: OK", Color("#05080d"), Color("#00ff9d"))
	sys_hbox.add_child(lbl_sys_door_badge)

	lbl_lure_selected_cam = Label.new()
	lbl_lure_selected_cam.text = "🎥 PASILLO APUNTADO: [ CAM C1 ]"
	lbl_lure_selected_cam.modulate = Color("#ffcc00")
	lbl_lure_selected_cam.add_theme_font_size_override("font_size", 12)
	lbl_lure_selected_cam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(lbl_lure_selected_cam)

	lbl_lure_hint = Label.new()
	lbl_lure_hint.text = "• Si te quedás mirando a la NIÑA FANTASMA en una cámara (>1.4s) o le tirás el Flash encima, ella INHABILITA TU PANTALLA DE CÁMARAS.\n• Girá las 4 PERILLAS a sus marcas verdes META para restaurar el video y el Flash de inmediato."
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
		k_canvas.custom_minimum_size = Vector2(84, 84)
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
		b_left.custom_minimum_size = Vector2(48, 42)
		_apply_styled_button(b_left, Color("#00f0ff"), false)
		b_left.pressed.connect(func(): _rotate_knob(bound_idx, -1))
		k_btns.add_child(b_left)

		var b_right = Button.new()
		b_right.text = "▶"
		b_right.custom_minimum_size = Vector2(48, 42)
		_apply_styled_button(b_right, Color("#00f0ff"), false)
		b_right.pressed.connect(func(): _rotate_knob(bound_idx, 1))
		k_btns.add_child(b_right)

	btn_hallway_light = Button.new()
	btn_hallway_light.text = "🔦 DISPARAR FLASH EN [CAM C1] (-6% ENERGÍA // AHUYENTA A SUBJECT-ZERO)"
	btn_hallway_light.custom_minimum_size = Vector2(0, 66)
	btn_hallway_light.add_theme_font_size_override("font_size", 16)
	btn_hallway_light.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_hallway_light.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styled_button(btn_hallway_light, Color("#00ff9d"), true)
	btn_hallway_light.pressed.connect(_on_hallway_light_pressed)
	vbox.add_child(btn_hallway_light)

	btn_goto_reboot = Button.new()
	btn_goto_reboot.text = "💻 ¡RADAR DE COMPAÑERA BLOQUEADO! IR A TAB 03 >>"
	btn_goto_reboot.custom_minimum_size = Vector2(0, 54)
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
	camera_disabled_timer = 0.0
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

	if all_aligned and (light_hacked_by_monster or camera_disabled_timer > 0.0):
		light_hacked_by_monster = false
		camera_disabled_timer = 0.0
		ghost_jumpscare_flash = 0.0
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

# --- JUMPSCARE DE LA NIÑA FANTASMA Y BLOQUEO DE PANTALLA ---
func _trigger_ghost_girl_jumpscare(_reason: String) -> void:
	ghost_active_cam = ""
	ghost_stare_timer = 0.0
	ghost_encounters_count = 0
	ghost_forced_attack_timer = 0.0
	camera_disabled_timer = 9.0
	ghost_jumpscare_flash = 1.0
	_trigger_monster_light_knob_hack()

	# Penalización de pánico y turbina
	music_box_charge = max(0.0, music_box_charge - 20.0)
	mia_bpm = min(198, mia_bpm + 35)
	bpm = min(max_bpm, bpm + 20)
	mia_damage_flash = 0.85

	_reset_ghost_video()

	_update_mia_vitals_ui()
	_update_turbine_ui()
	_refresh_lure_tab_ui()
	_update_3d_previz(0.0)

func _on_hallway_light_pressed() -> void:
	if not game_active or flash_cooldown > 0.0 or ghost_jumpscare_playing:
		return
	if light_hacked_by_monster or camera_disabled_timer > 0.0:
		if is_instance_valid(tab_container):
			tab_container.current_tab = 1
		return
	if not companion_pc_unlocked:
		if is_instance_valid(tab_container):
			tab_container.current_tab = 2
		return

	# ¡TRAMPA!: Si disparás el Flash en la cámara donde está la Niña Fantasma, te ataca instantáneamente
	if ghost_active_cam != "" and selected_cam_id == ghost_active_cam:
		_begin_ghost_jumpscare("¡Le disparaste el Flash a la Niña Fantasma en [C%s]!" % selected_cam_id, true)
		return

	power_energy = max(0.0, power_energy - 6.0)
	flash_stun_grace = 1.15
	flash_cooldown = 0.8

	if is_instance_valid(light_audio_player) and light_audio_player.stream != null:
		light_audio_player.pitch_scale = randf_range(0.85, 1.05)
		light_audio_player.volume_db = -2.0
		light_audio_player.play()

	if not monster_attack_active:
		_update_energy_and_temp_hud()
		_refresh_lure_tab_ui()
		_update_3d_previz(0.0)
		return

	var actual_node = _get_monster_node_id()
	if selected_cam_id == actual_node:
		monster_spotted_on_cam = true
		monster_last_node_id = actual_node

		# En la puerta final C4, el Flash solo lo frena un poco (obligándote a usar la Puerta Blindada)
		if monster_security_level >= TOTAL_SECURITY_LEVELS:
			monster_hack_progress = max(0.0, monster_hack_progress - 22.0)
		else:
			# En los pasillos 1, 2 y 3 el Flash lo encandila y lo obliga a retroceder/ocultarse
			if monster_security_level > 1 and randf() < 0.65:
				monster_security_level -= 1
				monster_branch = _random_branch_for_level(monster_security_level)
			monster_attack_active = false
			monster_is_moving = false
			monster_spotted_on_cam = false
			monster_hack_progress = 0.0
			door_hold_timer = 0.0
			door_hold_target_time = -1.0
			monster_cooldown_timer = randf_range(4.0, 11.0)

	_update_energy_and_temp_hud()
	_refresh_lure_tab_ui()
	_update_terminal_lock_state()
	_update_hud()
	_update_3d_previz(0.0)

func _count_active_errors() -> int:
	var c: int = 0
	if light_hacked_by_monster or camera_disabled_timer > 0.0:
		c += 1
	if not companion_pc_unlocked:
		c += 1
	return c

func _on_hack_alert_goto_pressed() -> void:
	if not is_instance_valid(tab_container):
		return
	if light_hacked_by_monster or camera_disabled_timer > 0.0:
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
	var video_down: bool = (light_hacked_by_monster or camera_disabled_timer > 0.0)

	if is_instance_valid(lbl_sys_audio_badge):
		_update_badge_style(lbl_sys_audio_badge, "🌀 VENTILACIÓN", Color("#05080d"), Color("#00ff9d"))
	if is_instance_valid(lbl_sys_video_badge):
		_update_badge_style(lbl_sys_video_badge, "👻 VIDEO: ¡CAÍDO!" if video_down else "🎥 VIDEO: ONLINE", Color("#05080d"), Color("#ff1744") if video_down else Color("#00ff9d"))
	if is_instance_valid(lbl_sys_door_badge):
		_update_badge_style(lbl_sys_door_badge, "💻 RADAR: ACTIVO" if companion_pc_unlocked else "🔒 RADAR: ¡HACKEADO!", Color("#05080d"), Color("#00ff9d") if companion_pc_unlocked else Color("#ff1744"))

	if is_instance_valid(tab_container) and tab_container.get_tab_count() >= 3:
		tab_container.set_tab_title(0, "🌀 01_TURBINA")
		tab_container.set_tab_title(1, "🚨 02_ÓPTICA CAÍDA (!)" if video_down else "🎛️ 02_ÓPTICA / PERILLAS")
		tab_container.set_tab_title(2, "🚨 03_RADAR CAÍDO (!)" if not companion_pc_unlocked else "💻 03_RADAR COMPAÑERA")

	if is_instance_valid(hack_alert_banner):
		var hacked_parts: Array[String] = []
		if video_down:
			hacked_parts.append("👻 CÁMARAS INHABILITADAS POR PHANTOM [TAB 02]")
		if not companion_pc_unlocked:
			hacked_parts.append("💻 RADAR COMPAÑERA [TAB 03]")

		if hacked_parts.is_empty():
			hack_alert_banner.visible = false
		else:
			hack_alert_banner.visible = true
			lbl_hack_alert_banner.text = "🚨 ¡ALERTA!: " + "  +  ".join(hacked_parts)
			if video_down:
				btn_hack_alert_goto.text = "🎛️ CALIBRAR PERILLAS [TAB 02] >>"
			else:
				btn_hack_alert_goto.text = "💻 DESBLOQUEAR RADAR [TAB 03] >>"

	if is_instance_valid(lbl_lure_selected_cam):
		lbl_lure_selected_cam.text = "🎥 PASILLO APUNTADO: [ CAM C%s ]  |  ENERGÍA: %d%%" % [selected_cam_id, int(power_energy)]

	if is_instance_valid(btn_hallway_light):
		if video_down:
			btn_hallway_light.text = "🔒 ÓPTICA Y FLASH CAÍDOS — ALINEÁ LAS 4 PERILLAS ARRIBA"
			_apply_styled_button(btn_hallway_light, Color("#ff1744"), true)
		else:
			btn_hallway_light.text = "🔦 DISPARAR FLASH EN CAM C%s (-6%% ENERGÍA // ¡NO USAR EN LA NIÑA!)" % selected_cam_id
			_apply_styled_button(btn_hallway_light, Color("#00ff9d"), true)

	if is_instance_valid(btn_quick_flash):
		if video_down:
			btn_quick_flash.text = "🚨 VIDEO ERROR"
			_apply_styled_button(btn_quick_flash, Color("#ff1744"), true)
		else:
			btn_quick_flash.text = "🔦 FLASH C%s (-6%%)" % selected_cam_id
			_apply_styled_button(btn_quick_flash, Color("#00ff9d"), true)

	if is_instance_valid(btn_goto_reboot):
		btn_goto_reboot.visible = not companion_pc_unlocked

	if is_instance_valid(lbl_code_progress_status):
		var locked_cnt = _count_locked_doors()
		lbl_code_progress_status.text = "PUERTA ACTIVA: %d (-%0.1f%%⚡/s)" % [locked_cnt, float(locked_cnt) * 2.4]
		lbl_code_progress_status.modulate = Color("#ffaa00") if locked_cnt > 0 else Color("#00ff9d")

# =========================================================
# 4C. TAB 03: DESBLOQUEAR RADAR DE TU COMPAÑERA (MATRIZ HEX)
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
	lbl_breach_status.text = "💻 TERMINAL DE RADAR DE TU COMPAÑERA"
	lbl_breach_status.modulate = Color("#00f0ff")
	lbl_breach_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_breach_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_bar.add_child(lbl_breach_status)

	btn_reset_matrix = Button.new()
	btn_reset_matrix.text = "↻ NUEVA CLAVE"
	btn_reset_matrix.custom_minimum_size = Vector2(0, 44)
	_apply_styled_button(btn_reset_matrix, Color("#00f0ff"), false)
	btn_reset_matrix.pressed.connect(_on_manual_reset_matrix)
	top_bar.add_child(btn_reset_matrix)

	lbl_breach_hint = Label.new()
	lbl_breach_hint.text = "Cuando el radar de tu compañera está activo, ella marca en el mapa en qué NIVEL (1..4) se mueve Subject-Zero y desacelera su avance. ¡Si el monstruo lo bloquea, completá la secuencia Hex!"
	lbl_breach_hint.modulate = Color("#88aacc")
	lbl_breach_hint.add_theme_font_size_override("font_size", 11)
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
			btn.custom_minimum_size = Vector2(72, 54)
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
			monster_hack_progress = max(0.0, monster_hack_progress - 25.0)
			bpm = max(70, bpm - 12)
			_update_turbine_ui()
			_refresh_lure_tab_ui()
			_update_terminal_lock_state()
			_update_hud()
			_update_3d_previz(0.0)
		_refresh_matrix_ui()
		_update_companion_perk_ui()
	else:
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
	var header_label = "CÓDIGO DE DESBLOQUEO (%s):" % comp_name
	var target_str = "[b][color=#88aacc]%s[/color][/b]\n" % header_label
	if companion_pc_unlocked and not temp_hacked_by_monster and entered_sequence.size() >= target_sequence.size():
		target_str += "[color=#00ff9d][ RADAR ACTIVO — ESCANEANDO NIVEL ][/color]"
	else:
		for i in range(target_sequence.size()):
			if i < entered_sequence.size():
				target_str += "[b][color=#00ff9d][ %s ][/color][/b] " % target_sequence[i]
			elif i == entered_sequence.size() and can_interact:
				target_str += "[b][color=#f600ff][ 🔮%s ][/color][/b] " % target_sequence[i] if is_mia else "[b][color=#00f0ff][ %s ][/color][/b] " % target_sequence[i]
			else:
				target_str += "[color=#667788][ %s ][/color] " % target_sequence[i]
	lbl_target_seq.text = target_str

	var buf_str = "[b][color=#88aacc]ESTADO TERMINAL:[/color][/b]\n"
	if companion_pc_unlocked and not temp_hacked_by_monster and entered_sequence.size() >= target_sequence.size():
		buf_str += "[b][color=#00ff9d]✓ %s RASTREANDO EN EL MAPA[/color][/b]" % comp_name
		lbl_breach_status.text = "✓ RADAR DE %s ACTIVO" % comp_name
		lbl_breach_status.modulate = Color("#00ff9d")
	else:
		for t in entered_sequence:
			buf_str += "[b][color=#00ff9d]%s[/color][/b]  " % t
		for _i in range(target_sequence.size() - entered_sequence.size()):
			buf_str += "[color=#445566]__[/color]  "
		var mode_txt = ("FILA %d" % (active_index + 1)) if selecting_row else ("COLUMNA %d" % (active_index + 1))
		lbl_breach_status.text = "🔒 RADAR CAÍDO — ELEGÍ EN %s // PASO %d/%d" % [
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
			return "1A"
		elif branch == "B":
			return "1"
		else:
			return "1B"
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
	# Si ya está en la animación del 3er encuentro inevitable, no te deja cambiar de cámara
	if ghost_forced_attack_timer > 0.0 or ghost_jumpscare_playing:
		return

	if not CAM_NODE_IDS.has(cam_id):
		cam_id = "1"
	var previous_cam: String = selected_cam_id
	selected_cam_id = cam_id

	var video_ok: bool = (camera_disabled_timer <= 0.0 and not light_hacked_by_monster)

	# Si estabas viendo a la Niña Fantasma (1er o 2do cruce) y cambiaste a tiempo, desaparece
	if ghost_active_cam != "" and previous_cam == ghost_active_cam and selected_cam_id != ghost_active_cam:
		ghost_active_cam = ""
		ghost_stare_timer = 0.0

	# Probabilidad de que la Niña Fantasma aparezca en una cámara vacía al cambiar de canal
	var monster_node = _get_monster_node_id() if monster_attack_active else ""
	if game_active and video_ok and previous_cam != selected_cam_id:
		if selected_cam_id != monster_node and ghost_active_cam == "":
			var ghost_chance: float = 0.22
			if bunker_temperature >= 45.0:
				ghost_chance += 0.20
			if mia_bpm >= 135:
				ghost_chance += 0.12
			if randf() < ghost_chance:
				ghost_encounters_count += 1
				ghost_active_cam = selected_cam_id
				ghost_stare_timer = 0.0

				if is_instance_valid(ghost_laugh_player) and ghost_laugh_player.stream != null:
					ghost_laugh_player.pitch_scale = randf_range(0.92, 1.08)
					ghost_laugh_player.play()

				if ghost_encounters_count >= GHOST_MAX_ENCOUNTERS:
					if _ghost_video_available():
						# 3er encuentro: salta el clip idle y arranca directo en el jumpscare (1:00-2:00)
						_begin_ghost_jumpscare("¡3er encuentro con la Anomalía Fantasma en [C%s]!" % selected_cam_id, true)
					else:
						ghost_forced_attack_timer = 0.65
						if is_instance_valid(sfx_scare_player):
							sfx_scare_player.pitch_scale = 1.12
							sfx_scare_player.play()

	if monster_attack_active and selected_cam_id == monster_node and video_ok:
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
			if click_pos.distance_to(node_pos) <= 32.0:
				_select_camera(cam_id)
				break

# =========================================================
# VISOR 3D DE CÁMARA + MODELO 3D DE LA NIÑA FANTASMA
# =========================================================
func _auto_load_fnaf_hall_textures() -> void:
	var search_dirs: Array[String] = [
		"res://assets/cameras/",
		"res://assets/sprites/",
		"res://assets/backgrounds/",
		"res://assets/",
		"res://"
	]
	if not is_instance_valid(tex_cam_empty):
		tex_cam_empty = _find_hall_tex("hall1", search_dirs)
	if not is_instance_valid(tex_monster_stage_1):
		tex_monster_stage_1 = _find_hall_tex("hall1_m1", search_dirs)
	if not is_instance_valid(tex_monster_stage_2):
		tex_monster_stage_2 = _find_hall_tex("hall1_m2", search_dirs)
	if not is_instance_valid(tex_monster_stage_3):
		tex_monster_stage_3 = _find_hall_tex("hall1_m3", search_dirs)

func _find_hall_tex(base_name: String, dirs: Array[String]) -> Texture2D:
	for d in dirs:
		for ext in ["jpg", "png", "jpeg", "webp"]:
			var path: String = d + base_name + "." + ext
			var tex: Texture2D = _load_board_texture(path)
			if is_instance_valid(tex):
				return tex
	return null

func _build_3d_camera_previz() -> Control:
	_auto_load_fnaf_hall_textures()

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

	# Contenedor que hace el paneo horizontal de FNAF (aprovechando el formato widescreen de hall1.jpg)
	cam_pan_root = Control.new()
	cam_pan_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_pan_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cam_pan_root)

	# 1. Imagen principal del pasillo por estados (hall1, hall1_m1, hall1_m2, hall1_m3)
	cam_state_tex_rect = TextureRect.new()
	cam_state_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_state_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cam_state_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cam_state_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_state_tex_rect.texture = tex_cam_empty
	cam_pan_root.add_child(cam_state_tex_rect)

	# 1b. Video de la Niña Fantasma (1824x768). Va debajo del shader de lente, así hereda el paneo y la distorsión.
	_load_ghost_videos()
	ghost_video_container = AspectRatioContainer.new()
	ghost_video_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ghost_video_container.ratio = 1824.0 / 768.0
	ghost_video_container.stretch_mode = AspectRatioContainer.STRETCH_COVER
	ghost_video_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_video_container.visible = false
	cam_pan_root.add_child(ghost_video_container)

	ghost_video_player = VideoStreamPlayer.new()
	ghost_video_player.expand = true
	ghost_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_video_player.finished.connect(_on_ghost_video_finished)
	ghost_video_container.add_child(ghost_video_player)

	# 2. Overlay de la Niña Fantasma sobre el pasillo (si aparece en la cámara)
	cam_ghost_overlay = Control.new()
	cam_ghost_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_ghost_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_ghost_overlay.visible = false
	cam_ghost_overlay.draw.connect(_draw_ghost_over_hallway)
	cam_pan_root.add_child(cam_ghost_overlay)

	# 3. Overlay de Compuerta Magnética Cerrada (baja sobre hall1.jpg cuando bloqueás la cámara)
	cam_door_bars_overlay = Control.new()
	cam_door_bars_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_door_bars_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_door_bars_overlay.visible = false
	cam_door_bars_overlay.draw.connect(_draw_locked_door_over_hallway)
	layer.add_child(cam_door_bars_overlay)

	# 4. Shader FNAF: Estira los bordes laterales de la imagen y aplica el destello del Flash
	var lens_warp_overlay = ColorRect.new()
	lens_warp_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lens_warp_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_lens_mat = _create_fnaf_lens_warp_material()
	lens_warp_overlay.material = cam_lens_mat
	layer.add_child(lens_warp_overlay)

	# 5. Golpe de estática blanca (0.22s) al cambiar de fase (m1 -> m2 -> m3) o de cámara
	cam_static_burst_rect = ColorRect.new()
	cam_static_burst_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_static_burst_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_static_burst_rect.material = _create_fnaf_static_burst_material()
	cam_static_burst_rect.visible = false
	layer.add_child(cam_static_burst_rect)

	var cam_crt = _create_portrait_crt_overlay(Color(0.02, 0.95, 0.75, 1.0))
	layer.add_child(cam_crt)

	# OVERLAY DE PANTALLA INHABILITADA POR LA NIÑA FANTASMA O EL RADAR
	previz_screen_blackout_overlay = ColorRect.new()
	previz_screen_blackout_overlay.color = Color(0.12, 0.01, 0.04, 0.96)
	previz_screen_blackout_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	previz_screen_blackout_overlay.visible = false
	layer.add_child(previz_screen_blackout_overlay)

	lbl_previz_blackout_msg = Label.new()
	lbl_previz_blackout_msg.text = "👻 ¡SEÑAL DE VIDEO PERDIDA!\n\nLA NIÑA INHABILITÓ LAS CÁMARAS\n[CALIBRÁ LAS PERILLAS EN TAB 02]"
	lbl_previz_blackout_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_previz_blackout_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_previz_blackout_msg.add_theme_font_size_override("font_size", 11)
	lbl_previz_blackout_msg.modulate = Color("#ff4466")
	lbl_previz_blackout_msg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	previz_screen_blackout_overlay.add_child(lbl_previz_blackout_msg)

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
	lbl_previz_cam_alert.text = "USÁ EL FLASH PARA VER EN LA PENUMBRA"
	lbl_previz_cam_alert.add_theme_font_size_override("font_size", 10)
	lbl_previz_cam_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_previz_cam_alert.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cam_bot_bar.add_child(lbl_previz_cam_alert)

	return frame

func _update_3d_previz(delta: float) -> void:
	if not is_instance_valid(cam_pan_root):
		return

	var video_down: bool = (camera_disabled_timer > 0.0 or light_hacked_by_monster or not companion_pc_unlocked)
	if is_instance_valid(previz_screen_blackout_overlay):
		previz_screen_blackout_overlay.visible = video_down
		if video_down:
			var flicker = 0.15 + 0.20 * abs(sin(pulse_phase * 6.0)) + ghost_jumpscare_flash * 0.5
			previz_screen_blackout_overlay.color = Color(flicker, 0.01, 0.04, 0.96)
			if is_instance_valid(lbl_previz_blackout_msg):
				if not companion_pc_unlocked and not (camera_disabled_timer > 0.0 or light_hacked_by_monster):
					lbl_previz_blackout_msg.text = "🚨 ¡TERMINAL HACKEADA!\n\nCÁMARAS BLOQUEADAS Y AVANCE ACELERADO\n[INGRESÁ EL CÓDIGO EN TAB 03]"
				else:
					lbl_previz_blackout_msg.text = "👻 ¡SEÑAL DE VIDEO PERDIDA!\n\nLA NIÑA INHABILITÓ LAS CÁMARAS\n[CALIBRÁ LAS PERILLAS EN TAB 02]"

	var monster_node = _get_monster_node_id() if monster_attack_active else ""
	var monster_in_this_cam = (not video_down) and monster_attack_active and (selected_cam_id == monster_node)
	var ghost_in_this_cam = (not video_down) and (ghost_active_cam != "" and selected_cam_id == ghost_active_cam)
	var d_state = door_node_states.get(selected_cam_id, "OPEN")

	if monster_in_this_cam:
		monster_spotted_on_cam = true

	# 1. CALCULAR EL ESTADO ACTUAL (VACÍO / M1 / M2 / M3 / FANTASMA)
	var new_stage: int = 0
	var new_state_key: String = "EMPTY_" + selected_cam_id
	if ghost_in_this_cam:
		new_stage = 4 if (ghost_jumpscare_playing or ghost_forced_attack_timer > 0.0) else 1
		new_state_key = "GHOST_%d_%s" % [new_stage, selected_cam_id]
	elif monster_in_this_cam and d_state != "LOCKED":
		if monster_hack_progress >= 74.0:
			new_stage = 3 # hall1_m3.jpg (Pegado a la lente)
		elif monster_hack_progress >= 38.0:
			new_stage = 2 # hall1_m2.jpg (Asomado en la puerta izquierda)
		else:
			new_stage = 1 # hall1_m1.jpg (Ojos al fondo del pasillo)
		new_state_key = "M_STAGE_%d_%s" % [new_stage, selected_cam_id]
	elif d_state == "LOCKED":
		new_state_key = "LOCKED_" + selected_cam_id

	# Si cambió de fase o cambiaste de cámara, mete golpe de estática y cambia la foto
	if new_state_key != current_fnaf_state_key:
		current_fnaf_state_key = new_state_key
		current_monster_stage = new_stage
		cam_static_timer = 0.22
		_apply_fnaf_state_texture(ghost_in_this_cam, monster_in_this_cam and d_state != "LOCKED", new_stage)

	if cam_static_timer > 0.0:
		cam_static_timer = max(0.0, cam_static_timer - delta)
	if is_instance_valid(cam_static_burst_rect):
		cam_static_burst_rect.visible = (cam_static_timer > 0.0 and not video_down)

	if is_instance_valid(cam_door_bars_overlay):
		cam_door_bars_overlay.visible = (d_state == "LOCKED" and not video_down)
		if cam_door_bars_overlay.visible:
			cam_door_bars_overlay.queue_redraw()

	_update_ghost_video(ghost_in_this_cam)

	if is_instance_valid(cam_ghost_overlay):
		cam_ghost_overlay.visible = (ghost_in_this_cam and not is_instance_valid(tex_ghost_girl_state) and not _ghost_video_available())
		if cam_ghost_overlay.visible:
			cam_ghost_overlay.queue_redraw()

	# 2. PANEO HORIZONTAL ESTILO FNAF (Recorre tu imagen widescreen de izquierda a derecha)
	var parent_w: float = max(215.0, cam_pan_root.get_parent_area_size().x)
	var parent_h: float = max(180.0, cam_pan_root.get_parent_area_size().y)
	var extra_w: float = parent_w * 0.38 # 38% de recorrido lateral para aprovechar el formato 2.39:1
	# El paneo arranca en el CENTRO y se va hacia la DERECHA. Se reinicia al cambiar de cámara.
	if cam_pan_last_cam_id != selected_cam_id:
		cam_pan_last_cam_id = selected_cam_id
		cam_pan_time = 0.0
	cam_pan_time += delta
	var pan_move_time: float = max(0.0, cam_pan_time - CAM_PAN_INITIAL_HOLD)
	var pan_wave: float = clampf(sin(pan_move_time * 0.55) * 1.35, -1.0, 1.0)
	var pan_norm: float = pan_wave * 0.5 + 0.5

	var shake_vec := Vector2.ZERO
	if ghost_in_this_cam and (ghost_jumpscare_playing or ghost_forced_attack_timer > 0.0):
		shake_vec = Vector2(randf_range(-8.0, 8.0), randf_range(-5.0, 5.0))

	cam_pan_root.size = Vector2(parent_w + extra_w, parent_h)
	cam_pan_root.position = Vector2(-extra_w * pan_norm, 0.0) + shake_vec

	# 3. ACTUALIZAR EL DESTELLO DEL FLASH EN EL SHADER
	if is_instance_valid(cam_lens_mat):
		var flash_val: float = clampf(flash_stun_grace / 1.15, 0.0, 1.0)
		cam_lens_mat.set_shader_parameter("flash_active", flash_val)

	# 4. TEXTOS DE ALERTA DEL VISOR
	if is_instance_valid(lbl_previz_cam_title):
		lbl_previz_cam_title.text = "🎥 CAM C%s // PUERTA: %s" % [selected_cam_id, "CERRADA" if d_state == "LOCKED" else "ABIERTA"]
		lbl_previz_cam_title.modulate = Color("#00ff9d") if d_state == "LOCKED" else Color("#00f0ff")

	if is_instance_valid(lbl_previz_cam_alert):
		if video_down:
			lbl_previz_cam_alert.text = "🚨 SIN SEÑAL — REPARAR SISTEMA"
			lbl_previz_cam_alert.modulate = Color("#ff1744")
		elif ghost_in_this_cam:
			if ghost_jumpscare_playing or ghost_forced_attack_timer > 0.0:
				lbl_previz_cam_alert.text = "👻 ¡ATAQUE PHANTOM! ¡SEÑAL COLAPSANDO!"
			else:
				var rem = max(0.0, GHOST_MAX_STARE_TIME - ghost_stare_timer)
				lbl_previz_cam_alert.text = "👻 ¡ANOMALÍA (%d/%d)! ¡CAMBIÁ DE CÁMARA YA (%0.1fs)!" % [ghost_encounters_count, GHOST_MAX_ENCOUNTERS, rem]
			lbl_previz_cam_alert.modulate = Color("#ff1744")
		elif monster_in_this_cam and d_state != "LOCKED":
			if selected_cam_id == "4":
				lbl_previz_cam_alert.text = "☣️ ¡FASE %d/3 EN PUERTA C4! ¡CERRALA!" % current_monster_stage
			else:
				lbl_previz_cam_alert.text = "☣️ ¡FASE %d/3 EN C%s! ¡DISPARÁ EL FLASH [🔦]!" % [current_monster_stage, selected_cam_id]
			lbl_previz_cam_alert.modulate = Color("#ff1744") if current_monster_stage == 3 else Color("#ffaa00")
		else:
			lbl_previz_cam_alert.text = "PASILLO C%s EN LÍNEA" % selected_cam_id
			lbl_previz_cam_alert.modulate = Color("#6688aa")

func _apply_fnaf_state_texture(ghost_here: bool, monster_here: bool, stage: int) -> void:
	if not is_instance_valid(cam_state_tex_rect):
		return
	var chosen_tex: Texture2D = tex_cam_empty
	if ghost_here and is_instance_valid(tex_ghost_girl_state):
		chosen_tex = tex_ghost_girl_state
	elif monster_here:
		match stage:
			1: chosen_tex = tex_monster_stage_1 if is_instance_valid(tex_monster_stage_1) else tex_cam_empty
			2: chosen_tex = tex_monster_stage_2 if is_instance_valid(tex_monster_stage_2) else tex_cam_empty
			3: chosen_tex = tex_monster_stage_3 if is_instance_valid(tex_monster_stage_3) else tex_cam_empty
	cam_state_tex_rect.texture = chosen_tex

# =========================================================
# VIDEO DE LA NIÑA FANTASMA: IDLE (0:00-1:00) + JUMPSCARE (1:00-2:00)
# =========================================================
func _load_ghost_videos() -> void:
	if ghost_video_path != "" and ResourceLoader.exists(ghost_video_path):
		ghost_stream = load(ghost_video_path)

func _ghost_video_available() -> bool:
	return is_instance_valid(ghost_video_player) and ghost_stream != null

func _update_ghost_video(ghost_here: bool) -> void:
	if not _ghost_video_available():
		return
	if ghost_jumpscare_playing:
		ghost_video_container.visible = true
		return
	if ghost_here:
		# Aparece la Niña: el video arranca en 0:00 (parada mirando a cámara)
		if ghost_video_mode != "idle":
			ghost_video_mode = "idle"
			ghost_video_player.stream = ghost_stream
			ghost_video_player.play()
		ghost_video_container.visible = true
	elif ghost_video_mode != "":
		ghost_video_mode = ""
		ghost_video_player.stop()
		ghost_video_container.visible = false

# direct = true: salta al segundo 1.0 (jumpscare). direct = false: el video ya corre y sigue solo hacia 1:00-2:00.
# Sin video cargado, cae al jumpscare instantáneo de siempre.
func _begin_ghost_jumpscare(reason: String, direct: bool = false) -> void:
	if ghost_jumpscare_playing:
		return
	if not _ghost_video_available():
		_trigger_ghost_girl_jumpscare(reason)
		return
	ghost_jumpscare_playing = true
	ghost_jumpscare_reason = reason
	var was_running: bool = (ghost_video_mode == "idle" and ghost_video_player.is_playing())
	ghost_video_mode = "jumpscare"
	ghost_video_container.visible = true
	if not was_running:
		ghost_video_player.stream = ghost_stream
		ghost_video_player.play()
	if direct:
		ghost_video_player.stream_position = GHOST_JUMPSCARE_START
		ghost_seek_check_timer = 0.25
		ghost_jumpscare_timer = GHOST_VIDEO_LENGTH - GHOST_JUMPSCARE_START + 0.1
	else:
		ghost_jumpscare_timer = maxf(0.1, GHOST_VIDEO_LENGTH - ghost_video_player.stream_position + 0.1)
	if is_instance_valid(sfx_scare_player):
		sfx_scare_player.pitch_scale = randf_range(0.92, 1.08)
		sfx_scare_player.play()
	_update_3d_previz(0.0)

func _on_ghost_video_finished() -> void:
	if ghost_video_mode == "jumpscare":
		_finish_ghost_jumpscare()

func _finish_ghost_jumpscare() -> void:
	if not ghost_jumpscare_playing:
		return
	var reason: String = ghost_jumpscare_reason
	ghost_jumpscare_playing = false
	_trigger_ghost_girl_jumpscare(reason)

func _reset_ghost_video() -> void:
	ghost_jumpscare_playing = false
	ghost_jumpscare_timer = 0.0
	ghost_seek_check_timer = 0.0
	ghost_video_mode = ""
	if is_instance_valid(ghost_video_player):
		ghost_video_player.stop()
	if is_instance_valid(ghost_video_container):
		ghost_video_container.visible = false

# SHADER QUE ESTIRA LOS BORDES LATERALES (ESTILO FNAF) Y REALZA EL BRILLO CON EL FLASH
func _create_fnaf_lens_warp_material() -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float edge_stretch : hint_range(0.0, 1.0) = 0.44;
uniform float flash_active : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float dx = uv.x - 0.5;
	float dy = uv.y - 0.5;
	// Estiramiento horizontal y curvatura vertical en los extremos izquierdo y derecho
	float stretch_x = dx * (1.0 - edge_stretch * (dx * dx * 3.1));
	float pinch_y = dy * (1.0 + edge_stretch * (dx * dx * 1.9));
	vec2 warped_uv = clamp(vec2(0.5 + stretch_x, 0.5 + pinch_y), vec2(0.002), vec2(0.998));

	vec3 col = texture(SCREEN_TEXTURE, warped_uv).rgb;

	// Tus renders ya tienen la oscuridad ideal (1.0); el Flash levanta las sombras del pasillo
	float dist_center = length(vec2(dx * 1.1, dy));
	float flash_cone = clamp(1.0 - dist_center * 1.35, 0.0, 1.0);
	col = col * (1.0 + flash_active * flash_cone * 2.4) + vec3(0.10, 0.14, 0.12) * flash_active * flash_cone;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	return mat

func _create_fnaf_static_burst_material() -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;

void fragment() {
	vec2 p = floor(UV * vec2(160.0, 110.0));
	float n = fract(sin(dot(p + vec2(TIME * 73.1, TIME * 19.7), vec2(12.9898, 78.233))) * 43758.5453);
	float bars = step(0.35, fract(UV.y * 18.0 + TIME * 14.0));
	float val = mix(n, 1.0, bars * 0.35);
	COLOR = vec4(vec3(val), 0.88);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	return mat

func _draw_locked_door_over_hallway() -> void:
	if not is_instance_valid(cam_door_bars_overlay):
		return
	var s: Vector2 = cam_door_bars_overlay.size
	cam_door_bars_overlay.draw_rect(Rect2(0.0, 0.0, s.x, s.y), Color(0.03, 0.08, 0.06, 0.82), true)
	for y_bar in range(16, int(s.y), 24):
		cam_door_bars_overlay.draw_line(Vector2(0.0, y_bar), Vector2(s.x, y_bar), Color("#183829"), 6.0)
	cam_door_bars_overlay.draw_rect(Rect2(4.0, 4.0, s.x - 8.0, s.y - 8.0), Color("#00ff9d"), false, 2.5)

func _draw_ghost_over_hallway() -> void:
	if not is_instance_valid(cam_ghost_overlay):
		return
	var s: Vector2 = cam_ghost_overlay.size
	var cx: float = s.x * 0.5
	var cy: float = s.y * 0.50
	var g_scale: float = 1.45 if current_monster_stage == 4 else 1.0
	var head_c := Vector2(cx, cy - 16.0 * g_scale)
	cam_ghost_overlay.draw_rect(Rect2(cx - 22.0 * g_scale, head_c.y + 22.0 * g_scale, 44.0 * g_scale, 95.0 * g_scale), Color("#070506"), true)
	for rib_i in range(4):
		var ry: float = head_c.y + (42.0 + rib_i * 10.0) * g_scale
		cam_ghost_overlay.draw_line(Vector2(cx - 14.0 * g_scale, ry), Vector2(cx + 14.0 * g_scale, ry), Color("#4a3f39"), 2.0)
	cam_ghost_overlay.draw_rect(Rect2(cx - 3.0 * g_scale, head_c.y + 30.0 * g_scale, 6.0 * g_scale, 14.0 * g_scale), Color.WHITE, true)
	for side in [-1.0, 1.0]:
		for n_i in range(3):
			cam_ghost_overlay.draw_line(head_c + Vector2(side * 18.0 * g_scale, (n_i - 1) * 5.0), head_c + Vector2(side * 58.0 * g_scale, (n_i - 1) * 11.0 - 6.0), Color("#4a3f39"), 1.5)
	cam_ghost_overlay.draw_circle(head_c, 24.0 * g_scale, Color("#c8cdd0"))
	cam_ghost_overlay.draw_circle(head_c + Vector2(-9.0 * g_scale, -2.0), 6.0 * g_scale, Color("#040406"))
	cam_ghost_overlay.draw_circle(head_c + Vector2(9.0 * g_scale, -2.0), 6.0 * g_scale, Color("#040406"))
	cam_ghost_overlay.draw_circle(head_c + Vector2(-9.0 * g_scale, -2.0), 2.0 * g_scale, Color.WHITE)
	cam_ghost_overlay.draw_circle(head_c + Vector2(9.0 * g_scale, -2.0), 2.0 * g_scale, Color.WHITE)
	cam_ghost_overlay.draw_arc(head_c + Vector2(0.0, 4.0 * g_scale), 11.0 * g_scale, 0.2, PI - 0.2, 12, Color("#040406"), 2.5 * g_scale)

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
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_refresh_lure_tab_ui()

func _on_open_all_doors_pressed() -> void:
	for k in door_node_states.keys():
		if door_node_states[k] == "LOCKED":
			door_node_states[k] = "OPEN"
	door_hold_timer = 0.0
	door_hold_target_time = -1.0
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_refresh_lure_tab_ui()

# --- CERO SPOILERS EN EL TEXTO DE PUERTAS ---
func _update_terminal_lock_state() -> void:
	if not is_instance_valid(current_mission) or not is_instance_valid(btn_inject):
		return

	var sel_closed: bool = (door_node_states.get(selected_cam_id, "OPEN") == "LOCKED")
	btn_inject.visible = true
	btn_inject.text = ("🔓 ABRIR COMPUERTA [C%s]" % selected_cam_id) if sel_closed else ("🚪 CERRAR COMPUERTA [C%s] (1 MÁX)" % selected_cam_id)
	_apply_styled_button(btn_inject, Color("#00ff9d") if sel_closed else Color("#00f0ff"), true)

	var locked_cam: String = ""
	for k in door_node_states.keys():
		if door_node_states[k] == "LOCKED":
			locked_cam = k
			break

	if power_energy <= 0.0:
		lbl_lock_banner.text = "🚨 ¡SIN ENERGÍA (0%)! Todas las compuertas magnéticas están desenergizadas."
		lbl_lock_banner.modulate = Color("#ff1744")
	elif locked_cam != "":
		lbl_lock_banner.text = "🚪 Compuerta [C%s] CERRADA consumiendo Energía (-2.4%%/s). Escuchá el golpe metálico (THUD!) para saber cuándo rebotó el monstruo." % locked_cam
		lbl_lock_banner.modulate = Color("#00ff9d")
	else:
		lbl_lock_banner.text = "En C1..C3 usá el [🔦 FLASH] para hacerlo retroceder. En C4 cerrá la Compuerta Blindada hasta escuchar el golpe."
		lbl_lock_banner.modulate = Color("#ffcc44")

func _update_companion_perk_ui() -> void:
	if not is_instance_valid(current_mission) or not is_instance_valid(lbl_perk_status) or not is_instance_valid(btn_companion_perk):
		return
	if current_mission.companion_perk == "prediction":
		lbl_perk_status.text = "🔮 RASTREO LISTO" if mia_prediction_ready else "🔮 EN ENFRIAMIENTO"
		lbl_perk_status.modulate = Color("#f600ff") if mia_prediction_ready else Color("#88aacc")
		btn_companion_perk.text = "🔮 MIA: ESCANEAR CÁMARAS + RESTAURAR VIDEO" if mia_prediction_ready else "🔮 RASTREO USADO EN ESTA OLEADA"
		btn_companion_perk.disabled = not mia_prediction_ready
		_apply_styled_button(btn_companion_perk, Color("#f600ff"), mia_prediction_ready)
	else:
		if naomi_shield_charges > 0:
			lbl_perk_status.text = "🛡️ NAOMI: ESCUDO LISTO"
			lbl_perk_status.modulate = Color("#00ff9d")
			btn_companion_perk.text = "🛡️ NAOMI: RECARGAR ENERGÍA + REPARAR CÁMARAS"
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
		ghost_active_cam = ""
		_sync_knobs_aligned()
		monster_spotted_on_cam = true
		_select_camera(_get_monster_node_id())
		music_box_charge = min(100.0, music_box_charge + 25.0)
		monster_hack_progress = max(0.0, monster_hack_progress - 20.0)
		_update_companion_perk_ui()
	else:
		if naomi_shield_charges <= 0:
			return
		ghost_active_cam = ""
		temp_hacked_by_monster = false
		_sync_knobs_aligned()
		companion_pc_unlocked = true
		power_energy = min(100.0, power_energy + 35.0)
		bunker_temperature = max(NORMAL_TEMP, bunker_temperature - 25.0)
		music_box_charge = min(100.0, music_box_charge + 35.0)
		monster_hack_progress = max(0.0, monster_hack_progress - 25.0)
		bpm = max(75, bpm - 12)
		_refresh_lure_tab_ui()
		_update_turbine_ui()
		_update_terminal_lock_state()
		_update_hud()

# =========================================================
# 5. DIBUJO DEL MAPA CON RADAR DE NIVEL DE LA COMPAÑERA
# =========================================================
func _update_energy_and_temp_hud() -> void:
	if is_instance_valid(lbl_energy_val):
		lbl_energy_val.text = "%d%%" % int(round(power_energy))
		lbl_energy_val.modulate = Color("#ff1744") if power_energy <= 25.0 else (Color("#ffcc00") if power_energy <= 55.0 else Color("#00ff9d"))
	if is_instance_valid(bar_energy):
		bar_energy.value = power_energy

	if is_instance_valid(lbl_temp_val):
		lbl_temp_val.text = "%d°C" % int(round(bunker_temperature))
		lbl_temp_val.modulate = Color("#ff1744") if bunker_temperature >= 75.0 else (Color("#ffaa00") if bunker_temperature >= 45.0 else Color("#00f0ff"))
	if is_instance_valid(bar_temperature):
		bar_temperature.value = bunker_temperature

	if is_instance_valid(lbl_companion_hack_status):
		var c_name = current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA"
		if companion_pc_unlocked:
			lbl_companion_hack_status.text = "👩‍💻 RADAR %s: ACTIVO" % c_name
			lbl_companion_hack_status.modulate = Color("#00ff9d")
		else:
			lbl_companion_hack_status.text = "🔒 RADAR %s: CAÍDO (TAB 03)" % c_name
			lbl_companion_hack_status.modulate = Color("#ff1744")

func _draw_mia_ecg_wave() -> void:
	if not is_instance_valid(mia_ecg_graph):
		return
	var s = mia_ecg_graph.size
	if s.x <= 10 or s.y <= 10:
		return
	var mid_y = s.y * 0.55
	var col = Color("#00ff9d")
	if mia_lives <= 1:
		col = Color("#ff1744")
	elif mia_lives == 2:
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
			var amp_mult = 1.0 + float(mia_max_lives - mia_lives) * 0.18
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
		lbl_mia_hearts.modulate = Color("#ff1744") if mia_lives <= 1 else (Color("#ffaa00") if mia_lives == 2 else Color("#ff4d94"))

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
		elif mia_lives <= 1:
			lbl_mia_bpm_overlay.text = "PELIGRO (%d)" % mia_bpm
			lbl_mia_bpm_overlay.modulate = Color("#ff1744")
		else:
			lbl_mia_bpm_overlay.text = "BIEN (%d)" % mia_bpm
			lbl_mia_bpm_overlay.modulate = Color("#00ff9d")

	if is_instance_valid(mia_portrait_border_style):
		if mia_lives <= 1 or (suffering_heat and mia_bpm >= 145):
			mia_portrait_border_style.border_color = Color("#ff1744")
		elif mia_lives == 2 or suffering_heat:
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

	var map_hdr = "ENLACE COMPAÑERA: FIREWALL ACTIVO" if companion_pc_unlocked else "🚨 FIREWALL BLOQUEADO (REPARAR EN TAB 03)"
	tactical_map.draw_string(font, Vector2(8, 14), map_hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#00ff9d") if companion_pc_unlocked else Color("#ff1744"))

	var mid_y = s.y * 0.50
	var top_y = s.y * 0.24
	var bot_y = s.y * 0.76

	var p_core = Vector2(s.x * 0.07, mid_y)
	var p_1a = Vector2(s.x * 0.23, s.y * 0.20)
	var p_1 = Vector2(s.x * 0.23, mid_y)
	var p_1b = Vector2(s.x * 0.23, s.y * 0.80)
	var p_2a = Vector2(s.x * 0.45, top_y)
	var p_2b = Vector2(s.x * 0.45, bot_y)
	var p_3a = Vector2(s.x * 0.67, top_y)
	var p_3b = Vector2(s.x * 0.67, bot_y)
	var p_4 = Vector2(s.x * 0.83, mid_y)
	var p_you = Vector2(s.x * 0.95, mid_y)

	map_node_positions = {
		"1A": p_1a, "1": p_1, "1B": p_1b,
		"2A": p_2a, "2B": p_2b,
		"3A": p_3a, "3B": p_3b,
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
		tactical_map.draw_line(e[0], e[1], line_col, 1.6)

	tactical_map.draw_circle(p_core, 7.0, Color(0.25, 0.04, 0.04, 0.9))
	tactical_map.draw_arc(p_core, 7.0, 0, TAU, 16, Color("#d9382e"), 1.6)

	var you_col = Color("#2bbd7e")
	tactical_map.draw_circle(p_you, 7.0, Color(0.04, 0.18, 0.10, 0.9))
	tactical_map.draw_arc(p_you, 7.0, 0, TAU, 16, you_col, 1.6)

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

		var box_size := Vector2(46, 30)
		var box_r := Rect2(npos - box_size * 0.5, box_size)
		tactical_map.draw_rect(box_r, nfill, true)
		tactical_map.draw_rect(box_r, ncol, false, 2.4 if is_cam_sel else 1.5)

		var cam_txt: String = "C" + node_id
		var font_size: int = 12
		var txt_size: Vector2 = font.get_string_size(cam_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var txt_pos := Vector2(
			npos.x - txt_size.x * 0.5,
			npos.y + font.get_ascent(font_size) * 0.5 - 1.0
		)
		tactical_map.draw_string(font, txt_pos, cam_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#f0e6d2") if is_cam_sel else Color("#b0b8bc"))

	var footer_txt = "⚡ %d%%   🌡️ %d°C   🌀 %d%%  |  DEFENSAS %d/%d" % [
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
	var cy = s.y * 0.20
	var jitter = Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))

	# Las 6 agujas metálicas saliendo de los costados del cráneo
	for side in [-1.0, 1.0]:
		for i in range(3):
			var p_start = Vector2(cx + side * 95.0, cy - 10.0 + i * 14.0) + jitter
			var p_end = Vector2(cx + side * 280.0, cy - 38.0 + i * 26.0) + jitter * 1.4
			death_art_canvas.draw_line(p_start, p_end, Color(0.55, 0.48, 0.44, 0.55), 3.0)

	# Silueta de la mandíbula desencajada
	death_art_canvas.draw_rect(Rect2(cx - 75.0 + jitter.x, cy + 25.0 + jitter.y, 150.0, 140.0), Color(0.02, 0.01, 0.01, 0.85), true)
	death_art_canvas.draw_rect(Rect2(cx - 75.0 + jitter.x, cy + 25.0 + jitter.y, 150.0, 140.0), Color(0.35, 0.12, 0.12, 0.45), false, 3.0)

	# Ojos blancos brillantes hundidos en la oscuridad
	var left_eye = Vector2(cx - 58, cy) + jitter
	var right_eye = Vector2(cx + 58, cy) + jitter
	death_art_canvas.draw_circle(left_eye, 24.0, Color(1.0, 1.0, 1.0, 0.18))
	death_art_canvas.draw_circle(right_eye, 24.0, Color(1.0, 1.0, 1.0, 0.18))
	death_art_canvas.draw_circle(left_eye, 8.0, Color.WHITE)
	death_art_canvas.draw_circle(right_eye, 8.0, Color.WHITE)

	# El Chip cuadrado brillando en el centro del pecho
	var chip_pos = Vector2(cx - 24.0, s.y * 0.78) - jitter * 0.6
	death_art_canvas.draw_rect(Rect2(chip_pos - Vector2(10, 10), Vector2(68, 68)), Color(0.25, 0.22, 0.18, 0.7), false, 3.0)
	death_art_canvas.draw_rect(Rect2(chip_pos, Vector2(48, 48)), Color(1.0, 0.88, 0.45, 0.85), true)

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
# 7. LÓGICA DEL MONSTRUO, PUERTA ÚNICA Y GOLPE ACÚSTICO (THUD)
# =========================================================
func _on_monster_completed_hack(_reason_msg: String) -> void:
	if not game_active or not is_instance_valid(current_mission):
		return
	var breached_node = _get_monster_node_id()
	if door_node_states.get(breached_node, "OPEN") == "LOCKED" and power_energy > 0.0:
		monster_hack_progress = 85.0
		if door_hold_target_time < 0.0:
			door_hold_target_time = randf_range(2.5, 6.0)
			door_hold_timer = 0.0
		return

	var next_lvl = min(TOTAL_SECURITY_LEVELS, monster_security_level + 1)
	var candidate_branch = _random_branch_for_level(next_lvl)
	var next_node_id = _node_id_for(next_lvl, candidate_branch)
	if door_node_states.get(next_node_id, "OPEN") == "LOCKED" and power_energy > 0.0:
		monster_security_level = next_lvl
		monster_branch = candidate_branch
		monster_hack_progress = 55.0
		door_hold_target_time = randf_range(2.5, 6.0)
		door_hold_timer = 0.0
		_update_terminal_lock_state()
		_update_hud()
		return

	monster_hack_progress = 0.0
	door_hold_timer = 0.0
	door_hold_target_time = -1.0

	# Si jugás con Naomi y tiene su escudo activo, te perdona una brecha completa
	if current_mission.companion_perk == "forgive_hack" and naomi_shield_charges > 0:
		naomi_shield_charges -= 1
		bpm = max(85, bpm - 10)
		_update_companion_perk_ui()
		_update_hud()
		_generate_breach_matrix()
		return

	door_node_states[breached_node] = "BREACHED"
	monster_last_node_id = breached_node
	monster_security_level += 1
	monster_branch = candidate_branch
	monster_spotted_on_cam = (selected_cam_id == _get_monster_node_id() and camera_disabled_timer <= 0.0 and not light_hacked_by_monster)
	bpm = min(max_bpm, bpm + 16)

	mia_lives = max(0, mia_lives - 1)
	mia_bpm = min(198, mia_bpm + 28)
	mia_damage_flash = 1.0
	_update_mia_vitals_ui()

	if mia_lives <= 0 or monster_security_level > TOTAL_SECURITY_LEVELS:
		_trigger_level_5_fatal_breach()
		return

	companion_pc_unlocked = false # <-- Agregá esta línea antes de _generate_breach_matrix()
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
	is_holding_turbine_btn = false
	bpm = 0
	mia_lives = 0
	mia_hp_percent = 0
	mia_bpm = 0
	_update_mia_vitals_ui()
	last_outcome_type = "failure"
	var comp_name = current_mission.agent_name.to_upper()
	var guard_name = current_mission.security_guard_name.to_upper()
	var m_name = current_mission.monster_name

	if is_instance_valid(sfx_scare_player):
		sfx_scare_player.pitch_scale = 0.72
		sfx_scare_player.play()

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
		var base_mia_bpm = 90 + (mia_max_lives - mia_lives) * 24
		if temp_hacked_by_monster:
			base_mia_bpm += 38
		if bunker_temperature > NORMAL_TEMP:
			base_mia_bpm += int((bunker_temperature - NORMAL_TEMP) * 1.15)
		if music_box_charge < 45.0:
			base_mia_bpm += 22
		mia_bpm = clampi(base_mia_bpm + randi_range(-3, 5), 75, 198)

	_update_hud()

	if bpm >= max_bpm:
		bpm = int(max_bpm * 0.78)
		var cur_m_node = _get_monster_node_id()
		if monster_attack_active and music_box_charge < 40.0 and door_node_states.get(cur_m_node, "OPEN") != "LOCKED":
			monster_hack_progress = min(100.0, monster_hack_progress + 10.0)
	elif time_left <= 0:
		_end_game(true, "mission", "¡06:00 AM ALCANZADAS! ¡Sobreviviste la noche!")

# --- REGLA DE 1 SOLA COMPUERTA MAGNÉTICA CERRADA A LA VEZ ---
func _on_seal_door_choice_pressed() -> void:
	if not game_active:
		return
	var chosen_node_id: String = selected_cam_id
	var cur_state: String = door_node_states.get(chosen_node_id, "OPEN")

	if cur_state == "LOCKED":
		door_node_states[chosen_node_id] = "OPEN"
		if chosen_node_id == _get_monster_node_id():
			door_hold_timer = 0.0
			door_hold_target_time = -1.0
		_select_camera(chosen_node_id)
		_update_terminal_lock_state()
		_refresh_lure_tab_ui()
		return

	if power_energy <= 3.0:
		return

	# Solo puede haber 1 compuerta magnética cerrada al mismo tiempo: abre las demás automáticamente
	for k in door_node_states.keys():
		if door_node_states[k] == "LOCKED":
			door_node_states[k] = "OPEN"

	power_energy = max(0.0, power_energy - 3.5)
	door_node_states[chosen_node_id] = "LOCKED"
	_select_camera(chosen_node_id)

	var actual_monster_node = _get_monster_node_id()
	if monster_attack_active and chosen_node_id == actual_monster_node:
		door_hold_target_time = randf_range(2.5, 6.5)
		door_hold_timer = 0.0
		monster_is_moving = false
	else:
		door_hold_timer = 0.0
		door_hold_target_time = -1.0

	_update_energy_and_temp_hud()
	_refresh_lure_tab_ui()
	_update_terminal_lock_state()
	_update_hud()

func _on_monster_left_after_closed_door(repelled_node_id: String, _waited_seconds: float) -> void:
	# ¡GOLPE ACÚSTICO METÁLICO (THUD)! Le avisa al jugador por oído que el monstruo chocó y se fue
	if is_instance_valid(sfx_thud_player):
		sfx_thud_player.pitch_scale = randf_range(0.88, 1.06)
		sfx_thud_player.play()

	gates_closed_by_guard += 1
	monster_hack_progress = 0.0
	door_hold_timer = 0.0
	door_hold_target_time = -1.0
	affinity = min(100, affinity + 12)
	bpm = max(70, bpm - 12)
	mia_prediction_ready = (current_mission.companion_perk == "prediction")

	# Al rebotar contra la puerta cerrada, retrocede a los primeros pasillos
	monster_security_level = 1 if randf() < 0.70 else max(1, monster_security_level - 1)
	monster_branch = _random_branch_for_level(monster_security_level)

	if gates_closed_by_guard >= TOTAL_DEFENSES_REQUIRED:
		_update_hud()
		var final_route = "romance" if affinity >= 75 else "mission"
		var win_txt = current_mission.romance_success_text if final_route == "romance" else current_mission.mission_success_text
		_end_game(true, final_route, win_txt)
		return

	monster_attack_active = false
	monster_is_moving = false
	monster_spotted_on_cam = false
	monster_last_node_id = repelled_node_id
	monster_advance_on_next_wave = false
	monster_cooldown_timer = randf_range(4.5, 11.0)

	status_overlay.text = "🔊 ¡GOLPE EN COMPUERTA [C%s]! SUBJECT-ZERO REBOTÓ — ¡ABRÍ LA PUERTA!" % repelled_node_id
	status_overlay.modulate = Color("#00ff9d")

	_refresh_lure_tab_ui()
	_select_camera(selected_cam_id)
	_update_terminal_lock_state()
	_update_companion_perk_ui()
	_update_hud()
	_update_3d_previz(0.0)

func _end_game(victory: bool, outcome_type: String, reason: String) -> void:
	game_active = false
	game_timer.stop()
	is_holding_turbine_btn = false
	last_outcome_type = outcome_type
	var color = "#2bbd7e" if victory else "#ff3366"
	status_overlay.text = "● CONTENCIÓN: " + ("🏆 ¡GANASTE! NOCHE COMPLETADA" if victory else "VULNERADO")
	status_overlay.modulate = Color(color)
	btn_continue_vn.visible = true

	if victory and is_instance_valid(victory_modal):
		var comp_name = current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA"
		lbl_victory_title.text = "🏆 ¡GANASTE! — 06:00 AM // NOCHE SUPERADA"
		lbl_victory_details.text = "[center][color=#aaddff][b]%s[/b][/color]\n\n[color=#2bbd7e][b]• Estado de %s:[/b] A SALVO (%d/%d ♥)  |  [b]Vínculo:[/b] %d%%\n[b]• Energía Restante:[/b] %d%%  |  [b]Temperatura Final:[/b] %d°C[/color]\n\n[color=#d8dfdc]¡Lograste contener a Subject-Zero y sobrevivir a la Anomalía Fantasma![/color][/center]" % [
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
	lbl_affinity.text = "♥ VÍNCULO (%s): %d%%  |  VIDAS: %d/%d ♥" % [
		current_mission.agent_name.to_upper(),
		affinity,
		mia_lives,
		mia_max_lives
	]
	_update_mia_vitals_ui()
	_update_energy_and_temp_hud()

func _populate_mission_selector() -> void:
	mission_selector.clear()
	for i in range(available_missions.size()):
		var m = available_missions[i]
		var perk_short = "Predicción" if m.companion_perk == "prediction" else "Escudo 1-Brecha"
		mission_selector.add_item("%s (%s)" % [m.agent_name, perk_short], i)

func _create_default_template(p_name: String, p_code: String, p_color: Color) -> MissionData:
	var m = MissionData.new()
	m.agent_name = p_name
	m.agent_codename = p_code
	m.agent_color = p_color
	if p_name.to_lower() == "naomi":
		m.companion_perk = "forgive_hack"
		m.security_guard_name = "Mia"
		m.security_guard_codename = "ORACLE-01"
	else:
		m.companion_perk = "prediction"
		m.security_guard_name = "Naomi"
		m.security_guard_codename = "AEGIS-02"
	return m

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

	var scr_tl := Vector2(70.0, 50.0)
	var scr_tr := Vector2(s.x - 84.0, 50.0)
	var scr_bl := Vector2(70.0, s.y - 64.0)
	var scr_br := Vector2(s.x - 84.0, s.y - 64.0)

	var out_tl := Vector2(36.0, 20.0)
	var out_tr := Vector2(s.x - 24.0, 28.0)
	var out_bl := Vector2(22.0, s.y - 34.0)
	var out_br := Vector2(s.x - 16.0, s.y - 26.0)

	for pipe_x in [s.x * 0.18, s.x * 0.24, s.x * 0.52, s.x * 0.78, s.x * 0.88]:
		monitor_3d_diorama.draw_rect(Rect2(pipe_x, 0.0, 18.0, 32.0), Color("#121518"), true)
		monitor_3d_diorama.draw_line(Vector2(pipe_x + 4.0, 0.0), Vector2(pipe_x + 4.0, 32.0), Color(1, 1, 1, 0.06), 2.0)

	var wall_logo_c := Vector2(s.x * 0.76, 18.0)
	monitor_3d_diorama.draw_arc(wall_logo_c, 22.0, 0.0, TAU, 28, Color(0.35, 0.38, 0.40, 0.22), 2.5)
	monitor_3d_diorama.draw_arc(wall_logo_c, 12.0, 0.0, TAU, 20, Color(0.35, 0.38, 0.40, 0.22), 2.0)

	var alarm_pulse: float = 0.65 + 0.35 * sin(pulse_phase * 1.8)
	if monster_attack_active or _count_active_errors() > 0 or bunker_temperature >= 60.0:
		alarm_pulse = 0.85 + 0.15 * sin(pulse_phase * 4.5)
	var lamp_pos := Vector2(96.0, 18.0)
	for r_i in range(6, 0, -1):
		var rad: float = float(r_i) * 28.0
		monitor_3d_diorama.draw_circle(lamp_pos, rad, Color(0.95, 0.12, 0.08, 0.045 * alarm_pulse))
	monitor_3d_diorama.draw_circle(lamp_pos, 14.0, Color(1.0, 0.22, 0.15, 0.9 * alarm_pulse))
	monitor_3d_diorama.draw_circle(lamp_pos, 7.0, Color(1.0, 0.75, 0.65, 0.95 * alarm_pulse))
	monitor_3d_diorama.draw_arc(lamp_pos, 15.0, 0.0, TAU, 16, Color("#2a1210"), 2.0)
	monitor_3d_diorama.draw_line(lamp_pos + Vector2(-15, 0), lamp_pos + Vector2(15, 0), Color("#2a1210"), 1.5)
	monitor_3d_diorama.draw_line(lamp_pos + Vector2(0, -15), lamp_pos + Vector2(0, 15), Color("#2a1210"), 1.5)

	var desk_poly := PackedVector2Array([
		Vector2(0.0, s.y - 42.0),
		Vector2(s.x, s.y - 34.0),
		Vector2(s.x, s.y),
		Vector2(0.0, s.y)
	])
	monitor_3d_diorama.draw_colored_polygon(desk_poly, Color("#0a0c0e"))
	monitor_3d_diorama.draw_line(Vector2(0.0, s.y - 42.0), Vector2(s.x, s.y - 34.0), Color("#22282a"), 2.0)

	for gx in range(int(s.x * 0.18), int(s.x * 0.52), 16):
		monitor_3d_diorama.draw_line(Vector2(gx, s.y - 28.0), Vector2(gx - 18.0, s.y - 4.0), Color("#15191c"), 2.0)
	monitor_3d_diorama.draw_circle(Vector2(s.x * 0.25, s.y - 12.0), 42.0, Color(0.95, 0.22, 0.12, 0.08 * alarm_pulse))

	var chassis_poly := PackedVector2Array([out_tl, out_tr, out_br, out_bl])
	monitor_3d_diorama.draw_colored_polygon(chassis_poly, Color("#121517"))
	monitor_3d_diorama.draw_polyline(PackedVector2Array([out_tl, out_tr, out_br, out_bl, out_tl]), Color("#2c3336"), 2.5)

	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([out_tl, out_tr, scr_tr, scr_tl]), Color("#181c1f"))
	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([scr_bl, scr_br, out_br, out_bl]), Color("#0c0e10"))
	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([out_tl, scr_tl, scr_bl, out_bl]), Color("#14181b"))
	monitor_3d_diorama.draw_colored_polygon(PackedVector2Array([scr_tr, out_tr, out_br, scr_br]), Color("#101315"))

	monitor_3d_diorama.draw_line(out_tl, scr_tl, Color("#2a3033"), 2.0)
	monitor_3d_diorama.draw_line(out_tr, scr_tr, Color("#2a3033"), 2.0)
	monitor_3d_diorama.draw_line(out_bl, scr_bl, Color("#2a3033"), 2.0)
	monitor_3d_diorama.draw_line(out_br, scr_br, Color("#2a3033"), 2.0)

	var right_frame_x: float = s.x - 76.0
	monitor_3d_diorama.draw_rect(Rect2(right_frame_x + 12.0, s.y * 0.24, 5.0, s.y * 0.18), Color(0.95, 0.18, 0.12, 0.85 * alarm_pulse), true)
	monitor_3d_diorama.draw_circle(Vector2(right_frame_x + 14.0, s.y * 0.20), 4.0, Color("#d9382e"))
	monitor_3d_diorama.draw_string(font, Vector2(right_frame_x - 2.0, s.y * 0.50), "BÚNKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#5c6466"))
	monitor_3d_diorama.draw_string(font, Vector2(right_frame_x - 2.0, s.y * 0.55), "B7", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#6e777a"))

	for rv in [Vector2(52, 36), Vector2(52, s.y - 48), Vector2(s.x - 42, 42), Vector2(s.x - 42, s.y - 44)]:
		monitor_3d_diorama.draw_circle(rv, 3.5, Color("#090b0c"))
		monitor_3d_diorama.draw_arc(rv, 3.5, 0.0, TAU, 10, Color("#2e3538"), 1.2)

	var mug_pos := Vector2(18.0, s.y - 118.0)
	var mug_size := Vector2(78.0, 96.0)
	monitor_3d_diorama.draw_arc(mug_pos + Vector2(mug_size.x + 2.0, mug_size.y * 0.52), 20.0, -PI * 0.45, PI * 0.45, 16, Color("#2c2a29"), 7.0)
	monitor_3d_diorama.draw_rect(Rect2(mug_pos, mug_size), Color("#252322"), true)
	monitor_3d_diorama.draw_rect(Rect2(mug_pos + Vector2(6, 4), Vector2(14, mug_size.y - 8)), Color(1, 1, 1, 0.05), true)
	monitor_3d_diorama.draw_rect(Rect2(mug_pos, mug_size), Color("#3d3a38"), false, 2.0)
	monitor_3d_diorama.draw_circle(mug_pos + Vector2(mug_size.x * 0.5, 4.0), 10.0, Color("#121010"))
	var mug_logo := mug_pos + Vector2(mug_size.x * 0.48, mug_size.y * 0.56)
	monitor_3d_diorama.draw_arc(mug_logo, 16.0, 0.0, TAU, 20, Color("#121110"), 2.0)
	monitor_3d_diorama.draw_arc(mug_logo, 8.0, 0.0, TAU, 16, Color("#121110"), 1.6)

func _draw_companion_matrix_stream() -> void:
	if not is_instance_valid(matrix_rain_canvas):
		return
	var s: Vector2 = matrix_rain_canvas.size
	if s.x < 20.0 or s.y < 20.0:
		return

	var font: Font = ThemeDB.fallback_font
	var matrix_pending: bool = (target_sequence.size() > 0 and entered_sequence.size() < target_sequence.size())
	var is_hacked: bool = (not companion_pc_unlocked) or temp_hacked_by_monster or matrix_pending
	var main_col: Color = Color("#ff1744") if is_hacked else Color("#00ff9d")
	var head_col: Color = Color("#ffcdd2") if is_hacked else Color("#d6ffef")
	var t_now: float = float(Time.get_ticks_msec()) * 0.001

	if is_instance_valid(matrix_stream_style):
		if is_hacked:
			var pulse_err: float = 0.5 + 0.5 * sin(t_now * 9.0)
			matrix_stream_style.border_color = Color("#ff1744").lerp(Color("#ffaa00"), pulse_err)
			matrix_stream_style.bg_color = Color(0.09 + 0.05 * pulse_err, 0.01, 0.02, 0.96)
		else:
			matrix_stream_style.border_color = Color("#00ff9d")
			matrix_stream_style.bg_color = Color(0.02, 0.05, 0.04, 0.96)

	var glyphs_ok: String = "0101101001¥§∆Ω∑¶#%&@$0110100101ΞΨΦ01"
	var glyphs_err: String = "01X!#¥§ERR_FAULT_00110101☠⚠0101#?!×0"
	var charset: String = glyphs_err if is_hacked else glyphs_ok

	var col_w: float = 16.0
	var row_h: float = 12.0
	var cols: int = int(s.x / col_w) + 1
	var rows: int = int(s.y / row_h) + 2

	for c in range(cols):
		var col_seed: float = float(c * 37 + 13)
		var speed: float = (6.0 if is_hacked else 3.2) + fmod(col_seed * 0.31, 2.6)
		var cycle_len: float = float(max(6, rows + 4))
		var head_pos: float = fmod(t_now * speed + col_seed * 0.7, cycle_len)

		for r in range(rows):
			var dist: float = fposmod(head_pos - float(r), cycle_len)
			if dist <= 8.5:
				var alpha: float = clampf(1.0 - (dist / 8.5), 0.15, 0.95)
				var char_idx: int = int(abs(sin(col_seed + float(r) * 1.9 + floor(t_now * (14.0 if is_hacked else 6.0))) * 1000.0)) % charset.length()
				var ch: String = charset.substr(char_idx, 1)
				var pos := Vector2(4.0 + float(c) * col_w, 24.0 + float(r) * row_h)
				if pos.y <= s.y + 4.0:
					var draw_c: Color = head_col if dist < 0.9 else Color(main_col.r, main_col.g, main_col.b, alpha * 0.82)
					matrix_rain_canvas.draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, draw_c)

	matrix_rain_canvas.draw_rect(Rect2(0.0, 0.0, s.x, 16.0), Color(0.01, 0.02, 0.03, 0.90), true)
	var comp_name: String = current_mission.agent_name.to_upper() if is_instance_valid(current_mission) else "COMPAÑERA"
	var header_txt: String = ""
	if is_hacked:
		header_txt = "🚨 [ERR_0x9F // FIREWALL DE %s CAÍDO — CLICK PARA DESBLOQUEAR EN TAB 03]" % comp_name
	else:
		header_txt = "🟢 [FIREWALL_LINK // %s CONTENIENDO AVANCE // ENCRIPTACIÓN ESTABLE...]" % comp_name
	matrix_rain_canvas.draw_string(font, Vector2(6.0, 12.0), header_txt, HORIZONTAL_ALIGNMENT_LEFT, s.x - 12.0, 10, head_col if is_hacked else main_col)
	
	# =========================================================
# LÓGICA DE VIDEO DE NAOMI / COMPAÑERA EN EL PANEL IZQUIERDO
# =========================================================
# =========================================================
# LÓGICA DE LOS 3 VIDEOS DE NAOMI / COMPAÑERA (PANEL IZQUIERDO)
# =========================================================
func _setup_companion_left_video(data: MissionData) -> void:
	companion_idle_1_stream = null
	companion_idle_2_stream = null
	companion_hacked_stream = null
	companion_idle_wait_timer = 0.0
	companion_static_timer = 0.0
	companion_was_hacked_state = false
	companion_next_is_look_around = false

	if naomi_idle_1_video_path != "" and ResourceLoader.exists(naomi_idle_1_video_path):
		companion_idle_1_stream = load(naomi_idle_1_video_path)
	elif data.seedance_video != "" and ResourceLoader.exists(data.seedance_video):
		companion_idle_1_stream = load(data.seedance_video)

	if naomi_idle_2_video_path != "" and ResourceLoader.exists(naomi_idle_2_video_path):
		companion_idle_2_stream = load(naomi_idle_2_video_path)

	if naomi_hacked_video_path != "" and ResourceLoader.exists(naomi_hacked_video_path):
		companion_hacked_stream = load(naomi_hacked_video_path)

	if is_instance_valid(companion_static_burst_rect):
		companion_static_burst_rect.visible = false

	if is_instance_valid(companion_video_player):
		if companion_idle_1_stream != null:
			var is_naomi: bool = (data.agent_name.to_lower() == "naomi")
			companion_video_player.material = _create_portrait_crt_material(
				Color(0.86, 1.0, 0.94, 1.0) if is_naomi else Color(0.98, 0.88, 1.0, 1.0)
			)
			companion_video_player.visible = true
			_play_next_normal_companion_clip()
		else:
			companion_video_player.stop()
			companion_video_player.visible = false

func _play_next_normal_companion_clip() -> void:
	if not is_instance_valid(companion_video_player):
		return
	var chosen_stream: VideoStream = companion_idle_1_stream
	if companion_next_is_look_around and companion_idle_2_stream != null:
		chosen_stream = companion_idle_2_stream
	companion_next_is_look_around = not companion_next_is_look_around

	if chosen_stream != null:
		companion_video_player.stop()
		companion_video_player.stream = chosen_stream
		companion_video_player.visible = true
		companion_video_player.paused = false
		companion_video_player.play()

func _update_companion_left_video(delta: float) -> void:
	if not is_instance_valid(companion_video_player) or companion_idle_1_stream == null:
		return

	var matrix_pending: bool = (target_sequence.size() > 0 and entered_sequence.size() < target_sequence.size())
	var is_hacked_now: bool = (not companion_pc_unlocked) or temp_hacked_by_monster or matrix_pending

	# 1. ¿Cambió entre Normal <-> Hackeado? ¡Disparar estática y cambiar al video correspondiente!
	if is_hacked_now != companion_was_hacked_state:
		companion_was_hacked_state = is_hacked_now
		companion_static_timer = 0.35
		companion_idle_wait_timer = 0.0

		if is_instance_valid(companion_static_burst_rect):
			companion_static_burst_rect.visible = true

		if is_hacked_now:
			# HACKEARON LA TERMINAL -> Pasa al Video 3 (preocupada mirando abajo) en loop
			var hack_str: VideoStream = companion_hacked_stream if companion_hacked_stream != null else companion_idle_1_stream
			companion_video_player.stop()
			companion_video_player.stream = hack_str
			companion_video_player.visible = true
			companion_video_player.paused = false
			companion_video_player.play()
		else:
			# ARREGLASTE LA TERMINAL -> Estática y vuelve al ciclo de Idle 1 / Look Around 2
			companion_next_is_look_around = false
			_play_next_normal_companion_clip()

	# 2. Descontar el golpe de estática (0.35s)
	if companion_static_timer > 0.0:
		companion_static_timer = max(0.0, companion_static_timer - delta)
		if is_instance_valid(companion_static_burst_rect):
			companion_static_burst_rect.visible = (companion_static_timer > 0.0)

	# 3. En estado normal: congelar en el último fotograma (~7.85s) para esperar 5 segundos sin pantalla vacía
	if not is_hacked_now:
		if companion_idle_wait_timer > 0.0:
			companion_idle_wait_timer -= delta
			if companion_idle_wait_timer <= 0.0:
				_play_next_normal_companion_clip()
		elif not companion_video_player.paused and companion_video_player.is_playing():
			var v_len: float = companion_video_player.get_stream_length()
			var freeze_point: float = (v_len - 0.12) if v_len > 1.0 else 7.85
			if companion_video_player.stream_position >= freeze_point:
				companion_video_player.paused = true
				companion_idle_wait_timer = naomi_idle_wait_seconds

func _on_companion_video_finished() -> void:
	if not is_instance_valid(companion_video_player) or companion_idle_1_stream == null:
		return

	if companion_was_hacked_state:
		# El Video 3 (preocupada mirando abajo) hace loop continuo mientras siga hackeada
		companion_video_player.paused = false
		companion_video_player.play()
	else:
		# Respaldo por si el video duró menos de 7.85s y llegó a finished antes del freeze_point
		if companion_idle_wait_timer <= 0.0:
			companion_idle_wait_timer = naomi_idle_wait_seconds

# =========================================================
# SONIDO GLOBAL PARA TODOS LOS BOTONES Y TABS DE LA TABLET
# =========================================================
func _bind_all_tablet_button_sounds(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is BaseButton:
			var btn := child as BaseButton
			# En el botón de la turbina suena al apretar (button_down); en los demás al hacer clic (pressed)
			if btn == btn_wind_music:
				if not btn.button_down.is_connected(_play_tablet_click_sfx):
					btn.button_down.connect(_play_tablet_click_sfx)
			else:
				if not btn.pressed.is_connected(_play_tablet_click_sfx):
					btn.pressed.connect(_play_tablet_click_sfx)
		elif child is TabContainer:
			var tc := child as TabContainer
			if not tc.tab_clicked.is_connected(_on_tablet_tab_clicked_sfx):
				tc.tab_clicked.connect(_on_tablet_tab_clicked_sfx)
		if child.get_child_count() > 0:
			_bind_all_tablet_button_sounds(child)

func _on_tablet_tab_clicked_sfx(_tab_idx: int) -> void:
	_play_tablet_click_sfx()

func _play_tablet_click_sfx() -> void:
	if is_instance_valid(sfx_click_player) and sfx_click_player.stream != null:
		sfx_click_player.pitch_scale = randf_range(0.95, 1.06)
		sfx_click_player.play()


# =========================================================
# 9. GUÍA CONTEXTUAL: LE DICE AL JUGADOR QUÉ HACER AHORA
# =========================================================
const GUIDE_COLORS: Array[Color] = [Color("#00ff9d"), Color("#00f0ff"), Color("#ffaa00"), Color("#ff1744")]

func _update_guidance(delta: float) -> void:
	if not is_instance_valid(guide_panel):
		return
	guide_tick -= delta
	var blink: float = 0.5 + 0.5 * sin(pulse_phase * 2.4)

	# La lógica cuesta poco, pero no hace falta recalcularla en cada frame
	if guide_tick <= 0.0:
		guide_tick = 0.15
		var g: Dictionary = _compute_guidance()
		guide_level = int(g["level"])
		var col: Color = GUIDE_COLORS[guide_level]
		lbl_guide_title.text = String(g["title"])
		lbl_guide_title.modulate = col
		lbl_guide_text.text = String(g["text"])
		lbl_guide_goal.text = "🎯 CONTENCIONES\n%d / %d" % [gates_closed_by_guard, TOTAL_DEFENSES_REQUIRED]
		guide_action_tab = int(g["tab"])
		btn_guide_action.visible = guide_action_tab >= 0
		if guide_action_tab >= 0:
			btn_guide_action.text = "IR A PESTAÑA 0%d >>" % (guide_action_tab + 1)
			_apply_styled_button(btn_guide_action, col, true)
		guide_style.bg_color = Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.96)
		guide_focus = g["focus"]

	# Parpadeo del borde según urgencia
	var base_col: Color = GUIDE_COLORS[guide_level]
	guide_style.border_color = base_col.lerp(Color.WHITE, blink * 0.35) if guide_level >= 2 else base_col

	# Resalta (pulsa) los botones que conviene tocar y apaga el resto
	for c in guide_prev_focus:
		if is_instance_valid(c) and not guide_focus.has(c):
			c.modulate = Color.WHITE
	for c in guide_focus:
		if is_instance_valid(c):
			c.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.7, 1.55, 0.75), blink)
	guide_prev_focus = guide_focus.duplicate()

func _compute_guidance() -> Dictionary:
	var video_down: bool = (light_hacked_by_monster or camera_disabled_timer > 0.0)
	var cams_ok: bool = (not video_down and companion_pc_unlocked)
	var turbine_ok: bool = (music_box_charge >= 40.0 and power_energy > 0.0)

	# 1) La Niña en la cámara que estás mirando: reaccionar YA
	if ghost_active_cam != "" and selected_cam_id == ghost_active_cam and not video_down:
		var others: Array[Control] = []
		for k in cam_select_buttons.keys():
			if k != selected_cam_id and is_instance_valid(cam_select_buttons[k]):
				others.append(cam_select_buttons[k])
		return _guide(3, "👁️ ¡LA NIÑA ESTÁ EN ESTA CÁMARA!",
			"Cambiá de cámara AHORA (%.1fs). No uses el FLASH ni sigas mirándola." % max(0.0, GHOST_MAX_STARE_TIME - ghost_stare_timer), -1, others)

	# 2) Sin energía
	if power_energy <= 0.0:
		return _guide(3, "⚡ SIN ENERGÍA",
			"Las compuertas y la turbina no funcionan. Mirá las cámaras y esperá que se recupere.", -1, [])

	# 3) Subject-Zero activo
	if monster_attack_active:
		var node_id: String = _get_monster_node_id()
		var door_closed_on_it: bool = (door_node_states.get(node_id, "OPEN") == "LOCKED")
		if door_closed_on_it:
			return _guide(1, "🚪 COMPUERTA CERRADA: ESPERÁ EL GOLPE",
				"Cuando escuches el golpe metálico (THUD) se fue. Después ABRÍ la compuerta para dejar de gastar energía.", -1, [btn_inject])
		if selected_cam_id == node_id and cams_ok:
			if monster_security_level >= TOTAL_SECURITY_LEVELS:
				return _guide(3, "☣️ SUBJECT-ZERO EN C%s: ¡CERRÁ LA COMPUERTA!" % node_id,
					"Es el último pasillo: el FLASH solo lo frena un poco. Tocá CERRAR COMPUERTA y esperá el golpe.", -1, [btn_inject])
			return _guide(3, "☣️ SUBJECT-ZERO EN C%s: ¡DISPARÁ EL FLASH!" % node_id,
				"Tocá FLASH ahora para hacerlo retroceder. Si lo dejás, avanza y hackea el sector.", -1, [btn_quick_flash])

	# 4) Sistemas sabotados (reparar)
	if video_down:
		return _guide(3 if monster_attack_active else 2, "🚨 ÓPTICA CAÍDA: NO PODÉS VER NI USAR FLASH",
			"Alineá las 4 perillas en la pestaña 02 para recuperar las cámaras.", 1, [])
	if not companion_pc_unlocked:
		return _guide(3 if monster_attack_active else 2, "🚨 RADAR CAÍDO: EL MONSTRUO VA AL DOBLE",
			"Completá la secuencia hexadecimal en la pestaña 03 para reparar el radar.", 2, [])

	# 5) Subject-Zero se acerca pero no lo ves
	if monster_attack_active:
		var perk_btn: Array[Control] = []
		var tip: String = "Revisá las cámaras (C1–C4 o tocá el mapa) hasta verlo."
		if mia_prediction_ready and current_mission.companion_perk == "prediction" and is_instance_valid(btn_companion_perk):
			tip += " Mia puede rastrearlo: usá su habilidad."
			perk_btn.append(btn_companion_perk)
		return _guide(2, "⚠️ SUBJECT-ZERO SE ACERCA", tip, -1, perk_btn)

	# 6) Mantenimiento
	if not turbine_ok:
		return _guide(3, "🌀 TURBINA CAÍDA (%d%%)" % int(music_box_charge),
			"Mantené APRETADO el botón de turbina hasta pasar el 40%. Sin turbina sube el calor y se gasta energía.", 0, [btn_wind_music])
	if bunker_temperature >= 50.0:
		return _guide(2, "🌡️ SALA CALIENTE (%d°C)" % int(bunker_temperature),
			"Mantené la turbina sobre 40% para enfriar. Pasados 70°C gastás más energía.", 0, [btn_wind_music])
	if music_box_charge < 60.0:
		return _guide(1, "🌀 TURBINA BAJA (%d%%)" % int(music_box_charge),
			"Se descarga sola. Recargala ahora que está tranquilo, antes de que llegue Subject-Zero.", 0, [btn_wind_music])
	if power_energy < 25.0:
		return _guide(2, "⚡ ENERGÍA BAJA (%d%%)" % int(power_energy),
			"Evitá cerrar compuertas y usar FLASH sin necesidad. La energía se recupera con la turbina arriba y sin puertas cerradas.", -1, [])

	return _guide(0, "✅ TODO ESTABLE",
		"Subject-Zero todavía no ataca. Mantené la turbina arriba y recorré las cámaras. Si ves a la Niña, cambiá de cámara enseguida.", -1, [])

func _guide(level: int, title: String, text: String, tab: int, focus: Array[Control]) -> Dictionary:
	return {"level": level, "title": title, "text": text, "tab": tab, "focus": focus}

func _show_help_dialog() -> void:
	if not is_instance_valid(help_dialog):
		help_dialog = AcceptDialog.new()
		help_dialog.title = "❓ CÓMO SE JUEGA"
		help_dialog.ok_button_text = "ENTENDIDO"
		help_dialog.dialog_autowrap = true
		help_dialog.dialog_text = "\n".join([
			"🎯 OBJETIVO: sobrevivir hasta las 6 AM conteniendo a Subject-Zero.",
			"",
			"🎥 CÁMARAS (C1–C4 o tocá el mapa): buscá a Subject-Zero. La barra de arriba siempre te dice qué hacer.",
			"👁️ LA NIÑA FANTASMA: si aparece en tu cámara, cambiá de cámara en menos de 1 segundo. NUNCA le dispares FLASH.",
			"🔦 FLASH: en C1–C3 hace retroceder a Subject-Zero (-6% energía). En C4 solo lo frena.",
			"🚪 COMPUERTA: en C4 cerrala, esperá el golpe (THUD) y abrila de nuevo. Solo 1 a la vez y gasta energía.",
			"🌀 TURBINA (pestaña 01): mantené apretado para subirla. Bajo 40% la sala se calienta y se gasta energía.",
			"🎛️ PERILLAS (02) y 💻 RADAR (03): la Niña los sabotea. Si el título de la pestaña dice 🚨, repará ahí.",
			"🔮 COMPAÑERA: usá su habilidad cuando esté lista (botón rojo grande, abajo a la izquierda).",
		])
		add_child(help_dialog)
	help_dialog.popup_centered(Vector2i(620, 460))
