class_name StateMachine
extends Node
## Calls fighter.state_<name>(delta) each tick, plus optional
## enter_<name>() / exit_<name>() hooks on change.
## (`fighter` is untyped on purpose to avoid a Fighter<->StateMachine script cycle.)

var fighter
var current := ""
var frames := 0  # physics frames spent in current state (1 on first tick)

func start(f, initial: String) -> void:
    fighter = f
    current = initial
    frames = 0
    _hook("enter_")

func change(next: String) -> void:
    _hook("exit_")
    current = next
    frames = 0
    _hook("enter_")

func tick(delta: float) -> void:
    frames += 1
    fighter.call("state_" + current, delta)

func _hook(prefix: String) -> void:
    var m := prefix + current
    if fighter.has_method(m):
        fighter.call(m)
