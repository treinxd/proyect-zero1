class_name VNEngine
extends Control

const SAVE_FILE_PATH: String = "user://proyect_zero_saves.cfg"
const OperatorConsoleScript = preload("res://operator_console.gd")

@export_group("1. Guion e Historia (Estilo Ren'Py)")
@export_multiline var custom_story_script: String = ""
@export var start_at_title_screen: bool = true

@export_group("2. Personajes, Fondos y Misiones")
@export var characters: Array[VNCharacterData] = []
@export var missions: Array[MissionData] = []
@export var default_background: Texture2D
@export var custom_backgrounds: Dictionary = {} # {"bunker": Texture2D, ...}

@export_group("3. Ajustes Visuales")
@export var typewriter_speed: float = 55.0
@export var auto_advance_delay: float = 2.2
@export var background_blur_amount: float = 2.2
@export var enable_crt_shader: bool = false
@export_range(0.0, 1.0, 0.05) var crt_intensity: float = 0.45

# --- ESTADO DEL MOTOR REN'PY ---
var parsed_labels: Dictionary = {}
var current_label: String = "start"
var current_step: int = 0
var story_vars: Dictionary = {
	"mia_affinity": 50,
	"naomi_affinity": 50,
	"maria_affinity": 50,
	"yuri_affinity": 50
}
var char_registry: Dictionary = {} # id -> VNCharacterData
var active_actors: Dictionary = {} # id -> VNStageActor
var actor_positions: Dictionary = {} # id -> "left" | "center" | "right"
var current_bg_id: String = "bunker"

# Estado de reproducción de diálogo
var is_typing: bool = false
var char_progress: float = 0.0
var is_waiting_choice: bool = false
var is_in_hacking_mode: bool = false
var auto_mode: bool = false
var skip_mode: bool = false
var auto_timer: float = 0.0
var skip_timer: float = 0.0
var bg_anim_time: float = 0.0
var lateral_menu_open: bool = false

# Rollback (botón "Atrás" estilo Ren'Py) y Log
var rollback_stack: Array[Dictionary] = []
var pending_hack_branches: Dictionary = {}

# --- CAPAS Y NODOS UI ---
var bg_canvas: Control
var bg_texture_rect: TextureRect
var stage_layer: Control

# Menú desplegable lateral superior izquierdo (Icono Hacker)
var top_left_menu_root: Control
var btn_hacker_icon: TextureButton
var lateral_drawer_panel: PanelContainer
var btn_qm_auto: Button
var btn_qm_skip: Button

# Caja de diálogo estilo Píldora (como example.png) + Nombre flotante arriba
var dialogue_container: Control
var adv_pill_panel: PanelContainer
var speaker_name_lbl: Label
var dialogue_rtl: RichTextLabel

# Menú de Elecciones (Choice Menu)
var choice_overlay: CenterContainer
var choice_vbox: VBoxContainer

# Consola de Hackeo integrada
var hacking_console: Control

# Pantallas superpuestas: Título, Pausa/Guardado/Opciones e Historial
var title_screen: Control
var pause_modal: Control
var pause_tabs: TabContainer
var save_slots_vbox: VBoxContainer
var history_modal: PanelContainer
var history_rtl: RichTextLabel
var crt_material: ShaderMaterial

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.size_changed.connect(_on_viewport_resized)

	_init_default_resources()
	var script_src = custom_story_script if custom_story_script.strip_edges() != "" else VNStoryScript.DEFAULT_STORY_SCRIPT
	parsed_labels = VNStoryScript.parse_script(script_src)

	_build_vn_backgrounds()
	if enable_crt_shader:
		_build_crt_layer()
	_build_stage_layer()
	_build_vn_hud_and_dialogue()
	_build_choice_overlay()
	_build_hacking_console_layer()
	_build_history_modal()
	_build_pause_and_save_menu()
	_build_title_screen()

	_on_viewport_resized()

	if start_at_title_screen:
		title_screen.visible = true
	else:
		start_new_game()

func _init_default_resources() -> void:
	if missions.is_empty():
		if ResourceLoader.exists("res://mision_02.tres"):
			missions.append(load("res://mision_02.tres"))
		if ResourceLoader.exists("res://mision_01.tres"):
			missions.append(load("res://mision_01.tres"))

	if characters.is_empty():
		var c_mia = VNCharacterData.new()
		c_mia.id = "mia"
		c_mia.display_name = "MIA"
		c_mia.codename = "ORACLE-01"
		c_mia.name_color = Color("#f600ff")
		_auto_assign_character_sprites(c_mia, 0)
		characters.append(c_mia)

		var c_naomi = VNCharacterData.new()
		c_naomi.id = "naomi"
		c_naomi.display_name = "NAOMI"
		c_naomi.codename = "AEGIS-02"
		c_naomi.name_color = Color("#00ff9d")
		_auto_assign_character_sprites(c_naomi, 1)
		characters.append(c_naomi)

	for ch in characters:
		if is_instance_valid(ch):
			char_registry[ch.id.to_lower()] = ch
			if ch.id.to_lower() == "mia":
				char_registry["maria"] = ch
			elif ch.id.to_lower() == "naomi":
				char_registry["yuri"] = ch

func _auto_assign_character_sprites(c_data: VNCharacterData, mission_idx: int) -> void:
	var candidate_ids = [c_data.id.to_lower()]
	if c_data.id.to_lower() == "mia":
		candidate_ids.append("maria")
	elif c_data.id.to_lower() == "naomi":
		candidate_ids.append("yuri")

	for cid in candidate_ids:
		var found = false
		for ext in ["png", "jpg", "jpeg", "webp"]:
			var sheet_path = "res://assets/sprites/%s_sheet.%s" % [cid, ext]
			if ResourceLoader.exists(sheet_path):
				c_data.dual_pose_sheet = load(sheet_path)
				found = true
				break
		if found:
			break

	if missions.size() > mission_idx and is_instance_valid(missions[mission_idx]):
		var m = missions[mission_idx]
		if is_instance_valid(m.agent_portrait):
			c_data.idle_texture = m.agent_portrait
		elif is_instance_valid(c_data.dual_pose_sheet):
			m.agent_portrait = c_data.get_pose_texture(false)
		if m.seedance_video != "":
			c_data.video_loop_path = m.seedance_video

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if history_modal.visible:
				history_modal.visible = false
			elif not title_screen.visible:
				_toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return

		if title_screen.visible or pause_modal.visible or history_modal.visible or is_in_hacking_mode or is_waiting_choice:
			return

		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_on_advance_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_CTRL:
			_toggle_skip_mode()

