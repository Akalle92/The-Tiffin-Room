## Player.gd — CharacterBody2D controller.
## 4-directional free movement. Locks during dialogue. Triggers NPC interactions.
extends CharacterBody2D

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
const SPEED := 80.0
const INTERACTION_RADIUS := 20.0

## 1024×1024 sprite sheet — 2×2 grid: top-left=down, top-right=up, bottom-left=left, bottom-right=right.
@export var world_sprite_sheet: Texture2D

# ---------------------------------------------------------------------------
# NODES (set via @onready once scene is ready)
# ---------------------------------------------------------------------------
@onready var sprite: AnimatedSprite2D       = $AnimatedSprite2D
@onready var interaction_area: Area2D       = $InteractionArea
@onready var collision: CollisionShape2D    = $CollisionShape2D

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _facing: String = "down"
var _carrying_tiffin: bool = true   # Carrying today's stack

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Sync position from GameState (respawns where we left off)
	global_position = GameState.player_world_position

	# Connect dialogue lock/unlock
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	# Set physics layers
	collision_layer = 2  # "player"
	collision_mask  = 1  # collide with "world"

	# Placeholder: draw a colored rect if no sprite sheet yet
	if sprite == null:
		push_warning("Player: AnimatedSprite2D not found — using placeholder draw.")

# ---------------------------------------------------------------------------
# PHYSICS PROCESS
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	# Advance time of day while free
	if not DialogueManager.is_active:
		GameState.advance_time(delta)

	if DialogueManager.is_active:
		velocity = Vector2.ZERO
		_play_idle()
		return

	# Read WASD / arrow keys
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if dir.length() > 0.01:
		velocity = dir.normalized() * SPEED
		_update_facing(dir)
		_play_walk()
	else:
		velocity = Vector2.ZERO
		_play_idle()

	move_and_slide()

	# Persist position each frame (cheap, only writes when saving)
	GameState.player_world_position = global_position

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()

# ---------------------------------------------------------------------------
# INTERACTION
# ---------------------------------------------------------------------------
func _try_interact() -> void:
	if DialogueManager.is_active:
		return
	# Look for NPCs / interactables in the interaction Area2D
	var overlapping: Array[Area2D] = interaction_area.get_overlapping_areas()
	if overlapping.is_empty():
		return
	# Pick the closest one
	var best: Area2D = null
	var best_dist := INF
	for area in overlapping:
		var d := global_position.distance_to(area.global_position)
		if d < best_dist:
			best_dist = d
			best = area
	if best and best.get_parent().has_method("interact"):
		AudioManager.play_sfx_bell()
		best.get_parent().interact()

# ---------------------------------------------------------------------------
# ANIMATION HELPERS
# ---------------------------------------------------------------------------
func _update_facing(dir: Vector2) -> void:
	var new_facing := ("right" if dir.x > 0 else "left") if abs(dir.x) >= abs(dir.y) \
					  else ("down" if dir.y > 0 else "up")
	if new_facing != _facing:
		_facing = new_facing
		queue_redraw()  # redraw sprite sheet frame for new direction

func _play_walk() -> void:
	if sprite == null: return
	var anim := "walk_" + _facing
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

func _play_idle() -> void:
	if sprite == null: return
	var anim := "idle_" + _facing
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	else:
		sprite.stop()

# ---------------------------------------------------------------------------
# DIALOGUE CALLBACKS
# ---------------------------------------------------------------------------
func _on_dialogue_started(_npc_id: String, _tree_id: String) -> void:
	velocity = Vector2.ZERO

func _on_dialogue_ended(_npc_id: String) -> void:
	pass  # player regains control automatically next _physics_process

# ---------------------------------------------------------------------------
# DRAW — sprite sheet if available, otherwise placeholder
# ---------------------------------------------------------------------------
func _draw() -> void:
	if sprite != null and sprite.sprite_frames != null:
		return  # AnimatedSprite2D handling rendering

	if world_sprite_sheet:
		# Pick frame based on facing direction (2×2 grid, each frame 512×512)
		var frame_x := 0.0
		var frame_y := 0.0
		match _facing:
			"down":  frame_x = 0.0; frame_y = 0.0
			"up":    frame_x = 512.0; frame_y = 0.0
			"left":  frame_x = 0.0; frame_y = 512.0
			"right": frame_x = 512.0; frame_y = 512.0
		var src := Rect2(frame_x, frame_y, 512.0, 512.0)
		draw_texture_rect_region(world_sprite_sheet, Rect2(-14.0, -40.0, 28.0, 40.0), src)
		return

	# Placeholder dabbawala silhouette
	draw_rect(Rect2(-6, -14, 12, 14), Color(0.85, 0.3, 0.2))
	draw_circle(Vector2(0, -18), 6, Color(0.75, 0.5, 0.3))
	if _carrying_tiffin:
		draw_rect(Rect2(-5, -28, 10, 4), Color(0.8, 0.6, 0.2))
		draw_rect(Rect2(-4, -32, 8, 4), Color(0.85, 0.65, 0.25))
