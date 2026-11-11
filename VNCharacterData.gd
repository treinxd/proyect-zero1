class_name VNCharacterData
extends Resource

@export var id: String = "maria"
@export var display_name: String = "MARIA"
@export var codename: String = "VALKYRIE-01"
@export var name_color: Color = Color("#f600ff")

@export_group("1. Hoja de Personaje Doble (Idle Izquierda + Hablando Derecha)")
## Arrastrá acá tu imagen con las 2 poses (Izquierda = Callada/Idle, Derecha = Hablando).
@export var dual_pose_sheet: Texture2D
## Si subís un .jpg con fondo gris sólido sin transparencia, activa el filtro por shader automáticamente.
@export var remove_solid_bg: bool = true
@export var bg_key_color: Color = Color(0.518, 0.518, 0.537, 1.0)
@export_range(0.01, 0.40, 0.005) var chroma_tolerance: float = 0.085
@export_range(0.005, 0.20, 0.005) var chroma_smoothness: float = 0.045

@export_group("2. Sprites Individuales / Animaciones Opcionales")
@export var idle_texture: Texture2D
@export var talking_texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var expression_textures: Dictionary = {}
@export_file("*.ogv") var video_loop_path: String = ""
@export var sprite_scale: Vector2 = Vector2(1.0, 1.0)

## Devuelve una AtlasTexture con el recorte centrado exacto de cada pose (sin bordes vacíos abajo)
func get_pose_texture(talking_pose: bool = false) -> Texture2D:
	if talking_pose and is_instance_valid(talking_texture):
		return talking_texture
	if not talking_pose and is_instance_valid(idle_texture):
		return idle_texture
	if is_instance_valid(dual_pose_sheet):
		var atlas = AtlasTexture.new()
		atlas.atlas = dual_pose_sheet
		var w = float(dual_pose_sheet.get_width())
		var h = float(dual_pose_sheet.get_height())
		var slice_w = roundf(w * 0.36)
		if talking_pose:
			# Centrado en la pose derecha (x ~ 77% del ancho total)
			var rx = clampf(roundf(w * 0.77 - slice_w * 0.5), w * 0.5, w - slice_w)
			atlas.region = Rect2(rx, 0.0, slice_w, h)
		else:
			# Centrado en la pose izquierda (x ~ 25% del ancho total)
			var lx = clampf(roundf(w * 0.25 - slice_w * 0.5), 0.0, w * 0.5 - slice_w)
			atlas.region = Rect2(lx, 0.0, slice_w, h)
		return atlas
	return idle_texture
