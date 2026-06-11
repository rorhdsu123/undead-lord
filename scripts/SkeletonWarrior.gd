extends CharacterBody2D

const ArrowScene = preload("res://scenes/Arrow.tscn")

const TYPE_PRESETS: Dictionary = {
	"warrior": {
		"hp": 100, "speed": 90, "damage": 10, "range": 80, "interval": 1.0,
		"scale": 1.0, "behavior": "melee", "evolves": true, "variant": 1,
	},
	"archer": {
		"hp": 60, "speed": 80, "damage": 8, "range": 400, "interval": 1.2,
		"scale": 0.85, "behavior": "ranged", "evolves": true, "variant": 2,
	},
	"tank": {
		"hp": 250, "speed": 50, "damage": 14, "range": 30, "interval": 1.3,
		"scale": 1.45, "behavior": "melee", "evolves": true, "variant": 3,
	},
	"bomber": {
		"hp": 50, "speed": 115, "damage": 60, "range": 25, "interval": 999.0,
		"scale": 0.85, "behavior": "bomber", "evolves": false, "variant": 1,
	},
}

const EVOLUTION_THRESHOLDS: Array = [5, 10]
const EVOLUTION_MULTS: Array = [1.0, 1.25, 1.6]
const BOMB_RADIUS: float = 80.0
const BASE_SPRITE_SCALE: float = 0.246
const GUARD_ENGAGE_RANGE: float = 150.0  # 포스트에서 이 거리 안 적만 교전

static var _cached_frames: Dictionary = {}

var minion_type: String = "warrior"
var hp: float = 100.0
var max_hp: float = 100.0
var attack_damage: float = 10.0
var base_damage: float = 10.0
var move_speed: float = 90.0
var attack_range: float = 30.0
var attack_interval: float = 1.0
var behavior: String = "melee"
var evolves: bool = true
var base_max_hp: float = 100.0
var base_scale: float = 1.0

var kill_count: int = 0
var level: int = 1
var attack_timer: float = 0.0
var current_target = null
var game = null
var _anim_state: String = ""
var lifesteal: float = 0.0
var _died_reported: bool = false
var has_post: bool = false
var guard_post: Vector2 = Vector2.ZERO
var guard_slot_index: int = -1
var is_dragging: bool = false
var sacrifice_highlight: bool = false:
	set(v):
		sacrifice_highlight = v
		queue_redraw()
var is_selected: bool = false:
	set(v):
		is_selected = v
		queue_redraw()

@onready var hp_bar: ProgressBar = $HPBar
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("minions")
	collision_layer = 2
	collision_mask = 0
	var preset: Dictionary = TYPE_PRESETS.get(minion_type, TYPE_PRESETS["warrior"])
	hp = preset["hp"]
	max_hp = preset["hp"]
	base_max_hp = max_hp
	attack_damage = preset["damage"]
	base_damage = attack_damage
	move_speed = preset["speed"]
	attack_range = preset["range"]
	attack_interval = preset["interval"]
	behavior = preset["behavior"]
	evolves = preset["evolves"]
	base_scale = preset["scale"]

	var variant: int = preset["variant"]
	anim_sprite.sprite_frames = _get_sprite_frames(variant)
	anim_sprite.scale = Vector2.ONE * BASE_SPRITE_SCALE * base_scale
	anim_sprite.show_behind_parent = true
	anim_sprite.animation_finished.connect(_on_animation_finished)
	_play_anim("idle")

static func _get_sprite_frames(variant: int) -> SpriteFrames:
	if variant in _cached_frames:
		return _cached_frames[variant]
	var sf: SpriteFrames = _build_sprite_frames(variant)
	_cached_frames[variant] = sf
	return sf

static func _load_anim(sf: SpriteFrames, anim: String, base_path: String, prefix: String, sub: String, count: int, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 15.0)
	for i: int in count:
		var tex: Texture2D = load("%s%s/%s_%s_%03d.png" % [base_path, sub, prefix, sub, i])
		if tex:
			sf.add_frame(anim, tex)

static func _build_sprite_frames(variant: int) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/skeleton_warrior_%d/" % variant
	var prefix: String = "0_Skeleton_Warrior"
	_load_anim(sf, "idle",  base_path, prefix, "Idle",     18, true)
	_load_anim(sf, "walk",  base_path, prefix, "Walking",  24, true)
	_load_anim(sf, "slash", base_path, prefix, "Slashing", 12, false)
	_load_anim(sf, "hurt",  base_path, prefix, "Hurt",     12, false)
	_load_anim(sf, "die",   base_path, prefix, "Dying",    15, false)
	return sf

