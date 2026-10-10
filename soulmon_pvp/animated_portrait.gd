class_name AnimatedPortrait
extends TextureRect
## Animated portrait using fighter's sprite sheet idle animation.

@export var sheet_path: String = ""
@export var frame_size: Vector2 = Vector2(64, 64)
@export var idle_row: int = 0
@export var frame_count: int = 4
@export var fps: float = 6.0
@export var loop: bool = true

var _atlas: AtlasTexture
var _timer: Timer
var _current_frame: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if sheet_path != "":
		_setup_animation()

func _setup_animation() -> void:
	var tex: Texture2D = load(sheet_path)
	_current_frame = 0
	_atlas = AtlasTexture.new()
	_atlas.atlas = tex
	_atlas.region = Rect2(0, idle_row * frame_size.y, frame_size.x, frame_size.y)
	texture = _atlas

	# Create the timer once and reuse it, otherwise every fighter change
	# stacks another timer and the animation speeds up.
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = false
		_timer.timeout.connect(_on_frame_advance)
		add_child(_timer)
	_timer.wait_time = 1.0 / fps
	_timer.start()

func _on_frame_advance() -> void:
	if not _atlas:
		return

	_current_frame = (_current_frame + 1) % frame_count
	_atlas.region = Rect2(_current_frame * frame_size.x, idle_row * frame_size.y, frame_size.x, frame_size.y)

func set_fighter(fighter_data: Dictionary) -> void:
	sheet_path = fighter_data.sheet
	# Parse ANIMS from fighter script to get idle animation info
	# For now, use defaults - could be enhanced to read from fighter's ANIMS constant
	_setup_animation()

func stop() -> void:
	if _timer:
		_timer.stop()

func start() -> void:
	if _timer:
		_timer.start()