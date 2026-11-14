extends Node3D

const OperatorConsoleScript = preload("res://operator_console.gd")

@export var available_missions: Array[MissionData] = []
@export var screen_resolution: Vector2i = Vector2i(1600, 900)
@export var screen_size_meters: Vector2 = Vector2(1.92, 1.08)
@export var enable_camera_parallax: bool = true


@export_group("Estética PS1 / PS2 (Toda la Escena)")
@export_range(1.0, 6.0, 1.0) var psx_pixel_scale: float = 1.2 # 2.0 = PS2 nítido, 3.0 = PS1/PS2 ideal, 4.0 = PS1 crudo
@export_range(60.0, 240.0, 10.0) var psx_vertex_jitter: float = 130.0 # Temblor de vértices 3D en toda la habitación
@export_range(16.0, 64.0, 1.0) var psx_color_depth: float = 28.0 # 28-32 = Color 15-bit clásico

var ui_viewport: SubViewport
var console_ui: Control
var screen_mesh_instance: MeshInstance3D
var screen_area_3d: Area3D
var main_cam: Camera3D
var alarm_light: OmniLight3D
var base_cam_pos: Vector3 = Vector3(0.0, 1.17, 1.44)
var base_cam_rot: Vector3 = Vector3(-2.0, 0.0, 0.0)
var time_acc: float = 0.0

func _ready() -> void:
	_build_subviewport_and_ui()
	_build_3d_bunker_room_and_monitor()
	_setup_screen_raycast_interaction()
	_setup_psx_post_process()

	await get_tree().process_frame
	if is_instance_valid(console_ui):
		console_ui.size = Vector2(screen_resolution)
	if is_instance_valid(screen_mesh_instance) and is_instance_valid(ui_viewport):
		var mat := screen_mesh_instance.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("screen_tex", ui_viewport.get_texture())
	if is_instance_valid(alarm_light) and is_instance_valid(console_ui):
		var urgent: bool = console_ui.monster_attack_active or console_ui.bunker_temperature >= 55.0 or console_ui.music_box_charge < 45.0
		var spd: float = 6.5 if urgent else 1.8
		alarm_light.light_energy = 1.8 + sin(time_acc * spd) * 1.0

func _process(delta: float) -> void:
	time_acc += delta

	if is_instance_valid(alarm_light) and is_instance_valid(console_ui):
		var urgent: bool = console_ui.monster_attack_active or console_ui.bunker_temperature >= 55.0
		var spd: float = 5.0 if urgent else 1.8
		alarm_light.light_energy = 1.8 + sin(time_acc * spd) * 1.0

	if enable_camera_parallax and is_instance_valid(main_cam):
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		if vp_size.x > 10 and vp_size.y > 10:
			var m_pos: Vector2 = get_viewport().get_mouse_position()
			var norm_x: float = clampf((m_pos.x / vp_size.x) * 2.0 - 1.0, -1.0, 1.0)
			var norm_y: float = clampf((m_pos.y / vp_size.y) * 2.0 - 1.0, -1.0, 1.0)

			var target_pos := base_cam_pos + Vector3(norm_x * 0.05, -norm_y * 0.035, 0.0)
			var target_rot := base_cam_rot + Vector3(-norm_y * 1.6, -norm_x * 2.5, 0.0)
			main_cam.position = main_cam.position.lerp(target_pos, delta * 6.0)
			main_cam.rotation_degrees = main_cam.rotation_degrees.lerp(target_rot, delta * 6.0)

# =========================================================
# 1. SUBVIEWPORT CON TEXTURA NEAREST (SIN FILTRADO BORROSO)
# =========================================================
func _build_subviewport_and_ui() -> void:
	ui_viewport = SubViewport.new()
	ui_viewport.name = "UIViewport"
	ui_viewport.size = screen_resolution
	ui_viewport.transparent_bg = false
	ui_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	ui_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ui_viewport.handle_input_locally = true
	ui_viewport.gui_embed_subwindows = true
	add_child(ui_viewport)

	console_ui = OperatorConsoleScript.new()
	console_ui.set("embedded_in_3d_monitor", true)
	if not available_missions.is_empty():
		console_ui.available_missions = available_missions
	ui_viewport.add_child(console_ui)
	console_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	console_ui.size = Vector2(screen_resolution)