func _process(delta: float) -> void:
	bg_anim_time += delta
	if is_instance_valid(bg_canvas) and not is_in_hacking_mode and not bg_texture_rect.visible:
		bg_canvas.queue_redraw()

	if title_screen.visible or pause_modal.visible or history_modal.visible or is_in_hacking_mode:
		return

	if is_typing:
		char_progress += delta * typewriter_speed
		var total = dialogue_rtl.get_total_character_count()
		dialogue_rtl.visible_characters = int(char_progress)
		if dialogue_rtl.visible_characters >= total:
			_finish_typing_current_line()
	else:
		if skip_mode and not is_waiting_choice:
			skip_timer += delta
			if skip_timer >= 0.12:
				skip_timer = 0.0
				_advance_story_step()
		elif auto_mode and not is_waiting_choice:
			auto_timer += delta
			if auto_timer >= auto_advance_delay:
				auto_timer = 0.0
				_advance_story_step()

# =========================================================
# 1. INTÉRPRETE DE COMANDOS ESTILO REN'PY
# =========================================================
func start_new_game() -> void:
	title_screen.visible = false
	pause_modal.visible = false
	history_modal.visible = false
	is_in_hacking_mode = false
	hacking_console.visible = false

	story_vars = {
		"mia_affinity": 50,
		"naomi_affinity": 50,
		"maria_affinity": 50,
		"yuri_affinity": 50
	}
	rollback_stack.clear()
	history_rtl.clear()
	_clear_all_stage_actors()
	jump_to_label("start")

func jump_to_label(label_name: String, step_idx: int = 0) -> void:
	if not parsed_labels.has(label_name):
		push_warning("Label no encontrado en el guion: " + label_name)
		return
	current_label = label_name
	current_step = step_idx
	_execute_current_step()

func _execute_current_step() -> void:
	var commands: Array = parsed_labels.get(current_label, [])
	while current_step < commands.size():
		var cmd_data: Dictionary = commands[current_step]
		var cmd_type: String = cmd_data.get("cmd", "say")

		match cmd_type:
			"scene":
				_set_scene_background(cmd_data.get("bg", "bunker"))
				current_step += 1
			"show":
				_show_stage_actor(
					cmd_data.get("char_id", "maria"),
					cmd_data.get("expression", "normal"),
					cmd_data.get("position", "center"),
					cmd_data.get("emote", "")
				)
				current_step += 1
			"hide":
				_hide_stage_actor(cmd_data.get("char_id", "maria"))
				current_step += 1
			"set":
				_apply_variable_expression(cmd_data.get("expr", ""))
				current_step += 1
			"if":
				if _evaluate_condition(cmd_data.get("condition", "")):
					jump_to_label(cmd_data.get("target", "start"))
					return
				current_step += 1
			"jump":
				jump_to_label(cmd_data.get("target", "start"))
				return
			"menu":
				_present_choice_menu(cmd_data.get("options", []))
				return
			"hack":
				_launch_hacking_minigame(cmd_data)
				return
			"end":
				_on_story_ended()
				return
			"say":
				_present_dialogue_line(cmd_data.get("speaker", "narrator"), cmd_data.get("text", ""))
				return
			_:
				current_step += 1

func _present_dialogue_line(speaker_id: String, text: String) -> void:
	_push_rollback_snapshot()
	is_waiting_choice = false
	choice_overlay.visible = false

	var spk_lower = speaker_id.to_lower()
	var display_name = ""
	var name_col = Color("#00f0ff")

	if char_registry.has(spk_lower):
		var c_data: VNCharacterData = char_registry[spk_lower]
		display_name = c_data.display_name.to_upper()
		name_col = c_data.name_color
	elif spk_lower in ["operador", "operator"]:
		display_name = "OPERATOR"
		name_col = Color("#00f0ff")
	elif spk_lower in ["sistema", "narrador", "system", "narrator"]:
		display_name = "SYSTEM"
		name_col = Color("#ffcc00")
	else:
		display_name = speaker_id.to_upper()

	for act_id in active_actors.keys():
		var actor: VNStageActor = active_actors[act_id]
		var is_speaker = (act_id == spk_lower)
		actor.set_talking_state(is_speaker, is_speaker or spk_lower in ["operador", "narrador", "operator", "narrator", "system", "sistema"])

	speaker_name_lbl.text = display_name
	speaker_name_lbl.add_theme_color_override("font_color", name_col)

	dialogue_rtl.text = "[center][b]%s[/b][/center]" % text
	dialogue_rtl.visible_characters = 0
	char_progress = 0.0
	is_typing = true
	auto_timer = 0.0

	history_rtl.append_text("[color=#%s][b][%s]:[/b][/color] %s\n\n" % [name_col.to_html(false), display_name, text])

func _finish_typing_current_line() -> void:
	is_typing = false
	dialogue_rtl.visible_characters = -1
	for act_id in active_actors.keys():
		var actor: VNStageActor = active_actors[act_id]
		actor.set_talking_state(false, actor.is_focused)

func _on_advance_pressed() -> void:
	if is_waiting_choice or is_in_hacking_mode:
		return
	if is_typing:
		_finish_typing_current_line()
		return
	_advance_story_step()

func _advance_story_step() -> void:
	current_step += 1
	_execute_current_step()

