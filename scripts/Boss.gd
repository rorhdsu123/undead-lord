extends CharacterBody2D

const WaveData = preload("res://scripts/WaveData.gd")

const BOSS_SPRITE_MAP: Dictionary = {
	"수습 용사 인턴":    "boss_intern",
	"정의의 용사 알바생": "boss_parttime",
	"용사 대리":          "boss_assistant",
	"정의의 용사 과장":   "boss_manager",
}
const BOSS_SCALE_MAP: Dictionary = {
	"boss_intern":    0.211,
	"boss_parttime":  0.404,
	"boss_assistant": 0.457,
	"boss_manager":   0.580,
}
const BASE_SPRITE_SCALE: float = 0.316

const COLOR_NORMAL: Color  = Color.WHITE
const COLOR_DASH: Color    = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_OVERTIME: Color = Color(1.0, 0.55, 0.3, 1.0)
const COLOR_PHASE3: Color  = Color(1.5, 0.4, 0.4, 1.0)

const RAGE_DIALOGUES: Dictionary = {
	"사관후보생":     "후, 훈련받은 대로...!",
	"수습 용사 인턴": "정, 정직원만 되면...!",
	"용사 대리":      "더 이상은 못 봐준다.",
}

const BOUNDS: Rect2 = Rect2(0, -280, 1024, 900)
const DASH_SPEED: float = 400.0

static var _cached_frames: Dictionary = {}

var hp: float = 300.0
var max_hp: float = 300.0
var speed: float = 50.0
var base_speed: float = 50.0
var damage: int = 20
var base_damage: int = 20
var attack_cooldown: float = 1.2
var attack_timer: float = 0.0
var boss_name: String = "보스"
var boss_type: String = "mid_boss"

var game = null
var _anim_state: String = ""

# 인턴 - 돌진
var dash_timer: float = 0.0
var dash_interval: float = 3.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_duration: float = 0.5
var dash_elapsed: float = 0.0

# 알바생 - 페이즈
var overtime_triggered: bool = false
var phase3_triggered: bool = false

var rage_timer: float = 0.0
var rage_interval: float = 6.0
var is_charging_rage: bool = false
var rage_charge_time: float = 0.0
var is_stunned: bool = false
var rage_charge_duration: float = 1.5
var rage_damage: int = 50

var summon_timer: float = 0.0
var summon_interval: float = 18.0
var summon_count: int = 2

@onready var hp_bar: ProgressBar = $HPBar
@onready var name_label: Label = $NameLabel
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("enemies")
	base_speed = speed
	base_damage = damage
	name_label.text = boss_name
	collision_mask = 4  # 영주(레이어 3)하고만 충돌 — 겹침 방지. 잡몹(레이어1)·하인(레이어2) 무리엔 안 낌
	if boss_type == "mid_boss":
		rage_interval = 6.0
		rage_charge_duration = 1.5
		rage_damage = 50
	else:
		rage_interval = 6.0
		rage_charge_duration = 1.0
		rage_damage = 35

	var folder: String = BOSS_SPRITE_MAP.get(boss_name, "boss_intern")
	var sprite_scale: float = BOSS_SCALE_MAP.get(folder, BASE_SPRITE_SCALE)
	anim_sprite.sprite_frames = _get_sprite_frames(folder)
	anim_sprite.scale = Vector2.ONE * sprite_scale
	anim_sprite.animation_finished.connect(_on_animation_finished)
	_play_anim("idle")

static func _get_sprite_frames(folder: String) -> SpriteFrames:
	if folder in _cached_frames:
		return _cached_frames[folder]
	var sf: SpriteFrames = _build_sprite_frames(folder)
	_cached_frames[folder] = sf
	return sf

static func _get_char_prefix(folder: String) -> String:
	match folder:
		"boss_intern":    return "0_Goblin"
		"boss_parttime":  return "0_Orc"
		"boss_assistant": return "0_Valkyrie"
		"boss_manager":   return "0_Golem"
	return "0_Goblin"

static func _load_anim(sf: SpriteFrames, anim: String, base_path: String, prefix: String, sub: String, count: int, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 15.0)
	for i: int in count:
		var tex: Texture2D = load("%s%s/%s_%s_%03d.png" % [base_path, sub, prefix, sub, i])
		if tex:
			sf.add_frame(anim, tex)

static func _build_sprite_frames(folder: String) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/%s/" % folder
	var prefix: String = _get_char_prefix(folder)
	_load_anim(sf, "idle",  base_path, prefix, "Idle",     18, true)
	_load_anim(sf, "walk",  base_path, prefix, "Walking",  24, true)
	_load_anim(sf, "slash", base_path, prefix, "Slashing", 12, false)
	_load_anim(sf, "hurt",  base_path, prefix, "Hurt",     12, false)
	_load_anim(sf, "die",   base_path, prefix, "Dying",    15, false)
	return sf

func _play_anim(anim: String) -> void:
	if not is_instance_valid(anim_sprite):
		return
	if _anim_state == anim:
		return
	_anim_state = anim
	anim_sprite.play(anim)

