## StatCheck.gd — Utility helpers for stat-gated interactions.
## Not an autoload — call these as static functions from anywhere.
class_name StatCheck

## Returns true if player's stat meets or exceeds threshold.
static func passes(stat_name: String, threshold: int) -> bool:
	return GameState.check_stat(stat_name, threshold)

## Returns a formatted label string like "[EMPATHY 3]" for choice display.
static func label(stat_name: String, threshold: int) -> String:
	return "[%s %d]" % [stat_name, threshold]

## Returns a coloured RichText BBCode for a stat check label.
static func bbcode_label(stat_name: String, threshold: int, passed: bool) -> String:
	var col := "ffe066" if passed else "ff6655"
	return "[color=#%s][%s %d][/color]" % [col, stat_name, threshold]

## Maps stat names to display colours for UI rendering.
static func stat_color(stat_name: String) -> Color:
	match stat_name:
		"EMPATHY":      return Color(0.9,  0.5,  0.7)
		"NOSE":         return Color(0.9,  0.75, 0.3)
		"STEADY_HANDS": return Color(0.4,  0.8,  0.55)
		"STREET_SENSE": return Color(0.4,  0.7,  0.95)
		"GRIEF":        return Color(0.6,  0.45, 0.9)
		_:              return Color.WHITE