# =========================================================
# 2. GESTIÓN DE ACTORES ANIMADOS Y MOVIMIENTO EN ESCENA
# =========================================================
func _show_stage_actor(char_id: String, expr: String, pos_name: String, emote: String) -> void:
	var id_clean = char_id.to_lower()
	if not char_registry.has(id_clean):
		return

	actor_positions[id_clean] = pos_name

	if not active_actors.has(id_clean):
		var actor = VNStageActor.new()
		stage_layer.add_child(actor)
		actor.setup_character(char_registry[id_clean], expr)
		active_actors[id_clean] = actor

		var effective_slot = "center" if active_actors.size() == 1 else pos_name
		var target_x = _get_slot_x(effective_slot, actor.size.x)
		# +18px por debajo del borde inferior para que el corte inferior NUNCA sea visible
		var target_y = size.y - actor.size.y + 18.0
		actor.position = Vector2(target_x, target_y)
		actor.modulate.a = 0.0

		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(actor, "modulate:a", 1.0, 0.25)
		if emote != "":
			actor.play_emote(emote)
	else:
		var actor: VNStageActor = active_actors[id_clean]
		actor.set_expression(expr, emote)

	_reposition_active_actors(true)

func _hide_stage_actor(char_id: String) -> void:
	var id_clean = char_id.to_lower()
	if not active_actors.has(id_clean):
		return
	var actor: VNStageActor = active_actors[id_clean]
	active_actors.erase(id_clean)
	actor_positions.erase(id_clean)
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(actor, "modulate:a", 0.0, 0.22)
	tw.tween_callback(actor.queue_free)

	_reposition_active_actors(true)

func _reposition_active_actors(animate: bool = true) -> void:
	var solo = (active_actors.size() == 1)
	for id_key in active_actors.keys():
		var actor: VNStageActor = active_actors[id_key]
		if not is_instance_valid(actor):
			continue
		var slot = "center" if solo else actor_positions.get(id_key, "center")
		var tx = _get_slot_x(slot, actor.size.x)
		var ty = size.y - actor.size.y + 18.0
		if animate:
			var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(actor, "position", Vector2(tx, ty), 0.25)
		else:
			actor.position = Vector2(tx, ty)

func _clear_all_stage_actors() -> void:
	for id_key in active_actors.keys():
		if is_instance_valid(active_actors[id_key]):
			active_actors[id_key].queue_free()
	active_actors.clear()
	actor_positions.clear()

func _get_slot_x(slot_name: String, actor_width: float = 630.0) -> float:
	var w = max(size.x, 1280.0)
	var half_w = actor_width * 0.5
	match slot_name:
		"left":
			return w * 0.28 - half_w
		"right":
			return w * 0.72 - half_w
		_:
			return w * 0.50 - half_w

func _on_viewport_resized() -> void:
	size = get_viewport_rect().size
	_reposition_active_actors(false)

# =========================================================
# 3. MENÚ DE ELECCIONES (CHOICE MENU) Y VARIABLES
# =========================================================
func _present_choice_menu(options: Array) -> void:
	is_waiting_choice = true
	skip_mode = false
	_update_quick_menu_buttons()

	for child in choice_vbox.get_children():
		child.queue_free()

	var header = Label.new()
	header.text = "⚡ CHOOSE YOUR RESPONSE:"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color("#00ff9d")
	header.add_theme_font_size_override("font_size", 18)
	choice_vbox.add_child(header)

	for opt in options:
		var btn = Button.new()
		btn.text = opt.get("text", "Option")
		btn.custom_minimum_size = Vector2(720, 56)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_pill_choice_button(btn)
		btn.pressed.connect(func(): _on_choice_option_picked(opt))
		choice_vbox.add_child(btn)

	choice_overlay.visible = true

func _on_choice_option_picked(opt: Dictionary) -> void:
	choice_overlay.visible = false
	is_waiting_choice = false

	var opt_txt: String = opt.get("text", "")
	history_rtl.append_text("[color=#00ff9d][b]➤ [CHOICE]: %s[/b][/color]\n\n" % opt_txt)

	var effect_str: String = opt.get("effect", "")
	if effect_str != "":
		_apply_variable_expression(effect_str)

	var target_lbl: String = opt.get("target", "")
	if target_lbl != "":
		jump_to_label(target_lbl)
	else:
		_advance_story_step()

func _apply_variable_expression(expr: String) -> void:
	if expr.contains("+="):
		var parts = expr.split("+=")
		var k = parts[0].strip_edges()
		var v = int(parts[1].strip_edges())
		story_vars[k] = clamp(int(story_vars.get(k, 0)) + v, 0, 100)
	elif expr.contains("-="):
		var parts = expr.split("-=")
		var k = parts[0].strip_edges()
		var v = int(parts[1].strip_edges())
		story_vars[k] = clamp(int(story_vars.get(k, 0)) - v, 0, 100)
	elif expr.contains("="):
		var parts = expr.split("=")
		var k = parts[0].strip_edges()
		var v = int(parts[1].strip_edges())
		story_vars[k] = v

func _evaluate_condition(cond: String) -> bool:
	if cond.contains(">="):
		var parts = cond.split(">=")
		var k = parts[0].strip_edges()
		var v = int(parts[1].strip_edges())
		return int(story_vars.get(k, 0)) >= v
	elif cond.contains("=="):
		var parts = cond.split("==")
		var k = parts[0].strip_edges()
		var v = int(parts[1].strip_edges())
		return int(story_vars.get(k, 0)) == v
	return false

# =========================================================
# 4. INTEGRACIÓN CON EL MINIJUEGO DE HACKEO (OPERATOR CONSOLE)
# =========================================================
func _build_hacking_console_layer() -> void:
	hacking_console = OperatorConsoleScript.new()
	hacking_console.embedded_in_vn_engine = true
	hacking_console.enable_crt_effect = false
	hacking_console.available_missions = missions
	hacking_console.visible = false
	hacking_console.hacking_completed.connect(_on_hacking_minigame_completed)
	add_child(hacking_console)

func _launch_hacking_minigame(cmd_data: Dictionary) -> void:
	var m_idx: int = clamp(int(cmd_data.get("mission_index", 0)), 0, max(0, missions.size() - 1))
	pending_hack_branches = {
		"mission": cmd_data.get("on_mission", ""),
		"romance": cmd_data.get("on_romance", ""),
		"failure": cmd_data.get("on_fail", "")
	}

	is_in_hacking_mode = true
	skip_mode = false
	auto_mode = false
	_update_quick_menu_buttons()

	var m_data: MissionData = missions[m_idx]
	var ag_key = m_data.agent_name.to_lower() + "_affinity"
	if story_vars.has(ag_key):
		m_data.initial_affinity = int(story_vars[ag_key])

	hacking_console.visible = true
	hacking_console.btn_continue_vn.text = "🎭 RETURN TO VISUAL NOVEL >>"
	hacking_console.load_mission(m_data, false)

