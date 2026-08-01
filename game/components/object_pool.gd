class_name ObjectPool
extends Node
## Simple pool for frequently spawned scenes (projectiles/effects).
## Expected parent: level root or autoload-like service node.

@export var pooled_scene: PackedScene
@export var initial_size: int = 16

var _available: Array[Node] = []


func _ready() -> void:
	if pooled_scene == null:
		return
	for _i in initial_size:
		var inst := pooled_scene.instantiate()
		_available.append(inst)


func acquire() -> Node:
	if pooled_scene == null:
		return null
	var node: Node
	if _available.is_empty():
		node = pooled_scene.instantiate()
	else:
		node = _available.pop_back()
	return node


func release(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_available.append(node)
