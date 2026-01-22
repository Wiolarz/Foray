@abstract class_name Helpers
extends RefCounted


static func remove_all_children(node : Node, include_internal : bool = false):
	var children = node.get_children(include_internal)
	for child in children:
		node.remove_child(child)  # acts faster than queue_free() useful to avoid animation calls for killed units
		child.queue_free()
