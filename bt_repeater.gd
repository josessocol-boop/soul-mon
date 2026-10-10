class_name Repeater
extends AIBehavior

var child: AIBehavior
var count: int = -1  # -1 = infinite
var _current_count: int = 0

func tick(ai: AIController) -> Status:
	if not child:
		return Status.FAILURE
	var result: Status = child.tick(ai)
	if result == Status.SUCCESS:
		_current_count += 1
		if count > 0 and _current_count >= count:
			_current_count = 0
			return Status.SUCCESS
		return Status.RUNNING
	if result == Status.RUNNING:
		return Status.RUNNING
	_current_count = 0
	return Status.FAILURE

func _reset() -> void:
	_current_count = 0
