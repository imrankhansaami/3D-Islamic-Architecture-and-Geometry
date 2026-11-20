extends Node
## PatternLibrary — presets, saved configurations and architectural panel
## assignments (autoload singleton).
##
## The laboratory, the 3D studio and the architectural environment all share
## pattern configurations through this library. Architectural panels listen to
## [signal panel_changed] and regenerate only the affected panel.

signal panel_changed(panel_id: String)
signal active_panel_changed(panel_id: String)
signal saved_patterns_changed

const SAVE_DIR := "user://patterns"
const PANEL_STATE_PATH := "user://panel_patterns.json"

## Currently selected architectural panel ("" = none). Set from the explorer
## or from the laboratory "Apply to panel" flow.
var active_panel_id: String = ""

## panel id -> display name
var panel_names: Dictionary = {}
## panel id -> PatternConfig (live instances owned by the library)
var panel_configs: Dictionary = {}

## Configurations shared with the other screens.
var lab_config: PatternConfig = null
var studio_config: PatternConfig = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	lab_config = make_preset(PatternConfig.PatternType.ROSETTE)
	studio_config = lab_config.clone()
	_build_default_panels()
	_load_panel_state()


# --- Presets -----------------------------------------------------------------

## Sensible per-type starting parameters used by Reset and the type dropdown.
func make_preset(type: int) -> PatternConfig:
	var c := PatternConfig.new()
	c.pattern_type = clampi(type, 0, PatternConfig.TYPE_NAMES.size() - 1)
	c.apply_palette(c.palette)
	match c.pattern_type:
		PatternConfig.PatternType.STAR:
			c.star_points = 8
			c.inner_radius_ratio = 0.45
		PatternConfig.PatternType.POLY_REGULAR:
			c.sides = 8
			c.repetition = 2
		PatternConfig.PatternType.POLY_OVERLAP:
			c.sides = 6
			c.symmetry_folds = 6
		PatternConfig.PatternType.POLY_CONCENTRIC:
			c.sides = 6
			c.repetition = 3
		PatternConfig.PatternType.POLY_RADIAL:
			c.sides = 4
			c.symmetry_folds = 8
		PatternConfig.PatternType.ROSETTE:
			c.star_points = 12
			c.repetition = 2
			c.symmetry_folds = 12
			c.inner_radius_ratio = 0.4
		PatternConfig.PatternType.TESS_SQUARE:
			c.repetition = 5
			c.tile_size = 1.5
			c.star_points = 8
			c.outer_radius = 4.4
			c.extrusion_depth = 0.06
		PatternConfig.PatternType.TESS_HEX:
			c.repetition = 2
			c.tile_size = 1.3
			c.star_points = 6
			c.outer_radius = 4.7
			c.extrusion_depth = 0.06
		PatternConfig.PatternType.TESS_TRIANGLE:
			c.repetition = 4
			c.tile_size = 1.0
			c.star_points = 6
			c.outer_radius = 3.2
			c.extrusion_depth = 0.06
		PatternConfig.PatternType.GIRIH:
			c.star_points = 8
			c.repetition = 3
			c.tile_size = 1.7
			c.symmetry_folds = 8
			c.extrusion_depth = 0.08
	c.clamp_values()
	return c


# --- Architectural panels ----------------------------------------------------

