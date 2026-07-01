## SaveLoad.gd — Autoloaded singleton for saving and loading game state.
## Uses Godot's ConfigFile to write to user://save_game.cfg
extends Node

const SAVE_PATH := "user://save_game.cfg"

# ---------------------------------------------------------------------------
# SAVE
# ---------------------------------------------------------------------------
func save() -> void:
	var config := ConfigFile.new()
	var gs := GameState

	# --- player stats ---
	for stat in gs.player_stats:
		config.set_value("player_stats", stat, gs.player_stats[stat])

	# --- game state ---
	config.set_value("game", "day_number",  gs.day_number)
	config.set_value("game", "is_night",    gs.is_night)
	config.set_value("game", "time_of_day", gs.time_of_day)
	config.set_value("game", "player_x",    gs.player_world_position.x)
	config.set_value("game", "player_y",    gs.player_world_position.y)

	# --- routes ---
	for npc_id in gs.routes:
		var r: Dictionary = gs.routes[npc_id]
		config.set_value("route_" + npc_id, "day_state",       r.get("day_state", 0))
		config.set_value("route_" + npc_id, "trust_level",     r.get("trust_level", 0))
		config.set_value("route_" + npc_id, "delivery_count",  r.get("delivery_count", 0))
		config.set_value("route_" + npc_id, "notes",           r.get("notes", []))
		config.set_value("route_" + npc_id, "unlocked",        r.get("unlocked", false))
		config.set_value("route_" + npc_id, "spirit_unlocked", r.get("spirit_unlocked", false))
		config.set_value("route_" + npc_id, "spirit_state",    r.get("spirit_state", 0))
		config.set_value("route_" + npc_id, "spirit_resolved", r.get("spirit_resolved", false))

	# --- flags ---
	for flag in gs.flags:
		config.set_value("flags", flag, gs.flags[flag])

	# --- deliveries ---
	config.set_value("deliveries", "today",     gs.today_deliveries)
	config.set_value("deliveries", "completed", gs.completed_deliveries)

	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("SaveLoad: failed to save (%d)" % err)

# ---------------------------------------------------------------------------
# LOAD
# ---------------------------------------------------------------------------
func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # First run — GameState already has defaults

	var gs := GameState

	# --- player stats ---
	for stat in gs.player_stats:
		gs.player_stats[stat] = config.get_value("player_stats", stat, gs.player_stats[stat])

	# --- game state ---
	gs.day_number  = config.get_value("game", "day_number",  1)
	gs.is_night    = config.get_value("game", "is_night",    false)
	gs.time_of_day = config.get_value("game", "time_of_day", 0.1)
	var px: float  = config.get_value("game", "player_x",    240.0)
	var py: float  = config.get_value("game", "player_y",    135.0)
	gs.player_world_position = Vector2(px, py)

	# --- routes ---
	for npc_id in gs.routes:
		var section: String = "route_" + str(npc_id)
		if config.has_section(section):
			gs.routes[npc_id]["day_state"]       = config.get_value(section, "day_state",       0)
			gs.routes[npc_id]["trust_level"]      = config.get_value(section, "trust_level",     0)
			gs.routes[npc_id]["delivery_count"]   = config.get_value(section, "delivery_count",  0)
			gs.routes[npc_id]["notes"]            = config.get_value(section, "notes",           [])
			gs.routes[npc_id]["unlocked"]         = config.get_value(section, "unlocked",        false)
			gs.routes[npc_id]["spirit_unlocked"]  = config.get_value(section, "spirit_unlocked", false)
			gs.routes[npc_id]["spirit_state"]     = config.get_value(section, "spirit_state",    0)
			gs.routes[npc_id]["spirit_resolved"]  = config.get_value(section, "spirit_resolved", false)

	# --- flags ---
	if config.has_section("flags"):
		for flag in config.get_section_keys("flags"):
			gs.flags[flag] = config.get_value("flags", flag)

	# --- deliveries ---
	# ConfigFile returns untyped Arrays; use assign() to coerce into Array[String]
	# without a "Trying to assign an array of type Array" runtime error.
	var today_raw: Array = config.get_value("deliveries", "today", [])
	var completed_raw: Array = config.get_value("deliveries", "completed", [])
	if today_raw.is_empty():
		gs.today_deliveries = gs._generate_day_deliveries()
	else:
		gs.today_deliveries.assign(today_raw)
	gs.completed_deliveries.assign(completed_raw)

# ---------------------------------------------------------------------------
# DELETE SAVE (for new game / debug)
# ---------------------------------------------------------------------------
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
