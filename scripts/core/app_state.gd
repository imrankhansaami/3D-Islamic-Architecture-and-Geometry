extends Node
## AppState — global application settings shared by every screen (autoload singleton).
##
## Holds quality options, time-of-day lighting presets and control preferences.
## Other nodes subscribe to the signals instead of polling.
## Custom input actions are registered here at runtime so the whole key map
## lives in one maintained place (see docs in README).

signal quality_changed(key: String)
signal lighting_preset_changed(preset: int)
signal controls_changed

enum TimeOfDay { DAWN = 0, MORNING = 1, NOON = 2, AFTERNOON = 3, DUSK = 4, NIGHT = 5 }

const TIME_PRESET_NAMES: PackedStringArray = [
	"Dawn", "Morning", "Noon", "Afternoon", "Dusk", "Night",
]

const DEFAULT_QUALITY := {
	"shadows": true,
	"ssao": true,
	"glow": true,
	"msaa": 1,           # 0 = off, 1 = 2x, 2 = 4x, 3 = 8x (Viewport.MSAA_*)
	"reflections": false, # screen-space reflections (Forward+ only; off by default for integrated GPUs)
}

const MSAA_NAMES: PackedStringArray = ["Off", "2x", "4x", "8x"]

## Graphics quality options, applied by the world / preview screens.
var quality: Dictionary = DEFAULT_QUALITY.duplicate()

## Active time-of-day lighting preset.
var time_of_day: int = TimeOfDay.AFTERNOON

# --- First-person controls ---------------------------------------------------
var fp_walk_speed: float = 4.2
var fp_run_multiplier: float = 1.9
var fp_jump_velocity: float = 4.6
var fp_mouse_sensitivity: float = 0.0032
var fp_invert_y: bool = false

# --- Orbit camera controls ---------------------------------------------------
var orbit_sensitivity: float = 0.005
var orbit_zoom_step: float = 1.12
var orbit_invert_y: bool = false

## Set by the dev capture helper when launched with --screen=<id>.
var requested_start_screen: String = ""

# Custom input actions and their default physical keys ("action": "Key name").
const ACTION_DEFAULTS := {
	"noor_forward": "W",
	"noor_back": "S",
	"noor_left": "A",
	"noor_right": "D",
	"noor_jump": "Space",
	"noor_run": "Shift",
	"noor_toggle_camera": "C",
	"noor_screenshot": "F12",
	"noor_help": "H",
	"noor_time": "T",
}


func _ready() -> void:
	_register_actions()


func _register_actions() -> void:
	for action_name: String in ACTION_DEFAULTS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var key_name: String = ACTION_DEFAULTS[action_name]
		var keycode: int = OS.find_keycode_from_string(key_name)
		if keycode == 0:
			push_warning("AppState: unknown key name '%s' for action '%s'" % [key_name, action_name])
			continue
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)


# --- Quality -----------------------------------------------------------------

func quality_bool(key: String) -> bool:
	return bool(quality.get(key, true))


func quality_int(key: String) -> int:
	return int(quality.get(key, 2))


func set_quality(key: String, value: Variant) -> void:
	if quality.get(key) == value:
		return
	quality[key] = value
	quality_changed.emit(key)


func restore_quality_defaults() -> void:
	for key: String in DEFAULT_QUALITY:
		set_quality(key, DEFAULT_QUALITY[key])


# --- Time of day -------------------------------------------------------------

func set_time_of_day(preset: int) -> void:
	preset = clampi(preset, 0, TIME_PRESET_NAMES.size() - 1)
	if preset == time_of_day:
		return
	time_of_day = preset
	lighting_preset_changed.emit(preset)


func time_preset_name() -> String:
	return TIME_PRESET_NAMES[clampi(time_of_day, 0, TIME_PRESET_NAMES.size() - 1)]


func cycle_time_of_day() -> void:
	set_time_of_day((time_of_day + 1) % TIME_PRESET_NAMES.size())


# --- Controls ----------------------------------------------------------------

func restore_control_defaults() -> void:
	fp_walk_speed = 4.2
	fp_run_multiplier = 1.9
	fp_jump_velocity = 4.6
	fp_mouse_sensitivity = 0.0032
	fp_invert_y = false
	orbit_sensitivity = 0.005
	orbit_zoom_step = 1.12
	orbit_invert_y = false
	controls_changed.emit()


func notify_controls_changed() -> void:
	controls_changed.emit()
