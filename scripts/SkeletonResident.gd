extends Node2D

const VARIANT: int = 1
const BASE_SCALE: float = 0.2
const WANDER_RADIUS: float = 70.0
const WALK_SPEED: float = 28.0
const IDLE_MIN: float = 2.0
const IDLE_MAX: float = 5.0
const WORK_CYCLE_MIN: float = 12.0
const WORK_CYCLE_MAX: float = 20.0

enum State { ARRIVING, IDLE, WALKING, RETURNING, WORKING }

static var _cached_frames: SpriteFrames = null

var home_pos: Vector2 = Vector2.ZERO
var color_tint: Color = Color.WHITE
var job: String = ""

var state: int = State.IDLE
var target_pos: Vector2 = Vector2.ZERO
var idle_timer: float = 0.0
var work_timer: float = 0.0

var anim_sprite: AnimatedSprite2D

func _ready() -> void:
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.sprite_frames = _get_frames()
	anim_sprite.scale = Vector2.ONE * BASE_SCALE
	anim_sprite.modulate = color_tint
	anim_sprite.animation_finished.connect(_on_anim_finished)
	add_child(anim_sprite)

	var area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(44, 60)
	shape.shape = rect
	shape.position = Vector2(0, -22)
	area.add_child(shape)
	area.input_pickable = true
	area.input_event.connect(_on_area_input)
	add_child(area)

	position = home_pos
	target_pos = home_pos
	work_timer = randf_range(WORK_CYCLE_MIN, WORK_CYCLE_MAX)
	_enter_idle()

static func _get_frames() -> SpriteFrames:
	if _cached_frames:
		return _cached_frames
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/skeleton_warrior_%d/" % VARIANT
	var prefix: String = "0_Skeleton_Warrior"
	_load_anim(sf, "idle",  base_path, prefix, "Idle",     18, true)
	_load_anim(sf, "walk",  base_path, prefix, "Walking",  24, true)
	_load_anim(sf, "slash", base_path, prefix, "Slashing", 12, false)
	_cached_frames = sf
	return sf

static func _load_anim(sf: SpriteFrames, anim: String, base_path: String, prefix: String, sub: String, count: int, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 12.0)
	for i: int in count:
		var tex: Texture2D = load("%s%s/%s_%s_%03d.png" % [base_path, sub, prefix, sub, i])
		if tex:
			sf.add_frame(anim, tex)

func _process(delta: float) -> void:
	match state:
		State.IDLE:
			idle_timer -= delta
			work_timer -= delta
			if work_timer <= 0.0:
				_go_home_to_work()
			elif idle_timer <= 0.0:
				_pick_wander_target()
		State.WALKING, State.RETURNING:
			var dir: Vector2 = (target_pos - position).normalized()
			position += dir * WALK_SPEED * delta
			anim_sprite.flip_h = dir.x < 0
			if position.distance_to(target_pos) < 3.0:
				position = target_pos
				if state == State.RETURNING:
					_play_work()
				else:
					_enter_idle()

func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(20.0, WANDER_RADIUS)
	target_pos = home_pos + Vector2(cos(angle), sin(angle)) * dist
	state = State.WALKING
	anim_sprite.play("walk")

func _enter_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
	anim_sprite.play("idle")

func _go_home_to_work() -> void:
	# 이미 home 근처면 바로 작업, 아니면 RETURNING 상태로 이동
	if position.distance_to(home_pos) < 5.0:
		_play_work()
	else:
		target_pos = home_pos
		state = State.RETURNING
		anim_sprite.play("walk")

func _play_work() -> void:
	state = State.WORKING
	anim_sprite.play("slash")
	work_timer = randf_range(WORK_CYCLE_MIN, WORK_CYCLE_MAX)

func _on_anim_finished() -> void:
	if state == State.WORKING:
		_enter_idle()

func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_bounce_tap()
	elif event is InputEventScreenTouch and event.pressed:
		_bounce_tap()

func _bounce_tap() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(anim_sprite, "scale", Vector2.ONE * BASE_SCALE * 1.25, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(anim_sprite, "scale", Vector2.ONE * BASE_SCALE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)

func play_arrival() -> void:
	state = State.ARRIVING
	anim_sprite.scale = Vector2.ZERO
	anim_sprite.modulate = Color(color_tint.r, color_tint.g, color_tint.b, 0.0)
	_spawn_dust_burst()
	var tween: Tween = create_tween()
	tween.parallel().tween_property(anim_sprite, "scale", Vector2.ONE * BASE_SCALE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(anim_sprite, "modulate:a", color_tint.a, 0.45)
	tween.tween_callback(_enter_idle)

func _spawn_dust_burst() -> void:
	for i: int in 8:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(4, 4)
		dot.color = Color(0.55, 0.5, 0.42, 0.85)
		dot.position = Vector2(randf_range(-8, 8), randf_range(-8, 4))
		add_child(dot)
		var ang: float = randf() * TAU
		var dist: float = randf_range(20.0, 45.0)
		var t: Tween = create_tween()
		t.parallel().tween_property(dot, "position", dot.position + Vector2(cos(ang), sin(ang)) * dist, 0.5)
		t.parallel().tween_property(dot, "modulate:a", 0.0, 0.5)
		t.tween_callback(dot.queue_free)
