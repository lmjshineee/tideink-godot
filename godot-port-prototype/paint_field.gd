extends RefCounted

# PROTOTYPE: ground-only CPU ownership grid plus a matching GPU-visible texture.
# The original paint.js also handles walls, corners, a render atlas, and detailed scoring.
const RESOLUTION := 256
const HALF_SIZE := 20.0
const WORLD_SIZE := HALF_SIZE * 2.0
const EMPTY := 255
const TeamPalette := preload("res://team_palette.gd")

var image: Image
var texture: ImageTexture
var owners := PackedByteArray()
var counts := [0, 0]
var dirty := false

func _init() -> void:
	image = Image.create_empty(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	texture = ImageTexture.create_from_image(image)
	owners.resize(RESOLUTION * RESOLUTION)
	owners.fill(EMPTY)


func owner_at(world: Vector3) -> int:
	var px := int(floor((world.x + HALF_SIZE) / WORLD_SIZE * RESOLUTION))
	var py := int(floor((world.z + HALF_SIZE) / WORLD_SIZE * RESOLUTION))
	if px < 0 or py < 0 or px >= RESOLUTION or py >= RESOLUTION:
		return -1
	var owner := owners[py * RESOLUTION + px]
	return -1 if owner == EMPTY else owner


func coverage(team: int) -> float:
	return float(counts[team]) / float(RESOLUTION * RESOLUTION) * 100.0


func splat(world: Vector3, radius: float, team: int, seed: float) -> void:
	var cx := (world.x + HALF_SIZE) / WORLD_SIZE * RESOLUTION
	var cy := (world.z + HALF_SIZE) / WORLD_SIZE * RESOLUTION
	var cell_radius := radius / WORLD_SIZE * RESOLUTION
	var reach := int(ceil(cell_radius * 1.5))
	var min_x: int = maxi(0, int(floor(cx)) - reach)
	var max_x: int = mini(RESOLUTION - 1, int(ceil(cx)) + reach)
	var min_y: int = maxi(0, int(floor(cy)) - reach)
	var max_y: int = mini(RESOLUTION - 1, int(ceil(cy)) + reach)
	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			var dx := float(px) + 0.5 - cx
			var dy := float(py) + 0.5 - cy
			var angle := atan2(dy, dx)
			if dx * dx + dy * dy > pow(cell_radius * blob_wobble(angle, seed), 2.0):
				continue
			var index := py * RESOLUTION + px
			var before := owners[index]
			if before == team:
				continue
			if before != EMPTY:
				counts[before] -= 1
			owners[index] = team
			counts[team] += 1
			image.set_pixel(px, py, TeamPalette.color(team))
			dirty = true


func flush() -> void:
	if dirty:
		texture.update(image)
		dirty = false


# Direct port of the main organic ink-blob outline from public/game/src/world/paint.js.
static func blob_wobble(angle: float, seed: float) -> float:
	return 1.0 + 0.12 * sin(3.0 * angle + seed * 6.2831) \
		+ 0.08 * sin(5.0 * angle + seed * 17.0) \
		+ 0.05 * sin(7.0 * angle + seed * 41.0) \
		+ 0.03 * sin(11.0 * angle + seed * 73.0) \
		+ 0.018 * sin(17.0 * angle + seed * 29.0) \
		+ 0.17 * pow(maxf(cos(angle - seed * 37.7), 0.0), 28.0) \
		+ 0.12 * pow(maxf(cos(angle - seed * 53.3 - 2.1), 0.0), 36.0)

