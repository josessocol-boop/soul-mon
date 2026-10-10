class_name UntilFail
extends AIBehavior

var child: AIBehavior

func tick(ai: AIController) -> Status:
	if not child:
		return Status.FAILURE
	var result: Status = child.tick(ai)
	if result == Status.FAILURE:
		return Status.SUCCESS
	return Status.RUNNING
