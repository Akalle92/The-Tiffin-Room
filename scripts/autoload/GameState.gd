## GameState.gd — Global singleton. Tracks all persistent game data.
## Autoloaded as "GameState" in project settings.
extends Node

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal day_started(day_number: int)
signal night_started(day_number: int)
signal route_updated(npc_id: String)
signal delivery_completed(npc_id: String)
signal stat_changed(stat_name: String, new_value: int)
signal flag_set(flag_name: String, value: Variant)
## Emitted once when all five spirit arcs are resolved (game complete).
signal game_completed

# ---------------------------------------------------------------------------
# PLAYER STATS  (0–5 scale)
# EMPATHY      – Unlock emotional dialogue options, sense grief
# NOSE         – Detect lies, read a room through smell/intuition and food
# STEADY_HANDS – Deliver without fumbling; patience under pressure
# STREET_SENSE – Navigate faster, read danger, spot opportunity
# GRIEF        – Understand loss; gate spirit-world interactions
# ---------------------------------------------------------------------------
var player_stats: Dictionary = {
	"EMPATHY":      1,
	"NOSE":         1,
	"STEADY_HANDS": 1,
	"STREET_SENSE": 1,
	"GRIEF":        0,
}

# ---------------------------------------------------------------------------
# DAY / NIGHT STATE
# ---------------------------------------------------------------------------
var is_night: bool = false
var day_number: int = 1
## 0.0 = dawn  |  0.5 = midday  |  1.0 = dusk-to-night
var time_of_day: float = 0.1
var time_speed: float = 0.004  # fraction of day consumed per second (real-time)

# ---------------------------------------------------------------------------
# DELIVERY STATE
# ---------------------------------------------------------------------------
## List of npc_ids the player must deliver to today
var today_deliveries: Array[String] = []
## Deliveries completed this day
var completed_deliveries: Array[String] = []
## NPC ids that appear in the city today (may be less than routes if some are spirit-only)
var active_npcs_day: Array[String] = []
## Spirit encounter points unlocked by day-world progress
var spirit_locations_unlocked: Array[String] = []

# ---------------------------------------------------------------------------
# ROUTE JOURNAL  (one entry per NPC)
# ---------------------------------------------------------------------------
## Structure per route:
## {
##   "name":               String,   display name
##   "title":              String,   subtitle ("The Widow of Flat 4B")
##   "unlocked":           bool,     visible in journal?
##   "day_state":          int,      story beat index (day side)
##   "trust_level":        int,      0=stranger 1=acquaintance 2=trusted 3=open
##   "delivery_count":     int,
##   "notes":              Array,    strings the player has collected
##   "spirit_unlocked":    bool,     night encounter accessible?
##   "spirit_state":       int,      story beat index (spirit side)
##   "spirit_resolved":    bool,     arc complete?
## }
var routes: Dictionary = {}

# ---------------------------------------------------------------------------
# GLOBAL FLAGS  (arbitrary bool/value game events)
# ---------------------------------------------------------------------------
var flags: Dictionary = {}

# ---------------------------------------------------------------------------
# BABULAL / PROTAGONIST THREAD
# You are Babulal's grandchild, carrying his route after his death. These flags
# track the grandfather sub-story that is seeded by Mrs. Mehta and Champa and
# pays off in the finale (see scripts/world/DayNightController.gd `_play_finale`).
# ---------------------------------------------------------------------------
const BABULAL_SEED_FLAGS := ["babulal_mehta_seed", "babulal_champa_seed"]

## How many grandfather memories the player uncovered during the run (0–2).
## Drives which finale lines Babulal speaks and the choice-reflective epilogue.
func babulal_seeds_seen() -> int:
	var seen := 0
	for f in BABULAL_SEED_FLAGS:
		if get_flag(f, false):
			seen += 1
	return seen

# ---------------------------------------------------------------------------
# PLAYER POSITION (persist across scene loads)
# ---------------------------------------------------------------------------
var player_world_position: Vector2 = Vector2(240, 135)

