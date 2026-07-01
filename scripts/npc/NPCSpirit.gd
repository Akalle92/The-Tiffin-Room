## NPCSpirit.gd — Night-world spirit version of an NPC.
## These entities appear in the spirit-city and hold the "unsaid" emotional
## payload the player must deliver to resolve a route arc.
extends StaticBody2D

# ---------------------------------------------------------------------------
# EXPORT VARS
# ---------------------------------------------------------------------------
@export var npc_id: String = ""
@export var display_name: String = ""
@export var portrait_spirit: Texture2D
@export var spirit_color: Color = Color(0.4, 0.35, 0.75)  # indigo-lavender placeholder
@export var world_sprite_sheet: Texture2D  ## 1024×1024 sheet, 2×2 grid: down/up/left/right

# ---------------------------------------------------------------------------
# NODES
# ---------------------------------------------------------------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var name_label: Label        = $NameLabel        if has_node("NameLabel") else null
@onready var glow_light: PointLight2D = $GlowLight        if has_node("GlowLight") else null

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _resolved: bool = false
var _pulse_timer: float = 0.0

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	collision_layer = 4
	collision_mask  = 0

	if npc_id != "":
		var route := GameState.get_route(npc_id)
		_resolved = route.get("spirit_resolved", false)

	if name_label:
		name_label.text = display_name

	# Spirits are invisible until their day-world route is unlocked enough
	visible = _should_be_visible()

	# Gentle point light (placeholder — will be replaced by real Light2D in scene)
	if glow_light:
		glow_light.color = spirit_color
		glow_light.energy = 1.2
		glow_light.texture_scale = 2.0

	GameState.route_updated.connect(_on_route_updated)

# ---------------------------------------------------------------------------
# PROCESS — pulse glow
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _resolved or glow_light == null:
		return
	_pulse_timer += delta * 1.5
	glow_light.energy = 1.0 + 0.4 * sin(_pulse_timer)

# ---------------------------------------------------------------------------
# INTERACT
# ---------------------------------------------------------------------------
func interact() -> void:
	if npc_id == "":
		return
	if _resolved:
		DialogueManager.start_dialogue(npc_id, "spirit_aftermath")
		return

	var route := GameState.get_route(npc_id)
	if not route.get("spirit_unlocked", false):
		# Spirit isn't accessible yet (player hasn't built enough day rapport)
		# Show a brief ambient message
		DialogueManager.start_dialogue(npc_id, "spirit_not_ready")
		return

	# Neglected too long: a colder, bittersweet homecoming.
	if route.get("hardened", false):
		DialogueManager.start_dialogue(npc_id, "spirit_hardened")
		return

	var spirit_state: int = route.get("spirit_state", 0)
	if spirit_state == 0:
		DialogueManager.start_dialogue(npc_id, "spirit_intro")
	else:
		DialogueManager.start_dialogue(npc_id, "spirit_resolution")

# ---------------------------------------------------------------------------
# ROUTE CALLBACK
# ---------------------------------------------------------------------------
func _on_route_updated(updated_id: String) -> void:
	if updated_id != npc_id:
		return
	var route := GameState.get_route(npc_id)
	_resolved = route.get("spirit_resolved", false)
	visible = _should_be_visible()
	queue_redraw()

func _should_be_visible() -> bool:
	if not GameState.is_night:
		return false
	var route := GameState.get_route(npc_id)
	# Visible if day_state >= 1 (player has spoken to them at least once)
	return route.get("day_state", 0) >= 1

# ---------------------------------------------------------------------------
# DRAW — sprite sheet (spirit-tinted) or placeholder silhouette
# ---------------------------------------------------------------------------
func _draw() -> void:
	if sprite != null and sprite.sprite_frames != null:
		return

	var alpha := 0.6 + 0.3 * sin(_pulse_timer)

	if world_sprite_sheet:
		var src := Rect2(0.0, 0.0, 512.0, 512.0)  # facing-down frame
		var dest := Rect2(-14.0, -40.0, 28.0, 40.0)
		# Spirit tint: indigo-violet, pulsing opacity
		var tint := Color(0.55, 0.48, 0.95, alpha)
		draw_texture_rect_region(world_sprite_sheet, dest, src, tint)
		if _resolved:
			# Peaceful overlay — bleach towards white
			draw_rect(dest, Color(0.9, 0.9, 1.0, 0.25))
		return

	# Placeholder silhouette
	if _resolved:
		draw_circle(Vector2.ZERO, 8, spirit_color.lightened(0.5))
		return
	var col := spirit_color
	col.a = alpha
	draw_rect(Rect2(-6, -14, 12, 14), col)
	draw_circle(Vector2(0, -18), 6, col.lightened(0.15))
	draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(spirit_color.r, spirit_color.g, spirit_color.b, 0.15), 6.0)
