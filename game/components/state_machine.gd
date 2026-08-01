class_name StateMachine
extends Node
## Minimal finite state machine. Parent entities call `transition_to`.
## Expected parent: entity root. Optional child state nodes are not required in Phase 1.

signal state_changed(from_state: StringName, to_state: StringName)

var current_state: StringName = &""


func start(initial_state: StringName) -> void:
	current_state = initial_state
	state_changed.emit(&"", initial_state)


func transition_to(next_state: StringName) -> bool:
	if next_state == current_state:
		return false
	var previous := current_state
	current_state = next_state
	state_changed.emit(previous, next_state)
	return true


func is_in(state_name: StringName) -> bool:
	return current_state == state_name
