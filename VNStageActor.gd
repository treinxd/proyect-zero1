class_name VNStageActor
extends Control

var character_id: String = ""
var character_data: VNCharacterData
var current_expression: String = "normal"
var is_talking: bool = false
var is_focused: bool = true

var anim_time: float = 0.0
var blink_timer: float = 0.0
var is_blinking: bool = false
var talk_energy: float = 0.0
var talk_flap_timer: float = 0.0
var showing_talking_pose: bool = false

var cached_idle_tex: Texture2D
var cached_talk_tex: Texture2D
var chroma_mat: ShaderMaterial

var visual_root: Control
var procedural_canvas: Control
var texture_rect: TextureRect
var anim_sprite: AnimatedSprite2D
var video_player: VideoStreamPlayer

func _init() -> void:
	# Proporción exacta 0.6388 igual al recorte del sprite (368x576) para que NUNCA quede espacio vacío abajo
	custom_minimum_size = Vector2(630, 986)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	size = custom_minimum_size
	pivot_offset = Vector2(size.x * 0.5, size.y)
	anim_time = randf() * TAU
	blink_timer = randf_range(1.8, 4.2)

	visual_root = Control.new()
	visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual_root)

	procedural_canvas = Control.new()
	procedural_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	procedural_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	procedural_canvas.draw.connect(_draw_procedural_animated_avatar)
	visual_root.add_child(procedural_canvas)

	texture_rect = TextureRect.new()
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# STRETCH_SCALE con la proporción exacta garantiza que la base del vestido toque el píxel inferior sin flotar jamás
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chroma_mat = _create_chroma_key_and_rim_material()
	visual_root.add_child(texture_rect)

	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.position = custom_minimum_size * 0.5
	visual_root.add_child(anim_sprite)

	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_player.visible = false
	video_player.finished.connect(func(): video_player.play())
	visual_root.add_child(video_player)

func setup_character(data: VNCharacterData, expr: String = "normal") -> void:
	character_data = data
	character_id = data.id
	_rebuild_pose_textures()
	set_expression(expr)

func _rebuild_pose_textures() -> void:
	if not is_instance_valid(character_data):
		return
	cached_idle_tex = character_data.get_pose_texture(false)
	cached_talk_tex = character_data.get_pose_texture(true)

	# Si el sprite ya es un PNG con transparencia en las esquinas (como maria_sheet.png),
	# no usamos shader para mantener el 100% del brillo y color original.
	var needs_chroma_shader = false
	var src_tex = character_data.dual_pose_sheet if is_instance_valid(character_data.dual_pose_sheet) else cached_idle_tex
	if is_instance_valid(src_tex) and character_data.remove_solid_bg:
		var img = src_tex.get_image()
		if is_instance_valid(img) and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var px = img.get_pixel(4, 4)
			if px.a > 0.85:
				needs_chroma_shader = true
				chroma_mat.set_shader_parameter("key_color", px)
				chroma_mat.set_shader_parameter("tolerance", character_data.chroma_tolerance)
				chroma_mat.set_shader_parameter("smoothness", character_data.chroma_smoothness)

	texture_rect.material = chroma_mat if needs_chroma_shader else null

func set_expression(expr: String, emote: String = "") -> void:
	current_expression = expr.to_lower()
	if not is_instance_valid(character_data):
		return

	var has_custom_visual = false

	if is_instance_valid(character_data.sprite_frames):
		anim_sprite.sprite_frames = character_data.sprite_frames
		anim_sprite.scale = character_data.sprite_scale
		anim_sprite.visible = true
		if character_data.sprite_frames.has_animation(current_expression):
			anim_sprite.play(current_expression)
		elif character_data.sprite_frames.has_animation("default"):
			anim_sprite.play("default")
		has_custom_visual = true
	else:
		anim_sprite.visible = false

	if not has_custom_visual and character_data.video_loop_path != "" and ResourceLoader.exists(character_data.video_loop_path):
		video_player.stream = load(character_data.video_loop_path)
		video_player.visible = true
		if not video_player.is_playing():
			video_player.play()
		has_custom_visual = true
	else:
		video_player.stop()
		video_player.visible = false

	if not has_custom_visual:
		var tex: Texture2D = null
		if character_data.expression_textures.has(current_expression):
			tex = character_data.expression_textures[current_expression]
		elif is_instance_valid(cached_idle_tex):
			tex = cached_talk_tex if (is_talking and showing_talking_pose and is_instance_valid(cached_talk_tex)) else cached_idle_tex
		texture_rect.texture = tex
		texture_rect.visible = is_instance_valid(tex)
		has_custom_visual = is_instance_valid(tex)
	else:
		texture_rect.visible = false

	procedural_canvas.visible = not has_custom_visual

	if emote != "":
		play_emote(emote)

func set_talking_state(talking: bool, focused: bool) -> void:
	is_talking = talking
	is_focused = focused
	if not is_talking:
		showing_talking_pose = false
		if texture_rect.visible and is_instance_valid(cached_idle_tex) and not character_data.expression_textures.has(current_expression):
			texture_rect.texture = cached_idle_tex
	# Mantenemos siempre el color original brillante del sprite sin oscurecerlo
	modulate = Color.WHITE

func play_emote(emote_name: String) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	match emote_name:
		"hop", "bounce":
			# Nunca sube más que el margen inferior de seguridad (+18px) para no mostrar el corte
			tw.tween_property(visual_root, "position:y", -10.0, 0.11)
			tw.tween_property(visual_root, "position:y", 0.0, 0.14)
		"shake", "panic":
			for _i in range(4):
				tw.tween_property(visual_root, "position:x", -9.0, 0.04)
				tw.tween_property(visual_root, "position:x", 9.0, 0.04)
			tw.tween_property(visual_root, "position:x", 0.0, 0.04)
		"nod":
			tw.tween_property(visual_root, "position:y", 8.0, 0.12)
			tw.tween_property(visual_root, "position:y", 0.0, 0.15)

