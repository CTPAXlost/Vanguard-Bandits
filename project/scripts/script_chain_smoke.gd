extends SceneTree

const SCRIPT_CHAIN: Array[String] = [
	"res://scripts/battle_prototype.gd",
	"res://scripts/campaign_battle.gd",
	"res://scripts/campaign_battle_v08.gd",
	"res://scripts/campaign_battle_v12.gd",
	"res://scripts/campaign_battle_v18.gd",
	"res://scripts/campaign_battle_v19.gd",
]

func _init() -> void:
	for script_path: String in SCRIPT_CHAIN:
		var loaded_script: Script = load(script_path) as Script
		if loaded_script == null:
			push_error("SCRIPT_CHAIN_SMOKE_FAILED: %s" % script_path)
			quit(1)
			return
		print("SCRIPT_CHAIN_LAYER_OK %s" % script_path)
	print("SCRIPT_CHAIN_SMOKE_OK layers=%d" % SCRIPT_CHAIN.size())
	quit(0)
