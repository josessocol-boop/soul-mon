extends CanvasLayer
## Container-driven HUD: P1 block anchored top-left, P2 mirrored top-right,
## and a legible controls hint in a translucent panel at the bottom.

const GameText := preload("res://system/game_text.gd")

@onready var root: Control = $Root
@onready var p1_hud = $Root/P1
@onready var p2_hud = $Root/P2
@onready var banner: Label = $Root/Banner
@onready var help_panel: PanelContainer = $Root/HelpPanel
@onready var help: Label = $Root/HelpPanel/Help

var f1: Fighter
var f2: Fighter

func _ready() -> void:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.text = ""
	_style_help()
	refresh_help()

func refresh_help() -> void:
	help.text = GameText.controls_help()   # built from the live key bindings

func _style_help() -> void:
	# Bright white text + thick black outline, on a dark translucent panel,
	# so it stays readable over any floor texture.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.78)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	help_panel.add_theme_stylebox_override("panel", sb)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_font_size_override("font_size", 15)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help_panel.offset_top -= 12.0
	help_panel.offset_bottom = -12.0

func bind(a: Fighter, b: Fighter, name1: String, name2: String) -> void:
	f1 = a
	f2 = b
	p1_hud.setup(name1, false, a.base_color.lightened(0.15))
	p2_hud.setup(name2, true, b.base_color.lightened(0.15))
	# anchor after setup so the (possibly reordered) blocks have their final min size
	p1_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	p2_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	p2_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	banner.set_anchors_and_offsets_preset(Control.PRESET_VCENTER_WIDE)

func show_banner(text: String) -> void:
	banner.text = text

func _process(_delta: float) -> void:
	if is_instance_valid(f1):
		p1_hud.update_from(f1)
	if is_instance_valid(f2):
		p2_hud.update_from(f2)
