class_name InteractiveObject
extends StaticBody3D
## Invisible hit proxy for one architectural object.
##
## Lives on collision layer 2 (selection rays use mask 2), never collides with
## the player, knows its information entry and can highlight its visual target
## with an additive material overlay.

var info_id := ""
var highlight_target: Node3D = null

var _highlighted := false


static func make(p_info_id: String, shape: Shape3D, transform: Transform3D,
		target: Node3D) -> InteractiveObject:
	var body := InteractiveObject.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.info_id = p_info_id
	body.highlight_target = target
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.transform = transform
	body.name = "Proxy_%s" % p_info_id
	return body


func info() -> Dictionary:
	var data := ObjectInformation.get_info(info_id)
	data["id"] = info_id
	return data


func set_highlighted(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	if highlight_target == null:
		return
	var overlay: Material = MaterialLibrary.get_material("highlight") if on else null
	for mesh_node in _collect_meshes(highlight_target):
		mesh_node.material_overlay = overlay


func _collect_meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_meshes(child))
	return out