# =========================================================
# 2. SHADER 3D DE PS1 (VERTEX LIGHTING + VERTEX SNAPPING + RUIDO LOW-RES)
# =========================================================
func _create_psx_room_material(base_col: Color, checker_contrast: float = 0.12) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """
shader_type spatial;
render_mode vertex_lighting, specular_disabled, ambient_light_disabled;

uniform vec4 albedo_color : source_color = vec4(0.15, 0.18, 0.20, 1.0);
uniform float jitter_res = 115.0;
uniform float tex_contrast = 0.12;

varying vec3 v_world_pos;

float hash_psx(vec2 p) {
	return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Encajar cada vértice 3D a una grilla baja en pantalla (Temblor de polígonos de PS1)
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	clip_pos.xy = floor(clip_pos.xy / clip_pos.w * jitter_res + 0.5) / jitter_res * clip_pos.w;
	POSITION = clip_pos;
}

void fragment() {
	// Textura procedural pixelada de 32px por metro (estilo textura de PS1 sin filtrado)
	vec2 low_uv = floor((v_world_pos.xy + v_world_pos.zy) * 28.0);
	float n = hash_psx(low_uv);
	float grunge = mix(1.0 - tex_contrast, 1.0 + tex_contrast, n);
	ALBEDO = albedo_color.rgb * grunge;
	ROUGHNESS = 1.0;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_color", base_col)
	mat.set_shader_parameter("jitter_res", psx_vertex_jitter)
	mat.set_shader_parameter("tex_contrast", checker_contrast)
	return mat

func _create_psx_screen_material(vp_tex: ViewportTexture) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_tex : source_color, filter_nearest;
uniform float jitter_res = 160.0;

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	clip_pos.xy = floor(clip_pos.xy / clip_pos.w * jitter_res + 0.5) / jitter_res * clip_pos.w;
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = texture(screen_tex, UV).rgb;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("screen_tex", vp_tex)
	mat.set_shader_parameter("jitter_res", psx_vertex_jitter * 1.4)
	return mat

# =========================================================
# 3. CUARTO 3D CON GEOMETRÍA LOW-POLY Y NIEBLA DENSA DE PS1/PS2
# =========================================================
func _build_3d_bunker_room_and_monitor() -> void:
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#020304")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#182228")
	env.ambient_light_energy = 0.9
	# Niebla densa clásica de PS1/PS2 para fundir el fondo
	env.fog_enabled = true
	env.fog_light_color = Color("#040608")
	env.fog_density = 0.22
	we.environment = env
	add_child(we)

	main_cam = Camera3D.new()
	main_cam.position = base_cam_pos
	main_cam.rotation_degrees = base_cam_rot
	main_cam.fov = 48.0
	main_cam.current = true
	add_child(main_cam)
	main_cam.make_current()

	alarm_light = OmniLight3D.new()
	alarm_light.position = Vector3(-1.05, 1.85, 0.35)
	alarm_light.light_color = Color("#ff2a1a")
	alarm_light.light_energy = 2.4
	alarm_light.omni_range = 4.2
	add_child(alarm_light)

	var desk_light = OmniLight3D.new()
	desk_light.position = Vector3(0.55, 1.75, 0.95)
	desk_light.light_color = Color("#6699aa")
	desk_light.light_energy = 1.1
	desk_light.omni_range = 4.2
	add_child(desk_light)

	# Materiales PS1 con Vertex Snapping y textura pixelada
	var desk_mat = _create_psx_room_material(Color("#1b2226"), 0.16)
	var wall_mat = _create_psx_room_material(Color("#12171b"), 0.20)
	var bezel_mat = _create_psx_room_material(Color("#262e33"), 0.14)
	var pipe_mat = _create_psx_room_material(Color("#2d1f1a"), 0.22) # Caños oxidados

	# Mesa metálica (Con subdivisiones para que el vertex_lighting de PS1 dibuje triángulos de luz)
	var desk_mi = MeshInstance3D.new()
	var desk_box = BoxMesh.new()
	desk_box.size = Vector3(3.4, 0.12, 1.6)
	desk_box.subdivide_width = 8
	desk_box.subdivide_depth = 4
	desk_mi.mesh = desk_box
	desk_mi.material_override = desk_mat
	desk_mi.position = Vector3(0.0, 0.52, 0.35)
	add_child(desk_mi)

	# Pared de fondo subdividida para iluminación por vértices
	var wall_mi = MeshInstance3D.new()
	var wall_box = BoxMesh.new()
	wall_box.size = Vector3(4.5, 3.2, 0.15)
	wall_box.subdivide_width = 10
	wall_box.subdivide_height = 6
	wall_mi.mesh = wall_box
	wall_mi.material_override = wall_mat
	wall_mi.position = Vector3(0.0, 1.6, -0.55)
	add_child(wall_mi)

	# Caños industriales LOW-POLY (6 lados octagonales estilo PS1)
	var pipe_cyl = CylinderMesh.new()
	pipe_cyl.top_radius = 0.055
	pipe_cyl.bottom_radius = 0.055
	pipe_cyl.height = 3.2
	pipe_cyl.radial_segments = 6
	pipe_cyl.rings = 4
	for px in [-1.15, -0.92, 0.98, 1.22]:
		var pm = MeshInstance3D.new()
		pm.mesh = pipe_cyl
		pm.material_override = pipe_mat
		pm.position = Vector3(px, 1.6, -0.42)
		add_child(pm)

	# Taza LOW-POLY de 7 caras en el escritorio (Bien facetada estilo PS1)
	var mug_mi = MeshInstance3D.new()
	var mug_cyl = CylinderMesh.new()
	mug_cyl.top_radius = 0.07
	mug_cyl.bottom_radius = 0.062
	mug_cyl.height = 0.15
	mug_cyl.radial_segments = 7
	mug_cyl.rings = 2
	mug_mi.mesh = mug_cyl
	mug_mi.material_override = _create_psx_room_material(Color("#3a332c"), 0.18)
	mug_mi.position = Vector3(-0.88, 0.65, 0.68)
	add_child(mug_mi)

	# NODO DEL MONITOR 3D
	var monitor_pivot = Node3D.new()
	monitor_pivot.name = "MonitorPivot3D"
	monitor_pivot.position = Vector3(0.0, 1.13, 0.0)
	monitor_pivot.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	add_child(monitor_pivot)

	var back_case = MeshInstance3D.new()
	var case_box = BoxMesh.new()
	case_box.size = Vector3(screen_size_meters.x + 0.22, screen_size_meters.y + 0.16, 0.18)
	case_box.subdivide_width = 4
	case_box.subdivide_height = 4
	back_case.mesh = case_box
	back_case.material_override = bezel_mat
	back_case.position = Vector3(0.0, 0.0, -0.095)
	monitor_pivot.add_child(back_case)

	var frame_thickness: float = 0.08
	var top_b = MeshInstance3D.new()
	var h_bar = BoxMesh.new()
	h_bar.size = Vector3(screen_size_meters.x + frame_thickness * 2.0, frame_thickness, 0.05)
	h_bar.subdivide_width = 6
	top_b.mesh = h_bar
	top_b.material_override = bezel_mat
	top_b.position = Vector3(0.0, screen_size_meters.y * 0.5 + frame_thickness * 0.5, 0.015)
	monitor_pivot.add_child(top_b)

	var bot_b = MeshInstance3D.new()
	bot_b.mesh = h_bar
	bot_b.material_override = bezel_mat
	bot_b.position = Vector3(0.0, -screen_size_meters.y * 0.5 - frame_thickness * 0.5, 0.015)
	monitor_pivot.add_child(bot_b)

	var v_bar = BoxMesh.new()
	v_bar.size = Vector3(frame_thickness, screen_size_meters.y, 0.05)
	v_bar.subdivide_height = 4
	for side_s in [-1.0, 1.0]:
		var sb = MeshInstance3D.new()
		sb.mesh = v_bar
		sb.material_override = bezel_mat
		sb.position = Vector3(side_s * (screen_size_meters.x * 0.5 + frame_thickness * 0.5), 0.0, 0.015)
		monitor_pivot.add_child(sb)

	# PANTALLA 3D SUBDIVIDIDA CON VERTEX SNAPPING
	screen_mesh_instance = MeshInstance3D.new()
	screen_mesh_instance.name = "MonitorScreen"
	var quad = QuadMesh.new()
	quad.size = screen_size_meters
	quad.subdivide_width = 6
	quad.subdivide_depth = 4
	screen_mesh_instance.mesh = quad
	screen_mesh_instance.material_override = _create_psx_screen_material(ui_viewport.get_texture())
	monitor_pivot.add_child(screen_mesh_instance)

	screen_area_3d = Area3D.new()
	screen_area_3d.name = "ScreenArea3D"
	screen_area_3d.input_ray_pickable = true
	monitor_pivot.add_child(screen_area_3d)

	var col_shape = CollisionShape3D.new()
	var box_col = BoxShape3D.new()
	box_col.size = Vector3(screen_size_meters.x, screen_size_meters.y, 0.02)
	col_shape.shape = box_col
	screen_area_3d.add_child(col_shape)

# =========================================================
# 4. POST-PROCESO DE PANTALLA COMPLETA (PIXELADO + DITHERING EN TODA LA ESCENA)
# =========================================================
func _setup_psx_post_process() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 120
	add_child(canvas_layer)

	var psx_rect = ColorRect.new()
	psx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	psx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float pixel_scale = 3.0;
uniform float color_depth = 28.0;
uniform float dither_strength = 0.55;

const mat4 bayer_matrix = mat4(
	vec4(-0.5, 0.0, -0.375, 0.125),
	vec4(0.25, -0.25, 0.375, -0.125),
	vec4(-0.3125, 0.1875, -0.4375, 0.0625),
	vec4(0.4375, -0.0625, 0.3125, -0.1875)
);

void fragment() {
	vec2 tex_size = vec2(textureSize(SCREEN_TEXTURE, 0));
	vec2 target_res = max(vec2(1.0), floor(tex_size / pixel_scale));
	vec2 grid_uv = (floor(SCREEN_UV * target_res) + 0.5) / target_res;
	vec3 col = texture(SCREEN_TEXTURE, grid_uv).rgb;

	ivec2 p_coord = ivec2(floor(FRAGCOORD.xy / pixel_scale)) % 4;
	float dither = bayer_matrix[p_coord.x][p_coord.y];

	col += (dither * dither_strength) / color_depth;
	col = floor(col * color_depth + 0.5) / color_depth;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("pixel_scale", psx_pixel_scale)
	mat.set_shader_parameter("color_depth", psx_color_depth)
	psx_rect.material = mat
	canvas_layer.add_child(psx_rect)

func _setup_screen_raycast_interaction() -> void:
	screen_area_3d.input_event.connect(_on_screen_area_3d_input_event)

func _on_screen_area_3d_input_event(_camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not (event is InputEventMouse):
		return

	var local_hit: Vector3 = screen_mesh_instance.to_local(event_position)
	var uv_x: float = (local_hit.x / screen_size_meters.x) + 0.5
	var uv_y: float = 0.5 - (local_hit.y / screen_size_meters.y)
	var uv := Vector2(clampf(uv_x, 0.0, 1.0), clampf(uv_y, 0.0, 1.0))

	var pixel_pos := Vector2(uv.x * float(screen_resolution.x), uv.y * float(screen_resolution.y))

	var vp_event: InputEventMouse = event.duplicate()
	vp_event.position = pixel_pos
	vp_event.global_position = pixel_pos
	ui_viewport.push_input(vp_event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and is_instance_valid(ui_viewport):
		ui_viewport.push_input(event)
