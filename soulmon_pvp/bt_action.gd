class_name Action
extends AIBehavior
## Buffers an input action for the fighter. duration 0 = instant SUCCESS.

var action_name: String = ""  # attack, special1, special2, ultimate, dash, jump
var duration: float = 0.0
var _timer: float = 0.0
var _started: bool = false

func tick(ai: AIController) -> Status:
	if not _started:
		_started = true
		if action_name != "":
			ai.buffer_action(action_name)
		_timer = duration
		if duration <= 0.0:
			_started = false
			return Status.SUCCESS
		return Status.RUNNING

	_timer -= _get_delta(ai)
	if _timer <= 0.0:
		_started = false
		return Status.SUCCESS
	return Status.RUNNING

func _reset() -> void:
	_timer = 0.0
	_started = false