func _draw() -> void:
	if sacrifice_highlight:
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 24, Color(1.0, 0.2, 0.2, 0.9), 2.5)
	elif is_selected:
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 24, Color(1.0, 0.85, 0.2, 0.9), 2.5)

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
	if _anim_state == "die" or is_dragging:
		return

	if has_post:
		# 포스트 고정 모드: 포스트로 귀환 후 제자리에서 사거리 안 적만 공격
		var dp: float = position.distance_to(guard_post)
		if dp > 8.0:
			var dir: Vector2 = (guard_post - position).normalized()
			velocity = dir * move_speed
			move_and_slide()
			anim_sprite.flip_h = dir.x < 0
			if _anim_state not in ["hurt"]:
				_play_anim("walk")
			return
		velocity = Vector2.ZERO
		position = guard_post
		if not is_instance_valid(current_target) or position.distance_to(current_target.position) > attack_range:
			current_target = _find_nearest_enemy()
		if is_instance_valid(current_target) and position.distance_to(current_target.position) <= attack_range:
			if _anim_state not in ["slash", "hurt"]:
				anim_sprite.flip_h = current_target.position.x < position.x
			attack_timer += delta
			if attack_timer >= attack_interval:
				attack_timer = 0.0
				_do_attack()
		else:
			attack_timer = 0.0
			if _anim_state not in ["slash", "hurt"]:
				_play_anim("idle")
		return

	# 포스트 없는 자유 이동 모드
	if not is_instance_valid(current_target):
		current_target = _find_nearest_enemy()

	if not current_target:
		velocity = Vector2.ZERO
		if _anim_state not in ["slash", "hurt"]:
			_play_anim("idle")
		return

	var dist: float = position.distance_to(current_target.position)
	if dist > attack_range:
		var dir: Vector2 = (current_target.position - position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		attack_timer = 0.0
		anim_sprite.flip_h = dir.x < 0
		if _anim_state not in ["hurt"]:
			_play_anim("walk")
	else:
		velocity = Vector2.ZERO
		if _anim_state not in ["slash", "hurt"]:
			anim_sprite.flip_h = current_target.position.x < position.x
			_play_anim("idle")
		if behavior == "bomber":
			_do_attack()
		else:
			attack_timer += delta
			if attack_timer >= attack_interval:
				attack_timer = 0.0
				_do_attack()

func _do_attack() -> void:
	if not is_instance_valid(current_target):
		return
	_play_anim("slash")
	match behavior:
		"ranged":
			_shoot_arrow()
		"bomber":
			_explode()
		_:
			_melee_strike()

func _melee_strike() -> void:
	var prev_hp: float = current_target.hp
	current_target.take_damage(attack_damage)
	_heal(attack_damage * lifesteal)
	if prev_hp > 0 and prev_hp <= attack_damage:
		_on_kill()

func _shoot_arrow() -> void:
	if not game:
		return
	var arrow = ArrowScene.instantiate()
	var dir: Vector2 = (current_target.position - position).normalized()
	arrow.position = position
	arrow.direction = dir
	arrow.damage = attack_damage
	arrow.source = self
	arrow.lifesteal = lifesteal
	game.add_child(arrow)

func _explode() -> void:
	if not game:
		queue_free()
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if position.distance_to(e.position) <= BOMB_RADIUS:
			e.take_damage(attack_damage)
	if game.has_method("spawn_explosion_effect"):
		game.spawn_explosion_effect(position)
	_report_died()
	queue_free()

func _on_kill() -> void:
	if not evolves:
		return
	kill_count += 1
	if level < 3 and kill_count >= EVOLUTION_THRESHOLDS[level - 1]:
		_evolve()

func _evolve() -> void:
	level += 1
	var prev_max: float = max_hp
	var mult: float = EVOLUTION_MULTS[level - 1]
	max_hp = base_max_hp * mult
	hp += max_hp - prev_max
	hp = min(hp, max_hp)
	attack_damage = base_damage * mult
	anim_sprite.scale = Vector2.ONE * BASE_SPRITE_SCALE * base_scale * (1.0 + 0.15 * (level - 1))
	anim_sprite.modulate = Color.WHITE.lerp(Color(1.3, 1.1, 0.5, 1.0), 0.35 * (level - 1))
	hp_bar.value = (hp / max_hp) * 100.0
	if game and game.has_method("spawn_evolve_effect"):
		game.spawn_evolve_effect(global_position)

func _find_nearest_enemy():
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var nearest_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if has_post and guard_post.distance_to(e.position) > GUARD_ENGAGE_RANGE:
			continue
		var d: float = position.distance_to(e.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

func _heal(amount: float) -> void:
	if amount <= 0.0:
		return
	hp = min(hp + amount, max_hp)
	hp_bar.value = (hp / max_hp) * 100.0

func take_damage(dmg: float) -> void:
	if _anim_state == "die":
		return
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	if hp <= 0:
		_die()
		return
	_play_anim("hurt")

func _die() -> void:
	_play_anim("die")
	if game and game.has_method("spawn_death_effect"):
		game.spawn_death_effect(global_position, Color.WHITE)
	_report_died()

func _report_died() -> void:
	if _died_reported:
		return
	_died_reported = true
	if game and game.has_method("minion_died"):
		game.minion_died(position, minion_type, guard_slot_index)

func sacrifice() -> void:
	_report_died()
	queue_free()
