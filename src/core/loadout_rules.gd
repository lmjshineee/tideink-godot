extends RefCounted
# Local kits use the existing abilities; they are not copies of Nintendo kits.
const MODES := ["kit", "custom"]
const KITS := {"shooter":"bomb", "roller":"shield", "charger":"sonar", "blaster":"mine",
	"dualie":"echo_decoy", "disc":"recall", "bow":"intel_mist", "canopy":"supply_box"}

static func sub_for(id: String) -> String:
	return String(KITS.get(id,"bomb"))