func _on_hacking_minigame_completed(outcome_type: String, final_affinity: int) -> void:
	hacking_console.visible = false
	is_in_hacking_mode = false

	if is_instance_valid(hacking_console.current_mission):
		var ag_key = hacking_console.current_mission.agent_name.to_lower() + "_affinity"
		story_vars[ag_key] = final_affinity

	var target_branch: String = pending_hack_branches.get(outcome_type, "")
	if target_branch != "" and parsed_labels.has(target_branch):
		jump_to_label(target_branch)
	else:
		_advance_story_step()

# =========================================================
# 5. FONDOS CON DESENFOQUE SUAVE (`scene`)
# =========================================================
func _set_scene_background(bg_id: String) -> void:
	current_bg_id = bg_id.to_lower()

	var loaded_tex: Texture2D = null
	if custom_backgrounds.has(current_bg_id) and is_instance_valid(custom_backgrounds[current_bg_id]):
		loaded_tex = custom_backgrounds[current_bg_id]
	elif ResourceLoader.exists(bg_id):
		loaded_tex = load(bg_id)
	else:
		for ext in ["png", "jpg", "jpeg", "webp"]:
			var candidate = "res://assets/backgrounds/%s.%s" % [current_bg_id, ext]
			if ResourceLoader.exists(candidate):
				loaded_tex = load(candidate)
				break

	if is_instance_valid(loaded_tex):
		bg_texture_rect.texture = loaded_tex
		bg_texture_rect.visible = true
	elif is_instance_valid(default_background):
		bg_texture_rect.texture = default_background
		bg_texture_rect.visible = true
	elif ResourceLoader.exists("res://assets/backgrounds/default_bg.jpg"):
		bg_texture_rect.texture = load("res://assets/backgrounds/default_bg.jpg")
		bg_texture_rect.visible = true
	else:
		bg_texture_rect.visible = false

	bg_texture_rect.modulate = Color(0.35, 0.35, 0.42, 1.0)
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(bg_texture_rect, "modulate", Color.WHITE, 0.35)

func _draw_animated_cyber_background() -> void:
	var s = bg_canvas.size
	bg_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color("#050811"), true)

# =========================================================
# 6. ROLLBACK ("ATRÁS"), GUARDADO / CARGA Y MENÚ DE PAUSA
# =========================================================
func _push_rollback_snapshot() -> void:
	var actor_snap: Dictionary = {}
	for k in active_actors.keys():
		var act: VNStageActor = active_actors[k]
		actor_snap[k] = {
			"expr": act.current_expression,
			"pos": actor_positions.get(k, "center")
		}
	rollback_stack.append({
		"label": current_label,
		"step": current_step,
		"bg": current_bg_id,
		"vars": story_vars.duplicate(),
		"actors": actor_snap
	})
	if rollback_stack.size() > 30:
		rollback_stack.pop_front()

func _on_rollback_pressed() -> void:
	if rollback_stack.size() <= 1:
		return
	rollback_stack.pop_back()
	var prev = rollback_stack.pop_back()
	_restore_snapshot(prev)

func _restore_snapshot(snap: Dictionary) -> void:
	story_vars = snap.get("vars", {}).duplicate()
	_set_scene_background(snap.get("bg", "bunker"))
	_clear_all_stage_actors()
	var saved_actors: Dictionary = snap.get("actors", {})
	for k in saved_actors.keys():
		var info = saved_actors[k]
		_show_stage_actor(k, info.get("expr", "normal"), info.get("pos", "center"), "")
	jump_to_label(snap.get("label", "start"), int(snap.get("step", 0)))

func save_to_slot(slot_idx: int) -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_FILE_PATH)
	var sec = "slot_%d" % slot_idx
	cfg.set_value(sec, "timestamp", Time.get_datetime_string_from_system(false, true))
	cfg.set_value(sec, "label", current_label)
	cfg.set_value(sec, "step", current_step)
	cfg.set_value(sec, "bg", current_bg_id)
	cfg.set_value(sec, "vars", story_vars)

	var actor_snap: Dictionary = {}
	for k in active_actors.keys():
		var act: VNStageActor = active_actors[k]
		actor_snap[k] = {
			"expr": act.current_expression,
			"pos": actor_positions.get(k, "center")
		}
	cfg.set_value(sec, "actors", actor_snap)
	cfg.save(SAVE_FILE_PATH)
	_refresh_save_slots_ui()

func load_from_slot(slot_idx: int) -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_FILE_PATH) != OK:
		return
	var sec = "slot_%d" % slot_idx
	if not cfg.has_section(sec):
		return

	title_screen.visible = false
	pause_modal.visible = false
	is_in_hacking_mode = false
	hacking_console.visible = false

	var snap = {
		"label": cfg.get_value(sec, "label", "start"),
		"step": cfg.get_value(sec, "step", 0),
		"bg": cfg.get_value(sec, "bg", "bunker"),
		"vars": cfg.get_value(sec, "vars", {"maria_affinity": 45, "yuri_affinity": 50}),
		"actors": cfg.get_value(sec, "actors", {})
	}
	_restore_snapshot(snap)

