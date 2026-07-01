## RouteJournal.gd — Full-screen relationship journal overlay.
## Toggle with J. Left panel = route list. Right panel = selected route detail.
extends CanvasLayer

# ---------------------------------------------------------------------------
# NODES
# ---------------------------------------------------------------------------
@onready var route_list: VBoxContainer       = $Background/VBox/HSplit/LeftPanel/ScrollContainer/RouteList
@onready var detail_panel: VBoxContainer     = $Background/VBox/HSplit/RightPanel/ScrollContainer/DetailVBox
@onready var detail_name: Label              = $Background/VBox/HSplit/RightPanel/ScrollContainer/DetailVBox/NameLabel
@onready var detail_title: Label             = $Background/VBox/HSplit/RightPanel/ScrollContainer/DetailVBox/TitleLabel
@onready var detail_trust: Label             = $Background/VBox/HSplit/RightPanel/ScrollContainer/DetailVBox/TrustLabel
@onready var detail_deliveries: Label        = $Background/VBox/HSplit/RightPanel/ScrollContainer/DetailVBox/DeliveriesLabel
@onready var detail_spirit_status: Label     = $Background/VBox/HSplit/RightPanel/ScrollContainer/DetailVBox/SpiritLabel
@onready var detail_notes_container: VBoxContainer = $Background/VBox/HSplit/RightPanel/ScrollContainer/DetailVBox/NotesContainer
@onready var close_btn: Button               = $Background/VBox/HeaderBar/CloseButton
@onready var day_label: Label                = $Background/VBox/HeaderBar/DayLabel

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _selected_npc_id: String = ""
const TRUST_LABELS := ["Stranger", "Acquaintance", "Trusted", "Open"]

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	hide()
	close_btn.pressed.connect(toggle)
	GameState.route_updated.connect(_on_route_updated)
	_apply_ui_skin()

# ---------------------------------------------------------------------------
# UI SKIN — journal cover texture as panel background
# ---------------------------------------------------------------------------
func _apply_ui_skin() -> void:
	const COVER_PATH := "res://assets/ui/journal_cover.png"
	if not ResourceLoader.exists(COVER_PATH):
		return  # placeholder style stays until asset is downloaded

	# Apply journal cover as left-panel background texture
	var tex: Texture2D = load(COVER_PATH)
	var left_panel: PanelContainer = $Background/VBox/HSplit/LeftPanel
	if left_panel:
		var style := StyleBoxTexture.new()
		style.texture = tex
		style.texture_margin_left   = 0.0
		style.texture_margin_right  = 0.0
		style.texture_margin_top    = 0.0
		style.texture_margin_bottom = 0.0
		left_panel.add_theme_stylebox_override("panel", style)

	# Apply dark parchment tint to right detail panel
	var right_panel: PanelContainer = $Background/VBox/HSplit/RightPanel
	if right_panel:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
		style.border_width_left   = 2
		style.border_color        = Color(0.55, 0.40, 0.20)
		right_panel.add_theme_stylebox_override("panel", style)

func _unhandled_input(event: InputEvent) -> void:
	# Don't let the journal open over dialogue or a mini-game overlay.
	if not visible and DialogueManager.is_active:
		return
	if event.is_action_pressed("toggle_journal"):
		toggle()
		get_viewport().set_input_as_handled()
	if visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# PUBLIC
# ---------------------------------------------------------------------------
func toggle() -> void:
	if visible:
		hide()
	else:
		_refresh_list()
		show()

func _on_route_updated(_npc_id: String) -> void:
	if not visible: return
	_refresh_list()
	if _selected_npc_id != "":
		_show_detail(_selected_npc_id)

# ---------------------------------------------------------------------------
# LIST
# ---------------------------------------------------------------------------
func _refresh_list() -> void:
	# Update header
	if day_label:
		day_label.text = "Day %d  —  The Tiffin Route" % GameState.day_number

	# Clear existing entries
	for child in route_list.get_children():
		child.queue_free()

	# Build one button per unlocked route
	for npc_id in GameState.routes:
		var route: Dictionary = GameState.routes[npc_id]
		if not route.get("unlocked", false):
			continue

		var btn := Button.new()
		var resolved: bool = route.get("spirit_resolved", false)
		var spirit_unlocked: bool = route.get("spirit_unlocked", false)

		var prefix := ""
		if resolved:
			prefix = "✦ "
		elif spirit_unlocked:
			prefix = "◎ "
		else:
			prefix = "○ "

		btn.text = prefix + route.get("name", npc_id)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.toggle_mode = true
		if npc_id == _selected_npc_id:
			btn.button_pressed = true

		var id: String = npc_id  # capture for closure
		btn.pressed.connect(func(): _on_route_selected(id))
		route_list.add_child(btn)

	# Auto-select first if nothing selected
	if _selected_npc_id == "" and not GameState.routes.is_empty():
		for npc_id in GameState.routes:
			if GameState.routes[npc_id].get("unlocked", false):
				_selected_npc_id = npc_id
				break

	if _selected_npc_id != "":
		_show_detail(_selected_npc_id)

func _on_route_selected(npc_id: String) -> void:
	_selected_npc_id = npc_id
	_show_detail(npc_id)

# ---------------------------------------------------------------------------
# DETAIL
# ---------------------------------------------------------------------------
func _show_detail(npc_id: String) -> void:
	var route: Dictionary = GameState.get_route(npc_id)
	if route.is_empty(): return

	detail_name.text   = route.get("name",  npc_id)
	detail_title.text  = route.get("title", "")

	var trust: int = route.get("trust_level", 0)
	detail_trust.text = "Relationship:  %s" % TRUST_LABELS[clampi(trust, 0, 3)]

	var dc: int = route.get("delivery_count", 0)
	detail_deliveries.text = "Tiffins delivered: %d" % dc

	# Spirit status
	var spirit_resolved: bool  = route.get("spirit_resolved", false)
	var spirit_unlocked: bool  = route.get("spirit_unlocked", false)
	if spirit_resolved:
		detail_spirit_status.text = "Spirit: ✦ Resolved"
		detail_spirit_status.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	elif spirit_unlocked:
		detail_spirit_status.text = "Spirit: ◎ Accessible (visit at night)"
		detail_spirit_status.add_theme_color_override("font_color", Color(0.65, 0.55, 0.9))
	else:
		detail_spirit_status.text = "Spirit: ○ Not yet reached"
		detail_spirit_status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	# Notes
	for child in detail_notes_container.get_children():
		child.queue_free()
	var notes: Array = route.get("notes", [])
	if notes.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(No notes yet)"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		detail_notes_container.add_child(empty_lbl)
	else:
		for note in notes:
			var lbl := Label.new()
			lbl.text = "• " + note
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_notes_container.add_child(lbl)