# ---------------------------------------------------------------------------
# ACCESSIBILITY SETTINGS
# Stored separately from the save game (in user://settings.cfg) so the choice
# survives "New Game" and is honoured before any run begins.
# ---------------------------------------------------------------------------
const SETTINGS_PATH := "user://settings.cfg"
## When true, every mini-game auto-passes so the narrative is never gated.
var skip_minigames: bool = false

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		skip_minigames = cfg.get_value("accessibility", "skip_minigames", false)

func set_skip_minigames(value: bool) -> void:
	skip_minigames = value
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep any other settings if present
	cfg.set_value("accessibility", "skip_minigames", value)
	cfg.save(SETTINGS_PATH)

# ---------------------------------------------------------------------------
# READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Load persistent accessibility settings (independent of the save game)
	_load_settings()
	# Initialise default routes for all known NPCs
	_init_default_routes()
	# Attempt to load an existing save; on first run this is a no-op
	SaveLoad.load_game()
	# Seed first day deliveries
	if today_deliveries.is_empty():
		today_deliveries = _generate_day_deliveries()

## Wipe all in-memory progress back to a fresh start (used by "New Game").
## Call SaveLoad.delete_save() before this so the reset state isn't overwritten.
func reset_new_game() -> void:
	player_stats = {
		"EMPATHY": 1, "NOSE": 1, "STEADY_HANDS": 1, "STREET_SENSE": 1, "GRIEF": 0,
	}
	is_night = false
	day_number = 1
	time_of_day = 0.1
	today_deliveries = []
	completed_deliveries = []
	active_npcs_day = []
	spirit_locations_unlocked = []
	routes = {}
	flags = {}
	player_world_position = Vector2(240, 135)
	_init_default_routes()
	today_deliveries = _generate_day_deliveries()

func _init_default_routes() -> void:
	var defaults: Dictionary = {
		"mrs_mehta":  {"name": "Mrs. Mehta",  "title": "The Widow of Flat 4B",        "unlocked": true},
		"raju":       {"name": "Raju",        "title": "The Boy on the Temple Steps", "unlocked": true},
		"desai":      {"name": "Desai Sahib", "title": "The Clerk at Window 3",       "unlocked": false},
		"arjun":      {"name": "Arjun",       "title": "The Son Who Came Back",       "unlocked": false},
		"champa":     {"name": "Champa Tai",  "title": "The Tea Stall at the Corner", "unlocked": true},
	}
	for npc_id in defaults:
		if not routes.has(npc_id):
			routes[npc_id] = {
				"name":             defaults[npc_id]["name"],
				"title":            defaults[npc_id]["title"],
				"unlocked":         defaults[npc_id]["unlocked"],
				"day_state":        0,
				"trust_level":      0,
				"delivery_count":   0,
				"notes":            [],
				"spirit_unlocked":  false,
				"spirit_unlocked_day": 0,
				"spirit_state":     0,
				"spirit_resolved":  false,
				"hardened":         false,
			}

# ---------------------------------------------------------------------------
# ROUTE API
# ---------------------------------------------------------------------------
func get_route(npc_id: String) -> Dictionary:
	if not routes.has(npc_id):
		push_warning("GameState: unknown npc_id '%s'" % npc_id)
		return {}
	return routes[npc_id]

func update_route(npc_id: String, updates: Dictionary) -> void:
	if not routes.has(npc_id):
		push_warning("GameState: update_route — unknown npc_id '%s'" % npc_id)
		return
	for key in updates:
		routes[npc_id][key] = updates[key]
	# Meeting someone always opens their journal page — regardless of which
	# first-meeting branch the player took (Desai/Arjun start locked).
	if int(routes[npc_id].get("day_state", 0)) >= 1:
		routes[npc_id]["unlocked"] = true
	# Stamp the day a spirit first becomes reachable, for neglect tracking.
	if routes[npc_id].get("spirit_unlocked", false) and int(routes[npc_id].get("spirit_unlocked_day", 0)) == 0:
		routes[npc_id]["spirit_unlocked_day"] = day_number
	route_updated.emit(npc_id)
	SaveLoad.save()
	# Fire the ending exactly once when every arc is resolved.
	if not get_flag("game_completed", false) and all_spirits_resolved():
		set_flag("game_completed", true)
		game_completed.emit()

