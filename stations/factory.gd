class_name Stations
extends RefCounted

static func make(station: String, readonly: bool = false) -> StationUI:
	match station:
		"helm":
			return HelmUI.new("helm", readonly)
		"engines":
			return EnginesUI.new("engines", readonly)
		"power":
			return PowerUI.new("power", readonly)
		"weapons":
			return WeaponsUI.new("weapons", readonly)
		"sensors":
			return SensorsUI.new("sensors", readonly)
		"ops":
			return OpsUI.new("ops", readonly)
		"dc":
			return DamageControlUI.new("dc", readonly)
	return null
