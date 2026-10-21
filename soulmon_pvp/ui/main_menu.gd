extends CanvasLayer

@onready var play_btn = %PlayButton
@onready var chars_btn = %CharactersButton
@onready var options_btn = %OptionsButton
@onready var quit_btn = %QuitButton

func _ready() -> void:
	print("MainMenu _ready() - connecting buttons")

	# Fallback: use get_node if % syntax fails
	if not play_btn:
		play_btn = get_node("VBoxContainer/PlayButton")
	if not chars_btn:
		chars_btn = get_node("VBoxContainer/CharactersButton")
	if not options_btn:
		options_btn = get_node("VBoxContainer/OptionsButton")
	if not quit_btn:
		quit_btn = get_node("VBoxContainer/QuitButton")

	print("Buttons: play=%s, chars=%s, options=%s, quit=%s" % [play_btn, chars_btn, options_btn, quit_btn])

	if play_btn:
		play_btn.pressed.connect(_on_play)
	if chars_btn:
		chars_btn.pressed.connect(_on_characters)
	if options_btn:
		options_btn.pressed.connect(_on_options)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)

func _on_play() -> void:
	print("PLAY button pressed")
	# Play -> Character Select (PLAYER / CPU switch and CPU level are on that screen) -> match
	_change_to_arena(true)

func _on_characters() -> void:
	print("CHARACTERS button pressed")
	_change_to_arena(true)

func _change_to_arena(view_mode: bool) -> void:
	if view_mode and Settings:
		Settings.set_view_mode_only(true)

	if not ResourceLoader.exists("res://arena/main.tscn"):
		print("ERROR: main.tscn not found!")
		return

	var err = get_tree().change_scene_to_file("res://arena/main.tscn")
	if err != OK:
		print("ERROR changing scene: ", err)

func _on_options() -> void:
	print("OPTIONS button pressed")
	UIManager.show_menu("res://ui/options_menu.tscn")

func _on_quit() -> void:
	print("QUIT button pressed")
	get_tree().quit()