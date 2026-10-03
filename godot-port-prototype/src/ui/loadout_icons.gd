extends RefCounted
# White vector artwork is tinted by the current team; retired IDs have a fallback.
const SPECIAL_NAMES := {"slam":"重击","storm":"墨雨","twin_discs":"双镖突进","rain_arrows":"雨箭齐射","absorb_counter":"吸墨反击"}
static var textures: Dictionary = {}

static func icon(kind: String, id: String) -> Texture2D:
	var key := kind+"-"+id
	if not textures.has(key):
		var path := "res://assets/ui/"+key+".svg"
		textures[key] = load(path if ResourceLoader.exists(path) else "res://assets/ui/nav-question.svg") as Texture2D
	return textures[key] as Texture2D

static func draw_on(canvas: CanvasItem, kind: String, id: String, rect: Rect2, tint: Color) -> void:
	var texture := icon(kind,id)
	for offset in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
		canvas.draw_texture_rect(texture,Rect2(rect.position+offset,rect.size),false,Color(.08,.06,.11,.8))
	canvas.draw_texture_rect(texture,rect,false,tint)