## Count of NPCs whose spirit arc is resolved (drives Champa's convergence beat).
func spirits_resolved_count() -> int:
	var n := 0
	for npc_id in routes:
		if routes[npc_id].get("spirit_resolved", false):
			n += 1
	return n

## True when every route's spirit arc has been resolved.
func all_spirits_resolved() -> bool:
	if routes.is_empty():
		return false
	for npc_id in routes:
		if not routes[npc_id].get("spirit_resolved", false):
			return false
	return true

func add_note(npc_id: String, note: String) -> void:
	if routes.has(npc_id) and note not in routes[npc_id]["notes"]:
		routes[npc_id]["notes"].append(note)
		route_updated.emit(npc_id)
		SaveLoad.save()

func increment_delivery(npc_id: String) -> void:
	if routes.has(npc_id):
		routes[npc_id]["delivery_count"] += 1
		if npc_id not in completed_deliveries:
			completed_deliveries.append(npc_id)
		delivery_completed.emit(npc_id)
		SaveLoad.save()

# ---------------------------------------------------------------------------
# STAT API
# ---------------------------------------------------------------------------
func get_stat(stat_name: String) -> int:
	return player_stats.get(stat_name, 0)

func check_stat(stat_name: String, threshold: int) -> bool:
	return player_stats.get(stat_name, 0) >= threshold

func modify_stat(stat_name: String, delta: int) -> void:
	if player_stats.has(stat_name):
		player_stats[stat_name] = clampi(player_stats[stat_name] + delta, 0, 5)
		stat_changed.emit(stat_name, player_stats[stat_name])
		SaveLoad.save()

# ---------------------------------------------------------------------------
# FLAG API
# ---------------------------------------------------------------------------
func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value
	flag_set.emit(flag_name, value)
	SaveLoad.save()

func get_flag(flag_name: String, default: Variant = null) -> Variant:
	return flags.get(flag_name, default)

func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)

# ---------------------------------------------------------------------------
# DAY / NIGHT TRANSITIONS
# ---------------------------------------------------------------------------
func transition_to_night() -> void:
	if is_night:
		return
	is_night = true
	night_started.emit(day_number)
	SaveLoad.save()

## A spirit left unvisited-unresolved for this many days grows "hardened":
## still resolvable, but only through a colder, bittersweet homecoming.
const DECAY_DAYS := 4

func transition_to_day() -> void:
	is_night = false
	day_number += 1
	time_of_day = 0.1
	completed_deliveries.clear()
	today_deliveries = _generate_day_deliveries()
	_check_spirit_decay()
	day_started.emit(day_number)
	SaveLoad.save()

## Neglect has a cost: unresolved spirits that wait too long harden.
func _check_spirit_decay() -> void:
	for npc_id in routes:
		var r: Dictionary = routes[npc_id]
		if not r.get("spirit_unlocked", false):
			continue
		if r.get("spirit_resolved", false) or r.get("hardened", false):
			continue
		var unlocked_day: int = int(r.get("spirit_unlocked_day", 0))
		if unlocked_day > 0 and (day_number - unlocked_day) >= DECAY_DAYS:
			r["hardened"] = true
			add_note(npc_id, "You let too many nights pass. The spirit has grown distant — this will be a harder, colder homecoming.")
			route_updated.emit(npc_id)

func _generate_day_deliveries() -> Array[String]:
	var deliveries: Array[String] = []
	for npc_id in routes:
		if routes[npc_id].get("unlocked", false) and not routes[npc_id].get("spirit_resolved", false):
			deliveries.append(npc_id)
	return deliveries

## Returns 0.0–1.0 fraction of today's deliveries completed
func delivery_progress() -> float:
	if today_deliveries.is_empty():
		return 1.0
	var done: int = 0
	for npc_id in today_deliveries:
		if npc_id in completed_deliveries:
			done += 1
	return float(done) / float(today_deliveries.size())

# ---------------------------------------------------------------------------
# TIME (called from DayNightController each frame)
# ---------------------------------------------------------------------------
func advance_time(delta: float) -> void:
	if is_night:
		return
	time_of_day = minf(time_of_day + time_speed * delta, 1.0)
	if time_of_day >= 1.0:
		transition_to_night()
