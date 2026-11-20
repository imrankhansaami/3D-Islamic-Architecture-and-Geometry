class_name GodotCompat
extends RefCounted
## Small compatibility helpers so the project degrades gracefully if a
## rendering property is unavailable in the installed Godot build.

## Returns true when [param obj] has a property called [param prop].
static func has_prop(obj: Object, prop: String) -> bool:
	if obj == null:
		return false
	for info: Dictionary in obj.get_property_list():
		if String(info.get("name", "")) == prop:
			return true
	return false


## Sets [param prop] on [param obj] only when the property exists.
## Returns true when the value was applied.
static func try_set(obj: Object, prop: String, value: Variant) -> bool:
	if has_prop(obj, prop):
		obj.set(prop, value)
		return true
	return false


## Calls [param method] with [param args] only when it exists on [param obj].
static func try_call(obj: Object, method: String, args: Array = []) -> Variant:
	if obj != null and obj.has_method(method):
		return obj.callv(method, args)
	return null