func _on_animation_finished() -> void:
	match _anim_state:
		"slash", "hurt":
			_anim_state = ""
		"die":
			queue_free()

func _physics_process(delta: float) -> void:
	if not game:
		return
	if _anim_state == "die":
		return
	if is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if boss_type == "mid_boss":
		_pattern_intern(delta)
	else:
		_pattern_albaeng(delta)

	var castle_pos: Vector2 = game.get_node("Castle").global_position
	var dist: float = global_position.distance_to(castle_pos)
	if dist < 60.0 and not is_dashing and not is_charging_rage:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			game.castle_take_damage(damage)
			if _anim_state not in ["hurt", "die"]:
				_play_anim("slash")
	else:
		attack_timer = 0.0

# ============ 인턴 패턴 ============
func _pattern_intern(delta: float) -> void:
	if is_charging_rage:
		_process_charge(delta)
		return

	summon_timer += delta
	if summon_timer >= summon_interval:
		summon_timer = 0.0
		_summon_companions()

	var castle_pos: Vector2 = game.get_node("Castle").global_position

	if is_dashing:
		dash_elapsed += delta
		velocity = dash_direction * DASH_SPEED
		move_and_slide()
		_clamp_to_bounds()
		anim_sprite.flip_h = dash_direction.x < 0
		if _anim_state not in ["hurt", "die"]:
			_play_anim("walk")
		if dash_elapsed >= dash_duration or not BOUNDS.has_point(position):
			is_dashing = false
			dash_elapsed = 0.0
			anim_sprite.modulate = COLOR_NORMAL
		return

	var dir: Vector2 = (castle_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	_clamp_to_bounds()
	anim_sprite.flip_h = dir.x < 0
	if _anim_state not in ["slash", "hurt", "die"]:
		_play_anim("walk")

	rage_timer += delta
	if rage_timer >= rage_interval:
		rage_timer = 0.0
		var rage_line: String = RAGE_DIALOGUES.get(boss_name, "이건 진심이다.")
		_start_rage_charge(rage_line, Color(1.0, 0.6, 0.2))
		return

	dash_timer += delta
	if dash_timer >= dash_interval:
		dash_timer = 0.0
		_start_dash()

func _start_dash() -> void:
	is_dashing = true
	var angle: float = randf_range(0, PI)
	dash_direction = Vector2(cos(angle), sin(angle))
	anim_sprite.modulate = COLOR_DASH

# ============ 알바생 패턴 ============
func _pattern_albaeng(delta: float) -> void:
	if not overtime_triggered and hp <= max_hp * 0.5:
		_enter_overtime()
	if not phase3_triggered and hp <= max_hp * 0.25:
		_enter_phase3()

	if is_charging_rage:
		_process_charge(delta)
		return

	var castle_pos: Vector2 = game.get_node("Castle").global_position
	var dir: Vector2 = (castle_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	_clamp_to_bounds()
	anim_sprite.flip_h = dir.x < 0
	if _anim_state not in ["slash", "hurt", "die"]:
		_play_anim("walk")

	summon_timer += delta
	if summon_timer >= summon_interval:
		summon_timer = 0.0
		_summon_companions()

	# 분노 충전(와인드업)을 전 페이즈에서 주기 발동 — 치명타 윈도우 보장.
	# 페이즈가 깊어질수록 더 잦게(escalation), phase3는 발악 대사·색.
	rage_timer += delta
	var interval: float = rage_interval
	if phase3_triggered:
		interval = rage_interval * 0.6
	elif overtime_triggered:
		interval = rage_interval * 0.8
	if rage_timer >= interval:
		rage_timer = 0.0
		summon_timer = 0.0
		if phase3_triggered:
			_start_rage_charge("이건 내 인생을 건 보고서다!!", Color(1.0, 0.2, 0.2))
		else:
			_start_rage_charge(RAGE_DIALOGUES.get(boss_name, "이건 진심이다."), Color(1.0, 0.5, 0.2))

func _enter_overtime() -> void:
	overtime_triggered = true
	speed = base_speed * 2.0
	damage = base_damage * 2
	attack_cooldown = 0.7
	anim_sprite.modulate = COLOR_OVERTIME
	name_label.text = boss_name + "\n[야근 모드]"
	summon_interval = 10.0
	summon_count = 3
	summon_timer = summon_interval * 0.5
	if game and game.has_method("show_dialogue"):
		game.show_dialogue("야근 수당이라도 달란 말이야!!", Color(1.0, 0.6, 0.1, 1), global_position + Vector2(0, -80))

func _enter_phase3() -> void:
	phase3_triggered = true
	speed = base_speed * 3.0
	damage = base_damage * 3
	attack_cooldown = 0.5
	anim_sprite.modulate = COLOR_PHASE3
	name_label.text = boss_name + "\n[초과 야근]"
	summon_interval = 7.0
	summon_count = 3
	rage_timer = rage_interval * 0.5
	if game and game.has_method("show_dialogue"):
		game.show_dialogue("...그냥 쓰러질 때까지 달린다!!", Color(1.0, 0.2, 0.2, 1), global_position + Vector2(0, -80))

# ============ 공통 액션 ============
func _start_rage_charge(dialogue: String, color: Color) -> void:
	is_charging_rage = true
	rage_charge_time = 0.0
	velocity = Vector2.ZERO
	if _anim_state not in ["hurt", "die"]:
		_play_anim("idle")
	if game and game.has_method("show_dialogue"):
		game.show_dialogue(dialogue, color, global_position + Vector2(0, -80))

func _process_charge(delta: float) -> void:
	rage_charge_time += delta
	velocity = Vector2.ZERO
	move_and_slide()
	var t: float = rage_charge_time / rage_charge_duration
	var pulse: float = (sin(rage_charge_time * 30.0) + 1.0) * 0.5
	anim_sprite.modulate = Color(1.0, 0.9 - pulse * 0.5, 0.1 + t * 0.3, 1)
	if rage_charge_time >= rage_charge_duration:
		_execute_rage_attack()

func _execute_rage_attack() -> void:
	is_charging_rage = false
	rage_charge_time = 0.0
	_restore_phase_modulate()
	if game:
		game.castle_take_damage(rage_damage)

func _summon_companions() -> void:
	if game and game.has_method("boss_summon"):
		game.boss_summon("swarm", summon_count)

func _restore_phase_modulate() -> void:
	if phase3_triggered:
		anim_sprite.modulate = COLOR_PHASE3
	elif overtime_triggered:
		anim_sprite.modulate = COLOR_OVERTIME
	else:
		anim_sprite.modulate = COLOR_NORMAL

# ============ 와인드업 중단 / 스턴 ============
func interrupt_windup() -> void:
	if not is_charging_rage:
		return
	is_charging_rage = false
	rage_charge_time = 0.0
	_restore_phase_modulate()
	_spawn_cancel_mark()
	apply_stun(1.5)

func apply_stun(duration: float) -> void:
	is_stunned = true
	var stars: Node2D = _spawn_stun_stars()
	var t: SceneTreeTimer = get_tree().create_timer(duration)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			is_stunned = false
			_restore_phase_modulate()
		if is_instance_valid(stars):
			stars.queue_free()
	)

func _spawn_cancel_mark() -> void:
	var container: Node2D = Node2D.new()
	container.position = Vector2(0, -80)
	add_child(container)

	var x_label: Label = Label.new()
	x_label.text = "✕"
	x_label.add_theme_font_size_override("font_size", 36)
	x_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1))
	x_label.position = Vector2(-18, -40)
	container.add_child(x_label)

	var text_label: Label = Label.new()
	text_label.text = "차단!"
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
	text_label.position = Vector2(-22, 0)
	container.add_child(text_label)

	var tween: Tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(container, "modulate:a", 0.0, 0.2)
	tween.tween_callback(container.queue_free)

