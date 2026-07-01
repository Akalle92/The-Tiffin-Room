## HUD.gd — Always-visible heads-up display.
## Shows: day number, time bar, delivery progress, stats.
extends CanvasLayer

# ---------------------------------------------------------------------------
# NODES
# ---------------------------------------------------------------------------
@onready var day_label: Label           = $TopBar/DayLabel
@onready var time_bar: ProgressBar      = $TopBar/TimeBar
@onready var delivery_label: Label      = $TopBar/DeliveryLabel
@onready var stat_container: HBoxContainer = $TopBar/StatContainer
@onready var notification_label: Label  = $NotificationLabel
@onready var phase_label: Label         = $TopBar/PhaseLabel

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _notif_timer: float = 0.0
const NOTIF_DURATION := 3.0
var _stat_labels: Dictionary = {}

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	_build_stat_display()
	_refresh_all()

	GameState.day_started.connect(func(_d): _refresh_all())
	GameState.night_started.connect(func(_d): _refresh_all())
	GameState.delivery_completed.connect(func(_id): _refresh_delivery())
	GameState.stat_changed.connect(_on_stat_changed)

func _process(delta: float) -> void:
	# Update time bar smoothly
	if time_bar:
		time_bar.value = GameState.time_of_day * 100.0

	# Notification fade
	if _notif_timer > 0:
		_notif_timer -= delta
		if _notif_timer <= 0:
			notification_label.visible = false

# ---------------------------------------------------------------------------
# STAT LABELS
# ---------------------------------------------------------------------------
func _build_stat_display() -> void:
	if stat_container == null: return
	for stat in GameState.player_stats:
		var lbl := Label.new()
		lbl.text = _stat_short(stat) + ":" + str(GameState.player_stats[stat])
		lbl.add_theme_color_override("font_color", StatCheck.stat_color(stat))
		lbl.add_theme_font_size_override("font_size", 9)
		stat_container.add_child(lbl)
		_stat_labels[stat] = lbl

func _stat_short(stat: String) -> String:
	match stat:
		"EMPATHY":      return "EMP"
		"NOSE":         return "NSE"
		"STEADY_HANDS": return "STD"
		"STREET_SENSE": return "STR"
		"GRIEF":        return "GRF"
		_:              return stat.left(3)

func _on_stat_changed(stat_name: String, new_value: int) -> void:
	if _stat_labels.has(stat_name):
		_stat_labels[stat_name].text = _stat_short(stat_name) + ":" + str(new_value)
	show_notification("%s increased to %d!" % [stat_name, new_value])

# ---------------------------------------------------------------------------
# REFRESH HELPERS
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	_refresh_day()
	_refresh_delivery()
	_refresh_phase()

func _refresh_day() -> void:
	if day_label:
		day_label.text = "Day %d" % GameState.day_number

func _refresh_delivery() -> void:
	if delivery_label == null: return
	var total := GameState.today_deliveries.size()
	var done  := GameState.completed_deliveries.size()
	delivery_label.text = "Tiffins: %d / %d" % [done, total]

func _refresh_phase() -> void:
	if phase_label == null: return
	phase_label.text = "NIGHT — Spirit City  ·  [R] Rest till dawn" if GameState.is_night else "DAY — The Route"
	phase_label.add_theme_color_override("font_color",
		Color(0.6, 0.5, 0.9) if GameState.is_night else Color(0.9, 0.75, 0.3))

# ---------------------------------------------------------------------------
# NOTIFICATION
# ---------------------------------------------------------------------------
func show_notification(text: String) -> void:
	if notification_label == null: return
	notification_label.text = text
	notification_label.visible = true
	notification_label.modulate.a = 1.0
	_notif_timer = NOTIF_DURATION
