class_name OrnamentalBackground
extends Control
## Decorative background drawn with the 2D canvas API.
##
## Draws a procedurally generated star-and-cross line lattice (the same
## mathematical construction family as the 3D patterns) plus an optional
## double-line gold frame with corner medallions. Colours and opacity are
## exported so each screen can tune the intensity.

@export var bg_color: Color = NoorTheme.BG_DEEP
@export var draw_background: bool = true
@export var line_color: Color = Color(0.788, 0.635, 0.153, 0.07)
@export var accent_color: Color = Color(0.078, 0.561, 0.427, 0.10)
@export var spacing: float = 84.0
@export var star_radius: float = 26.0
@export var draw_frame: bool = false
@export var frame_margin: float = 18.0
@export var frame_color: Color = Color(0.788, 0.635, 0.153, 0.35)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if draw_background:
		draw_rect(rect, bg_color)

	var cols := int(size.x / spacing) + 2
	var rows := int(size.y / spacing) + 2
	# horizontal / vertical lattice
	for i in rows:
		var y := float(i) * spacing - spacing * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), line_color, 1.0)
	for j in cols:
		var x := float(j) * spacing - spacing * 0.5
		draw_line(Vector2(x, 0), Vector2(x, size.y), line_color, 1.0)
	# 8-point stars at alternating lattice nodes, diamonds at the others
	for i in rows:
		for j in cols:
			var centre := Vector2(float(j) * spacing, float(i) * spacing)
			if (i + j) % 2 == 0:
				var pts := MathUtils.polygon_vertices(8, star_radius, 0.0)
				var star := MathUtils.star_vertices(8, star_radius, star_radius * 0.45)
				var poly := PackedVector2Array()
				for p in star:
					poly.append(p + centre)
				poly.append(poly[0])
				draw_polyline(poly, line_color, 1.0)
				draw_arc(centre, star_radius * 0.45, 0, TAU, 24, accent_color, 1.0)
			else:
				var diamond := PackedVector2Array([
					centre + Vector2(star_radius * 0.5, 0),
					centre + Vector2(0, star_radius * 0.5),
					centre + Vector2(-star_radius * 0.5, 0),
					centre + Vector2(0, -star_radius * 0.5),
					centre + Vector2(star_radius * 0.5, 0),
				])
				draw_polyline(diamond, accent_color, 1.0)

	if draw_frame:
		_draw_frame(rect)


func _draw_frame(rect: Rect2) -> void:
	var inner := rect.grow(-frame_margin)
	draw_rect(inner, frame_color, false, 1.5)
	draw_rect(inner.grow(-6.0), Color(frame_color.r, frame_color.g, frame_color.b, frame_color.a * 0.55), false, 1.0)
	# corner medallions: small 8-point stars
	for corner: Vector2 in [
		inner.position,
		Vector2(inner.end.x, inner.position.y),
		inner.end,
		Vector2(inner.position.x, inner.end.y),
	]:
		var star := MathUtils.star_vertices(8, 11.0, 5.0)
		var poly := PackedVector2Array()
		for p in star:
			poly.append(p + corner)
		poly.append(poly[0])
		draw_polyline(poly, frame_color, 1.2)
		draw_circle(corner, 3.0, Color(frame_color.r, frame_color.g, frame_color.b, frame_color.a * 0.9))