func _process(delta: float) -> void:
	anim_time += delta
	# Respiración anclada en la base inferior (pivot_offset.y = size.y) para que la parte baja NUNCA se levante ni flote
	visual_root.pivot_offset = Vector2(custom_minimum_size.x * 0.5, custom_minimum_size.y)
	visual_root.scale = Vector2(1.0, 1.0 + sin(anim_time * 2.0) * 0.004)

	# Alternancia automática entre Pose 1 (Callada) y Pose 2 (Hablando) cuando el personaje habla
	if is_talking and texture_rect.visible and is_instance_valid(cached_talk_tex) and not character_data.expression_textures.has(current_expression):
		talk_flap_timer -= delta
		if talk_flap_timer <= 0.0:
			showing_talking_pose = not showing_talking_pose
			texture_rect.texture = cached_talk_tex if showing_talking_pose else cached_idle_tex
			talk_flap_timer = randf_range(0.14, 0.24)

	blink_timer -= delta
	if blink_timer <= 0.0:
		if is_blinking:
			is_blinking = false
			blink_timer = randf_range(2.2, 4.8)
		else:
			is_blinking = true
			blink_timer = 0.13

	if is_talking:
		talk_energy = lerpf(talk_energy, 0.4 + abs(sin(anim_time * 16.0)) * 0.6, delta * 15.0)
	else:
		talk_energy = lerpf(talk_energy, 0.0, delta * 12.0)

	if procedural_canvas.visible:
		procedural_canvas.queue_redraw()

func _create_chroma_key_and_rim_material() -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 key_color : source_color = vec4(0.518, 0.518, 0.537, 1.0);
uniform float tolerance : hint_range(0.005, 0.5) = 0.085;
uniform float smoothness : hint_range(0.002, 0.3) = 0.045;
uniform vec2 rim_offset = vec2(0.018, -0.004);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float get_fg_alpha(sampler2D tex_sampler, vec2 uv_coord) {
	if (uv_coord.x < 0.0 || uv_coord.x > 1.0 || uv_coord.y < 0.0 || uv_coord.y > 1.0) {
		return 0.0;
	}
	vec4 c = texture(tex_sampler, uv_coord);
	float diff = distance(c.rgb, key_color.rgb);
	float sat = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
	float is_gray = 1.0 - smoothstep(0.03, 0.12, sat);
	return c.a * smoothstep(tolerance, tolerance + smoothness, diff / max(0.35, is_gray));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float fg_alpha = get_fg_alpha(TEXTURE, UV);
	float rim_alpha = get_fg_alpha(TEXTURE, UV - rim_offset);
	float final_alpha = max(fg_alpha, rim_alpha);
	vec3 final_rgb = mix(rim_color.rgb, tex.rgb * COLOR.rgb, fg_alpha);
	COLOR = vec4(final_rgb, final_alpha * COLOR.a);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	return mat

func _draw_procedural_animated_avatar() -> void:
	if not is_instance_valid(character_data):
		return
	var s = procedural_canvas.size
	var cx = s.x * 0.5
	var col = character_data.name_color
	var dark_body = Color(0.07, 0.10, 0.16, 0.96)
	var jacket_col = Color(col.r * 0.25, col.g * 0.25, col.b * 0.30, 0.95)

	var torso_pts = PackedVector2Array([
		Vector2(cx - 155, s.y),
		Vector2(cx - 115, s.y * 0.56),
		Vector2(cx - 55, s.y * 0.46),
		Vector2(cx + 55, s.y * 0.46),
		Vector2(cx + 115, s.y * 0.56),
		Vector2(cx + 155, s.y)
	])
	procedural_canvas.draw_colored_polygon(torso_pts, jacket_col)
	procedural_canvas.draw_polyline(torso_pts, col, 2.5)
	procedural_canvas.draw_rect(Rect2(cx - 22, s.y * 0.40, 44, 45), dark_body, true)

	var head_center = Vector2(cx, s.y * 0.31)
	procedural_canvas.draw_circle(head_center, 64.0, dark_body)
	procedural_canvas.draw_arc(head_center, 64.0, 0, TAU, 40, col, 2.5)
	procedural_canvas.draw_arc(head_center, 72.0, PI * 0.85, PI * 2.15, 32, col.lightened(0.15), 10.0)

	var eye_y = head_center.y - 4.0
	var left_eye = Vector2(cx - 24, eye_y)
	var right_eye = Vector2(cx + 24, eye_y)
	var eye_col = col.lightened(0.45)

	if is_blinking:
		procedural_canvas.draw_line(left_eye + Vector2(-12, 0), left_eye + Vector2(12, 0), eye_col, 3.0)
		procedural_canvas.draw_line(right_eye + Vector2(-12, 0), right_eye + Vector2(12, 0), eye_col, 3.0)
	else:
		procedural_canvas.draw_rect(Rect2(left_eye.x - 11, left_eye.y - 6, 22, 12), eye_col, true)
		procedural_canvas.draw_rect(Rect2(right_eye.x - 11, right_eye.y - 6, 22, 12), eye_col, true)

	var mouth_pos = Vector2(cx, head_center.y + 26.0)
	if talk_energy > 0.08:
		var open_h = 3.0 + talk_energy * 11.0
		procedural_canvas.draw_rect(Rect2(mouth_pos.x - 11, mouth_pos.y - open_h * 0.5, 22, open_h), eye_col, false, 2.2)
	else:
		procedural_canvas.draw_line(mouth_pos + Vector2(-9, 0), mouth_pos + Vector2(9, 0), eye_col, 2.2)
