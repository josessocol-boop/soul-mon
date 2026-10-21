class_name Sequence
extends AIBehavior
## Runs children in order. FAILURE if any child fails, SUCCESS if all succeed.

var children: Array[AIBehavior] = []
var _current_index: int = 0

func tick(ai: AIController) -> Status:
	while _current_index < children.size():
		var result: Status = children[_current_index].tick(ai)
		if result == Status.SUCCESS:
			_current_index += 1
		elif result == Status.RUNNING:
			return Status.RUNNING
		else:
			_current_index = 0
			return Status.FAILURE
	_current_index = 0
	return Status.SUCCESS

func _reset() -> void:
	_current_index = 0
