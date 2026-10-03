extends RefCounted
# Reuse the web Latin font resource and bundle a deterministic OFL Chinese fallback.
static func font(display:bool=false) -> Font:
	var id:="TitanOne" if display else "Rubik"
	var result:FontFile=load("res://assets/fonts/%s-latin.woff2" % id)
	if result.fallbacks.is_empty():
		var chinese:=FontVariation.new();chinese.base_font=load("res://assets/fonts/NotoSansSC.ttf");chinese.variation_opentype={"wght":600.0 if display else 500.0}
		result.allow_system_fallback=false;result.fallbacks=[chinese]
	return result
