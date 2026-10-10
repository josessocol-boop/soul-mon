class_name Condition
extends AIBehavior
## Evaluates a check (Callable returning bool).

var check_func: Callable

func tick(ai: AIController) -> Status:
	if check_func.is_valid():
		return Status.SUCCESS if check_func.call(ai) else Status.FAILURE
	return Status.FAILURE