func _build_default_panels() -> void:
	panel_names = {
		"floor_medallion": "Courtyard Floor Medallion",
		"gate_panel": "Entrance Portal Panel",
		"arcade_panel_east": "East Arcade Wall Panel",
		"arcade_panel_west": "West Arcade Wall Panel",
		"hall_panel": "Hall Interior Panel",
	}

	var medallion := make_preset(PatternConfig.PatternType.ROSETTE)
	medallion.star_points = 12
	medallion.repetition = 2
	medallion.symmetry_folds = 12
	medallion.line_thickness = 0.085
	medallion.extrusion_depth = 0.035
	medallion.scale = 1.0
	medallion.apply_palette(4)  # Marble & Malachite: light inlay on stone
	medallion.clamp_values()
	panel_configs["floor_medallion"] = medallion

	var gate := make_preset(PatternConfig.PatternType.STAR)
	gate.star_points = 8
	gate.inner_radius_ratio = 0.42
	gate.line_thickness = 0.075
	gate.extrusion_depth = 0.05
	gate.apply_palette(3)  # Bronze & Navy
	gate.clamp_values()
	panel_configs["gate_panel"] = gate

	var east := make_preset(PatternConfig.PatternType.TESS_SQUARE)
	east.repetition = 3
	east.tile_size = 1.0
	east.line_thickness = 0.05
	east.extrusion_depth = 0.05
	east.show_fills = true
	east.apply_palette(1)  # Lapis & Ivory
	east.clamp_values()
	panel_configs["arcade_panel_east"] = east

	var west := make_preset(PatternConfig.PatternType.GIRIH)
	west.star_points = 8
	west.repetition = 3
	west.tile_size = 0.95
	west.line_thickness = 0.05
	west.extrusion_depth = 0.05
	west.apply_palette(0)  # Emerald & Gold
	west.clamp_values()
	panel_configs["arcade_panel_west"] = west

	var hall := make_preset(PatternConfig.PatternType.ROSETTE)
	hall.star_points = 10
	hall.repetition = 2
	hall.symmetry_folds = 10
	hall.line_thickness = 0.07
	hall.extrusion_depth = 0.045
	hall.apply_palette(2)  # Turquoise & Sand
	hall.clamp_values()
	panel_configs["hall_panel"] = hall


func set_active_panel(panel_id: String) -> void:
	if panel_id == active_panel_id:
		return
	active_panel_id = panel_id
	active_panel_changed.emit(panel_id)


func assign_panel(panel_id: String, config: PatternConfig) -> void:
	if not panel_configs.has(panel_id):
		return
	panel_configs[panel_id] = config.clone()
	_save_panel_state()
	panel_changed.emit(panel_id)


func get_panel_config(panel_id: String) -> PatternConfig:
	if panel_configs.has(panel_id):
		return panel_configs[panel_id]
	return null


func panel_display_name(panel_id: String) -> String:
	return String(panel_names.get(panel_id, panel_id))


# --- Saved user patterns -----------------------------------------------------

func save_pattern(name: String, config: PatternConfig) -> String:
	var clean := _sanitize_name(name)
	if clean.is_empty():
		return "Please enter a name."
	var path := "%s/%s.json" % [SAVE_DIR, clean]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Could not write %s" % path
	file.store_string(config.to_json())
	file.close()
	saved_patterns_changed.emit()
	return ""


func list_saved_patterns() -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name.get_basename())
	names.sort()
	return names


func load_pattern(name: String) -> PatternConfig:
	var path := "%s/%s.json" % [SAVE_DIR, _sanitize_name(name)]
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var config := PatternConfig.from_json(file.get_as_text())
	file.close()
	return config


func delete_pattern(name: String) -> void:
	var path := "%s/%s.json" % [SAVE_DIR, _sanitize_name(name)]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		saved_patterns_changed.emit()


func _sanitize_name(name: String) -> String:
	var clean := name.strip_edges()
	for bad: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		clean = clean.replace(bad, "_")
	return clean


# --- Panel state persistence -------------------------------------------------

func _save_panel_state() -> void:
	var data := {}
	for panel_id: String in panel_configs:
		var config: PatternConfig = panel_configs[panel_id]
		data[panel_id] = config.to_dict()
	var file := FileAccess.open(PANEL_STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _load_panel_state() -> void:
	if not FileAccess.file_exists(PANEL_STATE_PATH):
		return
	var file := FileAccess.open(PANEL_STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for panel_id: String in data:
		if not panel_configs.has(panel_id):
			continue
		var config := PatternConfig.new()
		config.from_dict(data[panel_id])
		panel_configs[panel_id] = config
