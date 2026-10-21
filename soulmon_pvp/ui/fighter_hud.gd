extends MarginContainer
## One player's HUD block. Layout is entirely container-driven; this script
## only styles things, sets text, and (for P2) mirrors the block.

@onready var header: HBoxContainer = $VBox/Header
@onready var name_label: Label = $VBox/Header/NameLabel
@onready var state_label: Label = $VBox/Header/StateLabel
@onready var burn_badge: Label = $VBox/Header/BurnBadge
@onready var poison_badge: Label = $VBox/Header/PoisonBadge
@onready var slow_badge: Label = $VBox/Header/SlowBadge
@onready var hp_label: Label = $VBox/Header/HPLabel
@onready var hp_bar: ProgressBar = $VBox/HPBar
@onready var stamina_bar: ProgressBar = $VBox/StaminaBar
@onready var abilities: HBoxContainer = $VBox/Abilities
@onready var s1 = $VBox/Abilities/S1
@onready var s2 = $VBox/Abilities/S2
@onready var ult = $VBox/Abilities/Ult

var hp_fill := StyleBoxFlat.new()
var st_fill := StyleBoxFlat.new()

func _text(l: Label, font_size: int, color: Color) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)

func _style_bar(bar: ProgressBar, fill: StyleBoxFlat) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.08, 0.11, 0.85)
	bg.border_color = Color(0.3, 0.32, 0.4)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)

func _reverse(c: Container) -> void:
	var n := c.get_child_count()
	for i in n:
		c.move_child(c.get_child(n - 1), i)

func setup(title: String, mirrored: bool, accent: Color) -> void:
	name_label.text = title
	_text(name_label, 16, accent)
	_text(state_label, 13, Color(0.75, 0.78, 0.85))
	_text(burn_badge, 12, Color(1.0, 0.55, 0.2))
	_text(poison_badge, 12, Color(0.8, 0.5, 1.0))
	_text(slow_badge, 12, Color(0.45, 0.75, 1.0))
	_text(hp_label, 14, Color.WHITE)
	_style_bar(hp_bar, hp_fill)
	_style_bar(stamina_bar, st_fill)
	s1.title = "S1"
	s2.title = "S2"
	ult.title = "ULT"
	ult.accent = Color(1.0, 0.8, 0.25)
	s1.accent = accent
	s2.accent = accent
	if mirrored:
		_reverse(header)
		_reverse(abilities)
		abilities.alignment = BoxContainer.ALIGNMENT_END
		hp_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		stamina_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func update_from(f: Fighter) -> void:
	var st: StatsComponent = f.stats
	hp_bar.max_value = st.max_hp
	hp_bar.value = st.hp
	var ratio := st.hp / st.max_hp
	hp_fill.bg_color = Color(0.35, 0.8, 0.4) if ratio > 0.5 else (Color(0.95, 0.75, 0.2) if ratio > 0.25 else Color(0.9, 0.25, 0.25))
	hp_label.text = "%d" % ceil(st.hp)
	stamina_bar.max_value = st.max_stamina
	stamina_bar.value = st.stamina
	st_fill.bg_color = Color(0.7, 0.35, 0.35) if st.exhausted else Color(0.95, 0.8, 0.25)
	state_label.text = "[%s]" % f.sm.current
	burn_badge.modulate.a = 1.0 if st.burning() else 0.0   # keep layout stable
	poison_badge.modulate.a = 1.0 if st.poisoned() else 0.0
	slow_badge.modulate.a = 1.0 if st.slowed() else 0.0
	var c1: float = f.cooldowns["special1"]
	var c2: float = f.cooldowns["special2"]
	s1.set_state(f.cooldown_ratio("special1"), "" if c1 <= 0.0 else "%.1f" % c1, c1 <= 0.0)
	s2.set_state(f.cooldown_ratio("special2"), "" if c2 <= 0.0 else "%.1f" % c2, c2 <= 0.0)
	var um: Dictionary = f.ult_meter()
	ult.set_state(float(um.ratio), String(um.text), bool(um.ready))
