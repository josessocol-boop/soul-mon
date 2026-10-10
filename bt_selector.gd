class_name Selector
extends AIBehavior
## Tries children left-to-right, returns first SUCCESS or RUNNING.

var children: Array[AIBehavior] = []

func tick(ai: AIController) -> Status:
	for child in children:
		var result: Status = child.tick(ai)
		if result == Status.SUCCESS:
			return Status.SUCCESS
		if result == Status.RUNNING:
			return Status.RUNNING
	return Status.FAILURE