# =========================================================
# 7. CONSTRUCCIÓN VISUAL IDÉNTICA A EXAMPLE.PNG
# =========================================================
func _build_vn_backgrounds() -> void:
	bg_canvas = Control.new()
	bg_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_canvas.draw.connect(_draw_animated_cyber_background)
	add_child(bg_canvas)

	bg_texture_rect = TextureRect.new()
	bg_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_texture_rect.visible = false

	# Shader de desenfoque suave (Depth of Field) en el fondo como en example.png
	var blur_sh = Shader.new()
	blur_sh.code = """
shader_type canvas_item;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.2;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 col = vec4(0.0);
	col += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)) * 0.0625;
	col += texture(TEXTURE, UV + vec2(0.0, -ps.y)) * 0.125;
	col += texture(TEXTURE, UV + vec2(ps.x, -ps.y)) * 0.0625;
	col += texture(TEXTURE, UV + vec2(-ps.x, 0.0)) * 0.125;
	col += texture(TEXTURE, UV) * 0.25;
	col += texture(TEXTURE, UV + vec2(ps.x, 0.0)) * 0.125;
	col += texture(TEXTURE, UV + vec2(-ps.x, ps.y)) * 0.0625;
	col += texture(TEXTURE, UV + vec2(0.0, ps.y)) * 0.125;
	col += texture(TEXTURE, UV + vec2(ps.x, ps.y)) * 0.0625;
	COLOR = col * COLOR;
}
"""
	var blur_mat = ShaderMaterial.new()
	blur_mat.shader = blur_sh
	blur_mat.set_shader_parameter("blur_amount", background_blur_amount)
	bg_texture_rect.material = blur_mat
	add_child(bg_texture_rect)

func _build_stage_layer() -> void:
	stage_layer = Control.new()
	stage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_layer)

func _build_vn_hud_and_dialogue() -> void:
	var custom_font: Font = null
	if ResourceLoader.exists("res://assets/NetflixSans-Bd.ttf"):
		custom_font = load("res://assets/NetflixSans-Bd.ttf")

	# 1. Área clickeable de pantalla completa para avanzar diálogos
	var click_catcher = Control.new()
	click_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_catcher.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_advance_pressed()
	)
	add_child(click_catcher)

	# 2. CAJA DE DIÁLOGO PÍLDORA INFERIOR + NOMBRE FLOTANTE ARRIBA (COMO EXAMPLE.PNG)
	dialogue_container = Control.new()
	dialogue_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_container.custom_minimum_size = Vector2(1103, 265)
	dialogue_container.size = Vector2(1103, 265)
	dialogue_container.offset_left = -551
	dialogue_container.offset_right = 552
	dialogue_container.offset_top = -325
	dialogue_container.offset_bottom = -60
	dialogue_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_container)

	# Píldora translúcida usando Rectángulo 1.png (o StyleBoxFlat idéntico)
	adv_pill_panel = PanelContainer.new()
	adv_pill_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	adv_pill_panel.offset_top = 22
	adv_pill_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	if ResourceLoader.exists("res://assets/menu/Rectángulo 1.png"):
		var tex_style = StyleBoxTexture.new()
		tex_style.texture = load("res://assets/menu/Rectángulo 1.png")
		tex_style.modulate_color = Color(0.12, 0.13, 0.14, 0.68)
		tex_style.content_margin_left = 70
		tex_style.content_margin_right = 70
		tex_style.content_margin_top = 34
		tex_style.content_margin_bottom = 26
		adv_pill_panel.add_theme_stylebox_override("panel", tex_style)
	else:
		var pill_style = StyleBoxFlat.new()
		pill_style.bg_color = Color(0.10, 0.11, 0.12, 0.65)
		pill_style.set_corner_radius_all(120)
		pill_style.content_margin_left = 70
		pill_style.content_margin_right = 70
		pill_style.content_margin_top = 34
		pill_style.content_margin_bottom = 26
		adv_pill_panel.add_theme_stylebox_override("panel", pill_style)

	adv_pill_panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_advance_pressed()
	)
	dialogue_container.add_child(adv_pill_panel)

	var center_text_vbox = VBoxContainer.new()
	center_text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_text_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	adv_pill_panel.add_child(center_text_vbox)

	dialogue_rtl = RichTextLabel.new()
	dialogue_rtl.bbcode_enabled = true
	dialogue_rtl.fit_content = true
	dialogue_rtl.scroll_active = false
	dialogue_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(custom_font):
		dialogue_rtl.add_theme_font_override("normal_font", custom_font)
		dialogue_rtl.add_theme_font_override("bold_font", custom_font)
	dialogue_rtl.add_theme_font_size_override("normal_font_size", 32)
	dialogue_rtl.add_theme_font_size_override("bold_font_size", 32)
	dialogue_rtl.add_theme_color_override("default_color", Color.WHITE)
	dialogue_rtl.add_theme_constant_override("line_separation", 6)
	center_text_vbox.add_child(dialogue_rtl)

	# Nombre del personaje flotando centrado en el borde superior de la píldora (sin contorno negro)
	speaker_name_lbl = Label.new()
	speaker_name_lbl.text = "MARIA"
	speaker_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_name_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	speaker_name_lbl.offset_top = -2
	speaker_name_lbl.offset_bottom = 44
	if is_instance_valid(custom_font):
		speaker_name_lbl.add_theme_font_override("font", custom_font)
	speaker_name_lbl.add_theme_font_size_override("font_size", 33)
	speaker_name_lbl.add_theme_color_override("font_color", Color("#f600ff"))
	dialogue_container.add_child(speaker_name_lbl)

	# 3. ICONO HACKER ARRIBA A LA IZQUIERDA + MENÚ DESPLEGABLE LATERAL HACIA LA DERECHA
	top_left_menu_root = HBoxContainer.new()
	top_left_menu_root.position = Vector2(68, 52)
	top_left_menu_root.add_theme_constant_override("separation", 16)
	add_child(top_left_menu_root)

	btn_hacker_icon = TextureButton.new()
	btn_hacker_icon.custom_minimum_size = Vector2(145, 74)
	btn_hacker_icon.ignore_texture_size = true
	btn_hacker_icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_hacker_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_hacker_icon.pivot_offset = Vector2(72, 37)
	if ResourceLoader.exists("res://assets/menu/menu_display_icon.png"):
		btn_hacker_icon.texture_normal = load("res://assets/menu/menu_display_icon.png")

	# Al pasar el mouse por encima se pone verde neón; al hacer clic despliega el menú hacia la derecha
	btn_hacker_icon.mouse_entered.connect(func():
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn_hacker_icon, "modulate", Color("#00ff66"), 0.14)
		tw.tween_property(btn_hacker_icon, "scale", Vector2(1.08, 1.08), 0.14)
	)
	btn_hacker_icon.mouse_exited.connect(func():
		var target_col = Color("#00ff66") if lateral_menu_open else Color.WHITE
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn_hacker_icon, "modulate", target_col, 0.14)
		tw.tween_property(btn_hacker_icon, "scale", Vector2.ONE, 0.14)
	)
	btn_hacker_icon.pressed.connect(_toggle_lateral_quick_menu)
	top_left_menu_root.add_child(btn_hacker_icon)

	# Contenedor lateral que se despliega hacia la derecha al hacer clic en el icono
	lateral_drawer_panel = PanelContainer.new()
	var drawer_style = StyleBoxFlat.new()
	drawer_style.bg_color = Color(0.05, 0.08, 0.10, 0.86)
	drawer_style.border_color = Color("#00ff66")
	drawer_style.set_border_width_all(1)
	drawer_style.set_corner_radius_all(28)
	drawer_style.content_margin_left = 18
	drawer_style.content_margin_right = 18
	drawer_style.content_margin_top = 8
	drawer_style.content_margin_bottom = 8
	lateral_drawer_panel.add_theme_stylebox_override("panel", drawer_style)
	lateral_drawer_panel.visible = false
	lateral_drawer_panel.modulate.a = 0.0
	top_left_menu_root.add_child(lateral_drawer_panel)

	var qm_hbox = HBoxContainer.new()
	qm_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qm_hbox.add_theme_constant_override("separation", 10)
	lateral_drawer_panel.add_child(qm_hbox)

	var btn_back = _create_quick_menu_btn("◀ BACK", _on_rollback_pressed)
	var btn_hist = _create_quick_menu_btn("📜 HISTORY", func(): history_modal.visible = true)
	btn_qm_skip = _create_quick_menu_btn("⏭ SKIP", _toggle_skip_mode)
	btn_qm_auto = _create_quick_menu_btn("▶ AUTO", _toggle_auto_mode)
	var btn_qsave = _create_quick_menu_btn("💾 Q. SAVE", func(): save_to_slot(1))
	var btn_qload = _create_quick_menu_btn("📂 Q. LOAD", func(): load_from_slot(1))
	var btn_prefs = _create_quick_menu_btn("⚙️ MENU / PAUSE", _toggle_pause_menu)

	for b in [btn_back, btn_hist, btn_qm_skip, btn_qm_auto, btn_qsave, btn_qload, btn_prefs]:
		qm_hbox.add_child(b)

