extends CharacterBody2D

const WaveData = preload("res://scripts/WaveData.gd")

const BOSS_SPRITE_MAP: Dictionary = {
	"수습 용사 인턴":    "boss_intern",
	"정의의 용사 알바생": "boss_parttime",
	"용사 대리":          "boss_assistant",
	"정의의 용사 과장":   "boss_manager",
}
const BOSS_SCALE_MAP: Dictionary = {
	"boss_intern":    0.060,
	"boss_parttime":  0.115,
	"boss_assistant": 0.130,
	"boss_manager":   0.165,
}
const BASE_SPRITE_SCALE: float = 0.09

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
var rage_charge_duration: float = 1.5
var rage_damage: int = 50

var summon_timer: float = 0.0
var summon_interval: float = 10.0

@onready var hp_bar: ProgressBar = $HPBar
@onready var name_label: Label = $NameLabel
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("enemies")
	base_speed = speed
	base_damage = damage
	name_label.text = boss_name
	collision_mask = 0
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

static func _build_sprite_frames(folder: String) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/%s/" % folder
	var anim_map: Dictionary = {
		"idle":  "Idle",
		"walk":  "Walking",
		"slash": "Slashing",
		"hurt":  "Hurt",
		"die":   "Dying",
	}
	for anim_name: String in anim_map:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, anim_name not in ["slash", "hurt", "die"])
		sf.set_animation_speed(anim_name, 15.0)
		var src_folder: String = anim_map[anim_name]
		var dir: DirAccess = DirAccess.open(base_path + src_folder)
		if not dir:
			continue
		var files: Array[String] = []
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".png"):
				files.append(fname)
			fname = dir.get_next()
		files.sort()
		for f: String in files:
			var tex: Texture2D = load(base_path + src_folder + "/" + f)
			if tex:
				sf.add_frame(anim_name, tex)
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

	if overtime_triggered:
		summon_timer += delta
		if summon_timer >= summon_interval:
			summon_timer = 0.0
			rage_timer = 0.0
			_summon_companions()

	if phase3_triggered:
		rage_timer += delta
		if rage_timer >= rage_interval:
			rage_timer = 0.0
			summon_timer = 0.0
			_start_rage_charge("이건 내 인생을 건 보고서다!!", Color(1.0, 0.2, 0.2))

func _enter_overtime() -> void:
	overtime_triggered = true
	speed = base_speed * 2.0
	damage = base_damage * 2
	attack_cooldown = 0.7
	anim_sprite.modulate = COLOR_OVERTIME
	name_label.text = boss_name + "\n[야근 모드]"
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
		game.boss_summon("swarm", 3)
		if game.has_method("show_dialogue"):
			game.show_dialogue("동료들도 같이 야근하자!", Color(0.95, 0.7, 0.2), global_position + Vector2(0, -150))

func _restore_phase_modulate() -> void:
	if phase3_triggered:
		anim_sprite.modulate = COLOR_PHASE3
	elif overtime_triggered:
		anim_sprite.modulate = COLOR_OVERTIME
	else:
		anim_sprite.modulate = COLOR_NORMAL

# ============ 피격 / 사망 ============
func take_damage(dmg: float) -> void:
	if _anim_state == "die":
		return
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	_hit_flash()
	if game:
		game.spawn_damage_number(global_position, dmg)
	if hp <= 0:
		_die()
		return
	if not is_charging_rage:
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
