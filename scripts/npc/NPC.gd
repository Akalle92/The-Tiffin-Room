## NPC.gd — Base class for all day-world NPCs.
## Attach to a StaticBody2D or CharacterBody2D. Must have a child Area2D named
## "InteractionArea" so the Player can detect them.
class_name NPC
extends StaticBody2D

# ---------------------------------------------------------------------------
# EXPORT VARS  (set per-instance in the scene / Inspector)
# ---------------------------------------------------------------------------
@export var npc_id: String = ""          ## matches key in npc_data.json
@export var display_name: String = ""    ## shown above sprite
@export var is_delivery_target: bool = true  ## counts as a tiffin delivery?
@export var portrait_day: Texture2D      ## dialogue portrait (bust shot)
@export var world_sprite_sheet: Texture2D  ## 1024×1024 sheet, 2×2 grid: down/up/left/right
@export var sprite_color: Color = Color(0.25, 0.45, 0.85)  # placeholder tint

# ---------------------------------------------------------------------------
# NODES
# ---------------------------------------------------------------------------
@onready var sprite: AnimatedSprite2D    = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var name_label: Label           = $NameLabel        if has_node("NameLabel") else null
@onready var delivery_marker: Sprite2D   = $DeliveryMarker   if has_node("DeliveryMarker") else null

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _has_delivery_today: bool = false
var _delivery_done: bool = false

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Physics — layer 3 "npc", mask 1 "world"
	collision_layer = 4
	collision_mask  = 1

	# Show name label
	if name_label:
		name_label.text = display_name if display_name != "" else npc_id

	# Track delivery state
	if npc_id != "" and is_delivery_target:
		_has_delivery_today = npc_id in GameState.today_deliveries
		_delivery_done      = npc_id in GameState.completed_deliveries
		_refresh_delivery_marker()

	# Connect delivery signal
	GameState.delivery_completed.connect(_on_delivery_completed)
	GameState.day_started.connect(_on_day_started)

# ---------------------------------------------------------------------------
# INTERACT — called by Player when pressing E nearby
# ---------------------------------------------------------------------------
func interact() -> void:
	if npc_id == "":
		push_error("NPC '%s': npc_id not set" % name)
		return

	# If player has a delivery for this NPC and hasn't done it yet: deliver
	if is_delivery_target and _has_delivery_today and not _delivery_done:
		_deliver_tiffin()
	else:
		# Just talk
		DialogueManager.start_dialogue(npc_id)

# ---------------------------------------------------------------------------
# DELIVERY FLOW
# ---------------------------------------------------------------------------
func _deliver_tiffin() -> void:
	_delivery_done = true
	GameState.increment_delivery(npc_id)
	_refresh_delivery_marker()
	AudioManager.play_sfx_tiffin()

	# Auto-advance day_state on first delivery
	var route := GameState.get_route(npc_id)
	if route.get("day_state", 0) == 0:
		GameState.update_route(npc_id, {"day_state": 1})

	# Open dialogue after delivery (contextual)
	DialogueManager.start_dialogue(npc_id)

func _on_delivery_completed(completed_id: String) -> void:
	if completed_id == npc_id:
		_delivery_done = true
		_refresh_delivery_marker()

func _on_day_started(_day: int) -> void:
	_has_delivery_today = npc_id in GameState.today_deliveries
	_delivery_done      = false
	_refresh_delivery_marker()

func _refresh_delivery_marker() -> void:
	if delivery_marker == null: return
	delivery_marker.visible = _has_delivery_today and not _delivery_done

# ---------------------------------------------------------------------------
# DRAW — sprite sheet if available, otherwise placeholder
# ---------------------------------------------------------------------------
func _draw() -> void:
	if sprite != null and sprite.sprite_frames != null:
		return  # AnimatedSprite2D is handling rendering

	if world_sprite_sheet:
		# 1024×1024 sprite sheet — 2×2 grid of 512×512 frames.
		# Top-left (0,0) = facing down — NPCs are stationary so we use this frame.
		var src := Rect2(0.0, 0.0, 512.0, 512.0)
		# Draw at 28×40 pixels in game space, centered on feet at origin.
		draw_texture_rect_region(world_sprite_sheet, Rect2(-14.0, -40.0, 28.0, 40.0), src)
		# Delivery "!" indicator above head
		if _has_delivery_today and not _delivery_done:
			draw_rect(Rect2(-2, -52, 4, 10), Color(1.0, 0.85, 0.1))
			draw_circle(Vector2(0, -56), 2, Color(1.0, 0.85, 0.1))
		return

	# Colored rectangle + circle placeholder
	draw_rect(Rect2(-7, -16, 14, 16), sprite_color)
	draw_circle(Vector2(0, -20), 7, sprite_color.lightened(0.2))
	if _has_delivery_today and not _delivery_done:
		draw_rect(Rect2(-2, -36, 4, 10), Color(1.0, 0.85, 0.1))
		draw_circle(Vector2(0, -40), 2, Color(1.0, 0.85, 0.1))