func _toggle_lateral_quick_menu() -> void:
	lateral_menu_open = not lateral_menu_open
	if lateral_menu_open:
		lateral_drawer_panel.visible = true
		lateral_drawer_panel.scale = Vector2(0.85, 1.0)
		btn_hacker_icon.modulate = Color("#00ff66")
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(lateral_drawer_panel, "modulate:a", 1.0, 0.20)
		tw.tween_property(lateral_drawer_panel, "scale:x", 1.0, 0.20)
	else:
		btn_hacker_icon.modulate = Color.WHITE
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(lateral_drawer_panel, "modulate:a", 0.0, 0.16)
		tw.tween_property(lateral_drawer_panel, "scale:x", 0.85, 0.16)
		tw.chain().tween_callback(func(): lateral_drawer_panel.visible = false)

func _create_quick_menu_btn(txt: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 14)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_drawer_button(btn, false)
	btn.pressed.connect(callback)
	return btn

func _style_drawer_button(btn: Button, active_state: bool) -> void:
	var st_norm = StyleBoxFlat.new()
	st_norm.bg_color = Color(0.0, 1.0, 0.4, 0.22) if active_state else Color(1, 1, 1, 0.05)
	st_norm.set_corner_radius_all(18)
	st_norm.content_margin_left = 12
	st_norm.content_margin_right = 12
	st_norm.content_margin_top = 6
	st_norm.content_margin_bottom = 6

	var st_hov = st_norm.duplicate()
	st_hov.bg_color = Color(0.0, 1.0, 0.4, 0.28)

	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hov)
	btn.add_theme_stylebox_override("pressed", st_hov)
	btn.add_theme_color_override("font_color", Color("#00ff66") if active_state else Color("#e6f2ec"))
	btn.add_theme_color_override("font_hover_color", Color("#00ff66"))

func _style_pill_choice_button(btn: Button) -> void:
	var st_norm = StyleBoxFlat.new()
	st_norm.bg_color = Color(0.06, 0.08, 0.10, 0.85)
	st_norm.border_color = Color(1.0, 1.0, 1.0, 0.25)
	st_norm.set_border_width_all(1)
	st_norm.set_corner_radius_all(28)
	st_norm.content_margin_left = 24
	st_norm.content_margin_right = 24
	st_norm.content_margin_top = 12
	st_norm.content_margin_bottom = 12

	var st_hov = st_norm.duplicate()
	st_hov.bg_color = Color(0.08, 0.22, 0.16, 0.92)
	st_hov.border_color = Color("#00ff66")
	st_hov.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hov)
	btn.add_theme_stylebox_override("pressed", st_hov)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color("#00ff66"))

func _toggle_auto_mode() -> void:
	auto_mode = not auto_mode
	if auto_mode:
		skip_mode = false
	auto_timer = 0.0
	_update_quick_menu_buttons()

func _toggle_skip_mode() -> void:
	skip_mode = not skip_mode
	if skip_mode:
		auto_mode = false
	skip_timer = 0.0
	_update_quick_menu_buttons()

func _update_quick_menu_buttons() -> void:
	if is_instance_valid(btn_qm_auto):
		btn_qm_auto.text = "▶ AUTO: ON" if auto_mode else "▶ AUTO"
		_style_drawer_button(btn_qm_auto, auto_mode)
	if is_instance_valid(btn_qm_skip):
		btn_qm_skip.text = "⏭ SKIP: ON" if skip_mode else "⏭ SKIP"
		_style_drawer_button(btn_qm_skip, skip_mode)

func _build_choice_overlay() -> void:
	choice_overlay = CenterContainer.new()
	choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_overlay.offset_bottom = -240
	choice_overlay.visible = false
	add_child(choice_overlay)

	var panel = _create_panel(Color(0.04, 0.06, 0.09, 0.88), Color("#00ff66"), 1, 22)
	choice_overlay.add_child(panel)

	choice_vbox = VBoxContainer.new()
	choice_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(choice_vbox)

