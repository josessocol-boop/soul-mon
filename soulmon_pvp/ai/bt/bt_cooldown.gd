class_name Cooldown
extends AIBehavior
## Child only evaluated when the cooldown is ready.

var child: AIBehavior
var cooldown_time: float = 1.0
var _timer: float = 0.0

func tick(ai: AIController) -> Status:
	if _timer > 0.0:
		_timer -= _get_delta(ai)
		return Status.FAILURE
	if not child:
		return Status.FAILURE
	var result: Status = child.tick(ai)
	if result == Status.SUCCESS:
		_timer = cooldown_time
	return result

func _reset() -> void:
	_timer = 0.0
