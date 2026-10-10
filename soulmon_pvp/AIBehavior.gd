class_name AIBehavior
extends RefCounted
## Base class for behavior tree nodes. All nodes return Status enum.

enum Status { SUCCESS, FAILURE, RUNNING }

## Override in derived classes. Called each decision tick.
func tick(_ai: AIController) -> Status:
	return Status.FAILURE

func _reset() -> void:
	pass

## Helper: get delta time from AI controller
func _get_delta(ai: AIController) -> float:
	return ai.get_physics_process_delta_time()