# =========================================================
# 8. MENÚ DE PAUSA, GUARDADO/CARGA Y AJUSTES (`ESC`)
# =========================================================
func _build_pause_and_save_menu() -> void:
	pause_modal = ColorRect.new()
	pause_modal.color = Color(0.02, 0.04, 0.07, 0.88)
	pause_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.visible = false
	add_child(pause_modal)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(center)

	var card = _create_panel(Color("#080e17"), Color("#00f0ff"), 2, 20)
	card.custom_minimum_size = Vector2(760, 500)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)

	var title = Label.new()
	title.text = "⚙️ PAUSE MENU // SAVE & SETTINGS"
	title.modulate = Color("#00f0ff")
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	var btn_resume = Button.new()
	btn_resume.text = "▶ RESUME [ESC]"
	_style_button(btn_resume, Color("#00ff9d"), true)
	btn_resume.pressed.connect(_toggle_pause_menu)
	top_bar.add_child(btn_resume)

	pause_tabs = TabContainer.new()
	pause_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(pause_tabs)

	var slots_margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		slots_margin.add_theme_constant_override("margin_" + side, 12)
	pause_tabs.add_child(slots_margin)
	pause_tabs.set_tab_title(0, "💾 SAVE / LOAD GAME")

	save_slots_vbox = VBoxContainer.new()
	save_slots_vbox.add_theme_constant_override("separation", 12)
	slots_margin.add_child(save_slots_vbox)

	var prefs_margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		prefs_margin.add_theme_constant_override("margin_" + side, 14)
	pause_tabs.add_child(prefs_margin)
	pause_tabs.set_tab_title(1, "🎛️ TEXT & DISPLAY SETTINGS")

	var prefs_vbox = VBoxContainer.new()
	prefs_vbox.add_theme_constant_override("separation", 16)
	prefs_margin.add_child(prefs_vbox)

	var lbl_spd = Label.new()
	lbl_spd.text = "Text Speed (Typewriter): 55 cps"
	prefs_vbox.add_child(lbl_spd)

	var sld_spd = HSlider.new()
	sld_spd.min_value = 20.0
	sld_spd.max_value = 140.0
	sld_spd.value = typewriter_speed
	sld_spd.value_changed.connect(func(v):
		typewriter_speed = v
		lbl_spd.text = "Text Speed (Typewriter): %d cps" % int(v)
	)
	prefs_vbox.add_child(sld_spd)

	var btn_fullscreen = Button.new()
	btn_fullscreen.text = "🖥️ TOGGLE FULLSCREEN / WINDOWED"
	_style_button(btn_fullscreen, Color("#00f0ff"), false)
	btn_fullscreen.pressed.connect(func():
		var mode = DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	)
	prefs_vbox.add_child(btn_fullscreen)

	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom_bar)

	var btn_to_title = Button.new()
	btn_to_title.text = "🏠 RETURN TO MAIN MENU"
	btn_to_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(btn_to_title, Color("#ffaa00"), false)
	btn_to_title.pressed.connect(func():
		pause_modal.visible = false
		hacking_console.visible = false
		is_in_hacking_mode = false
		title_screen.visible = true
	)
	bottom_bar.add_child(btn_to_title)

	var btn_quit = Button.new()
	btn_quit.text = "✕ QUIT GAME"
	btn_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(btn_quit, Color("#ff3366"), false)
	btn_quit.pressed.connect(func(): get_tree().quit())
	bottom_bar.add_child(btn_quit)

	_refresh_save_slots_ui()

func _refresh_save_slots_ui() -> void:
	if not is_instance_valid(save_slots_vbox):
		return
	for ch in save_slots_vbox.get_children():
		ch.queue_free()

	var cfg = ConfigFile.new()
	cfg.load(SAVE_FILE_PATH)

	for slot in range(1, 4):
		var sec = "slot_%d" % slot
		var has_data = cfg.has_section(sec)
		var row_panel = _create_panel(Color("#0c1624"), Color("#1e3448"), 1, 10)
		save_slots_vbox.add_child(row_panel)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)

		var info_lbl = Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if has_data:
			var ts = cfg.get_value(sec, "timestamp", "")
			var lbl_name = cfg.get_value(sec, "label", "start")
			info_lbl.text = "SLOT %d  —  [%s]  //  Scene: %s" % [slot, ts, str(lbl_name).to_upper()]
			info_lbl.modulate = Color("#00ff9d")
		else:
			info_lbl.text = "SLOT %d  —  [EMPTY]" % slot
			info_lbl.modulate = Color("#667788")
		row.add_child(info_lbl)

		var btn_save = Button.new()
		btn_save.text = "💾 SAVE"
		_style_button(btn_save, Color("#00f0ff"), false)
		btn_save.pressed.connect(func(): save_to_slot(slot))
		row.add_child(btn_save)

		var btn_load = Button.new()
		btn_load.text = "📂 LOAD"
		btn_load.disabled = not has_data
		_style_button(btn_load, Color("#00ff9d"), false)
		btn_load.pressed.connect(func(): load_from_slot(slot))
		row.add_child(btn_load)

func _toggle_pause_menu() -> void:
	pause_modal.visible = not pause_modal.visible
	if pause_modal.visible:
		_refresh_save_slots_ui()

