class_name AIBehavior
extends RefCounted
## Base class for behavior tree nodes. All nodes return Status enum.

enum Status { SUCCESS, FAILURE, RUNNING }

## Override in derived classes. Called each decision tick.
func tick(_ai: AIController) -> Status:
	return Status.FAILURE

func _reset() -> void:
	pass

## Seconds since the AI's last decision. The tree only ticks at the reaction interval, so cooldowns and
## action durations must count this, not one physics frame (that made a 3 s cooldown last about 45 s).
func _get_delta(ai: AIController) -> float:
	return ai.decision_dt
