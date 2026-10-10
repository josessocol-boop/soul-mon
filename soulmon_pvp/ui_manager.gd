extends Node
## Menu stack manager autoload. Handles showing/hiding menus with a navigation stack.

signal menu_changed(menu_name: String)

var current_menu: CanvasLayer
var menu_stack: Array[String] = []

func show_menu(menu_scene_path: String) -> void:
	if current_menu:
		current_menu.queue_free()
	current_menu = load(menu_scene_path).instantiate()
	get_tree().root.add_child(current_menu)
	menu_stack.append(menu_scene_path)
	menu_changed.emit(menu_scene_path)

func go_back() -> void:
	if menu_stack.size() > 1:
		menu_stack.pop_back()
		show_menu(menu_stack[-1])
	elif menu_stack.size() == 1:
		menu_stack.clear()
		if current_menu:
			current_menu.queue_free()
			current_menu = null

func clear_stack() -> void:
	menu_stack.clear()
	if current_menu:
		current_menu.queue_free()
		current_menu = null

func get_current_menu() -> String:
	return menu_stack[-1] if menu_stack.size() > 0 else ""