# =========================================================
# 9. PANTALLA DE TÍTULO PRINCIPAL Y MODAL DE HISTORIAL
# =========================================================
func _build_title_screen() -> void:
	title_screen = ColorRect.new()
	title_screen.color = Color(0.02, 0.04, 0.08, 0.94)
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_screen)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(center)

	var card = _create_panel(Color("#080e18"), Color("#00f0ff"), 2, 28)
	card.custom_minimum_size = Vector2(640, 460)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var tag = _create_badge("DATING SIM + 2D HORROR CONTAINMENT & HACKING", Color("#05080d"), Color("#00f0ff"))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tag)

	var main_title = Label.new()
	main_title.text = "P R O Y E C T  —  Z E R O"
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.add_theme_font_size_override("font_size", 36)
	main_title.modulate = Color("#ffffff")
	vbox.add_child(main_title)

	var subtitle = Label.new()
	subtitle.text = "5 Security Levels // Choose Your Hacking Companion & Security Guard"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color("#b829ff")
	vbox.add_child(subtitle)

	var sep = Control.new()
	sep.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(sep)

	var btn_new = Button.new()
	btn_new.text = "▶  START NIGHT SHIFT (DATING SIM + CONTAINMENT)"
	btn_new.custom_minimum_size = Vector2(0, 48)
	btn_new.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(btn_new, Color("#00ff9d"), true)
	btn_new.pressed.connect(start_new_game)
	vbox.add_child(btn_new)

	var btn_load_menu = Button.new()
	btn_load_menu.text = "📂  CONTINUE / LOAD GAME"
	btn_load_menu.custom_minimum_size = Vector2(0, 44)
	btn_load_menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(btn_load_menu, Color("#00f0ff"), true)
	btn_load_menu.pressed.connect(func():
		_refresh_save_slots_ui()
		pause_tabs.current_tab = 0
		pause_modal.visible = true
	)
	vbox.add_child(btn_load_menu)

	var btn_direct_hack = Button.new()
	btn_direct_hack.text = "💻  DIRECT ACCESS: CONTAINMENT CONSOLE (FNAF 2D)"
	btn_direct_hack.custom_minimum_size = Vector2(0, 44)
	btn_direct_hack.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(btn_direct_hack, Color("#b829ff"), true)
	btn_direct_hack.pressed.connect(func():
		title_screen.visible = false
		_launch_hacking_minigame({"mission_index": 0, "on_mission": "mia_survived", "on_romance": "mia_romance", "on_fail": "night_breach_mia"})
	)
	vbox.add_child(btn_direct_hack)

	var btn_settings = Button.new()
	btn_settings.text = "⚙️  SETTINGS & DISPLAY"
	btn_settings.custom_minimum_size = Vector2(0, 42)
	_style_button(btn_settings, Color("#88aacc"), false)
	btn_settings.pressed.connect(func():
		pause_tabs.current_tab = 1
		pause_modal.visible = true
	)
	vbox.add_child(btn_settings)

	var btn_exit = Button.new()
	btn_exit.text = "✕  EXIT TO DESKTOP"
	btn_exit.custom_minimum_size = Vector2(0, 40)
	_style_button(btn_exit, Color("#ff3366"), false)
	btn_exit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_exit)

func _build_history_modal() -> void:
	history_modal = _create_panel(Color(0.02, 0.04, 0.08, 0.96), Color("#00f0ff"), 2, 18)
	history_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	history_modal.offset_left = 100
	history_modal.offset_top = 70
	history_modal.offset_right = -100
	history_modal.offset_bottom = -70
	history_modal.visible = false
	add_child(history_modal)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	history_modal.add_child(vbox)

	var top = HBoxContainer.new()
	vbox.add_child(top)

	var lbl = Label.new()
	lbl.text = "📜 DIALOGUE & DECISION LOG"
	lbl.modulate = Color("#00f0ff")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lbl)

	var btn_close = Button.new()
	btn_close.text = "✕ CLOSE"
	_style_button(btn_close, Color("#ff3366"), false)
	btn_close.pressed.connect(func(): history_modal.visible = false)
	top.add_child(btn_close)

	history_rtl = RichTextLabel.new()
	history_rtl.bbcode_enabled = true
	history_rtl.scroll_following = true
	history_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(history_rtl)

func _on_story_ended() -> void:
	title_screen.visible = true

# =========================================================
# 10. SHADER CRT Y HELPERS DE ESTILO
# =========================================================
func _build_crt_layer() -> void:
	var rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 uv = SCREEN_UV;
	float shift = 0.0008 * intensity;
	float r = texture(SCREEN_TEXTURE, uv + vec2(shift, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(shift, 0.0)).b;
	vec3 col = vec3(r, g, b);

	float scanline = sin(uv.y * 900.0) * (0.035 * intensity);
	col -= scanline;

	COLOR = vec4(col, 1.0);
}
"""
	crt_material = ShaderMaterial.new()
	crt_material.shader = sh
	crt_material.set_shader_parameter("intensity", crt_intensity)
	rect.material = crt_material
	add_child(rect)

func _create_panel(bg_col: Color, border_col: Color, border_w: int = 1, pad: int = 10) -> PanelContainer:
	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(border_w)
	st.border_width_left = max(border_w, 3)
	st.set_corner_radius_all(5)
	st.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", st)
	return p

func _create_badge(txt: String, font_col: Color, bg_col: Color) -> Label:
	var lbl = Label.new()
	_update_badge(lbl, txt, font_col, bg_col)
	return lbl

func _update_badge(lbl: Label, txt: String, font_col: Color, bg_col: Color) -> void:
	lbl.text = "  " + txt + "  "
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", font_col)
	var st = StyleBoxFlat.new()
	st.bg_color = bg_col
	st.set_corner_radius_all(3)
	st.set_content_margin_all(4)
	lbl.add_theme_stylebox_override("normal", st)

func _style_button(btn: Button, col: Color, prominent: bool = true) -> void:
	var alpha = 0.22 if prominent else 0.12
	var st_norm = StyleBoxFlat.new()
	st_norm.bg_color = Color(col.r * alpha, col.g * alpha, col.b * alpha, 0.95)
	st_norm.border_color = col
	st_norm.set_border_width_all(2 if prominent else 1)
	st_norm.set_corner_radius_all(4)
	st_norm.set_content_margin_all(8)

	var st_hov = st_norm.duplicate()
	st_hov.bg_color = Color(col.r * 0.38, col.g * 0.38, col.b * 0.38, 1.0)
	st_hov.border_color = col.lightened(0.3)

	var st_dis = st_norm.duplicate()
	st_dis.bg_color = Color(0.07, 0.09, 0.13, 0.6)
	st_dis.border_color = Color(0.2, 0.25, 0.3, 0.5)

	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hov)
	btn.add_theme_stylebox_override("pressed", st_hov)
	btn.add_theme_stylebox_override("disabled", st_dis)
	btn.add_theme_color_override("font_color", col.lightened(0.38))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("#556677"))