func _spawn_stun_stars() -> Node2D:
	var container: Node2D = Node2D.new()
	container.position = Vector2(0, -100)
	add_child(container)

	var star_label: Label = Label.new()
	star_label.text = "★★★"
	star_label.add_theme_font_size_override("font_size", 22)
	star_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1))
	star_label.position = Vector2(-28, 0)
	container.add_child(star_label)

	# 좌우 흔들림 루프 tween
	var tween: Tween = create_tween().set_loops().set_ignore_time_scale(true)
	tween.tween_property(container, "position:x", 6.0, 0.18)
	tween.tween_property(container, "position:x", -6.0, 0.18)
	tween.tween_property(container, "position:x", 0.0, 0.14)

	return container

# ============ 피격 / 사망 ============
func take_damage(dmg: float, tier: String = "normal") -> void:
	if _anim_state == "die":
		return
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	_hit_flash()
	if game:
		game.spawn_damage_number(global_position, dmg, tier)
	if hp <= 0:
		_die()
		return
	if not is_charging_rage and not is_stunned:
		_play_anim("hurt")

func _hit_flash() -> void:
	if is_charging_rage:
		return
	anim_sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)
	var t: SceneTreeTimer = get_tree().create_timer(0.1)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_charging_rage:
			_restore_phase_modulate()
	)

func _clamp_to_bounds() -> void:
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)

func apply_knockback(_from_pos: Vector2, _force: float) -> void:
	pass  # 보스는 넉백 면역

func apply_slow(_duration: float) -> void:
	pass  # 보스는 슬로우 면역

func _die() -> void:
	_play_anim("die")
	if game:
		game.spawn_death_effect(global_position, Color.WHITE)
		game.add_souls(randi_range(100, 200))
		var shards: int = WaveData.get_wave(game.current_chapter, game.current_stage, game.current_wave).get("crown_shards", 0)
		game.earn_crown_shards(shards)
		game.on_boss_killed(global_position, shards, boss_type == "boss")
		game.enemy_died(true)
