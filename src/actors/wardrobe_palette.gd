extends RefCounted

# Finite, coordinated colourways. Private seeded selection keeps previews,
# portraits and combat identical without touching weapon/gameplay randomness.
const NAMES := ["海盐青", "莓果奶油", "靛蓝橙", "苔绿沙", "石墨薄荷", "奶油红", "雾紫灰", "铜锈蓝"]
# Shirt, trousers, shoes, sole, socks, tank straps.
const COLORS := [
	["347d84","233846","e5e2d5","f3ecd9","ced9d2","344650"],
	["8b4968","313d54","e7d8c1","f5ead8","d5c3c7","403344"],
	["354b83","242f45","c97e4d","e6ddce","b8c6d5","263c53"],
	["6b7958","343d36","9f7553","ded2b7","c4c6a9","3f4d44"],
	["384953","263738","8dbdb0","e8e5d6","c2d8d0","345952"],
	["dfd9c6","454c57","ac5050","ece5cf","d2d4c3","555a58"],
	["938aa4","383f51","d8d8d5","f0eade","c4bfd0","515366"],
	["ae754b","314c5c","537e8e","dbd5c5","c5c6b4","34474e"]
]
const GRAPHICS := ["胸条拼色", "折线拼色", "侧条纹", "胸前徽记"]
const TOPS := ["短袖T恤", "运动外套", "工装衬衫", "宽松球衣"]
const TROUSERS := ["短裤", "修身长裤", "工装长裤", "宽松中裤"]
const SHOES := ["轻便跑鞋", "低帮运动鞋", "厚底工装鞋", "宽头板鞋"]

static func look(appearance_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# A separate stream preserves the existing facial ornament sequence.
	rng.seed = maxi(appearance_seed,0) ^ 0x57a4d1
	return {"top":rng.randi_range(0,3),"trousers":rng.randi_range(0,3),"shoes":rng.randi_range(0,3),
		"palette":rng.randi_range(0,COLORS.size()-1),"trouser_palette":rng.randi_range(0,COLORS.size()-1),"shoe_palette":rng.randi_range(0,COLORS.size()-1),
		"graphic":rng.randi_range(0,GRAPHICS.size()-1)}

static func label(appearance_seed: int) -> String:
	var value := look(appearance_seed)
	return TOPS[value.top]+" / "+TROUSERS[value.trousers]+" / "+SHOES[value.shoes]+"\n"+NAMES[value.palette]+" · "+GRAPHICS[value.graphic]
