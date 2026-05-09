extends CharacterBody2D

const TYPE_PRESETS: Dictionary = {
	"normal": {"hp_mult": 1.0, "speed_mult": 1.0, "damage_mult": 1.0, "scale": 1.0,
		"folder": "enemy_normal", "attack_anim": "Slashing"},
	"scout":  {"hp_mult": 0.5, "speed_mult": 1.8, "damage_mult": 0.6, "scale": 0.8,
		"folder": "enemy_scout",  "attack_anim": "Shooting"},
	"brute":  {"hp_mult": 3.0, "speed_mult": 0.5, "damage_mult": 1.5, "scale": 1.45,
		"folder": "enemy_brute",  "attack_anim": "Slashing"},
	"swarm":  {"hp_mult": 0.3, "speed_mult": 1.3, "damage_mult": 0.5, "scale": 0.65,
		"folder": "enemy_swarm",  "attack_anim": "Kicking"},
}

const BASE_HP: float = 50.0
const BASE_SPEED: float = 60.0
const BASE_DAMAGE: int = 10
const BASE_SPRITE_SCALE: float = 0.07
const MINION_ENGAGE_RANGE: float = 100.0

static var _cached_frames: Dictionary = {}

var hp: float = 50.0
var max_hp: float = 50.0
var speed: float = 60.0
var base_speed: float = 60.0
var damage: int = 10
var attack_cooldown: float = 1.5
var attack_timer: float = 0.0
var slow_timer: float = 0.0
var enemy_type: String = "normal"
var _attack_anim: String = "slash"
var _anim_state: String = ""

var game = null

@onready var hp_bar: ProgressBar = $HPBar
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("enemies")
	var preset: Dictionary = TYPE_PRESETS.get(enemy_type, TYPE_PRESETS["normal"])
	var base_scale: float = preset["scale"]
	hp = BASE_HP * preset["hp_mult"]
	max_hp = hp
	speed = BASE_SPEED * preset["speed_mult"]
	base_speed = speed
	damage = int(BASE_DAMAGE * preset["damage_mult"])
	_attack_anim = preset["attack_anim"].to_lower()

	var folder: String = preset["folder"]
	anim_sprite.sprite_frames = _get_sprite_frames(folder, preset["attack_anim"])
	anim_sprite.scale = Vector2.ONE * BASE_SPRITE_SCALE * base_scale
	anim_sprite.animation_finished.connect(_on_animation_finished)
	_play_anim("idle")

static func _get_sprite_frames(folder: String, attack_folder: String) -> SpriteFrames:
	if folder in _cached_frames:
		return _cached_frames[folder]
	var sf: SpriteFrames = _build_sprite_frames(folder, attack_folder)
	_cached_frames[folder] = sf
	return sf

static func _build_sprite_frames(folder: String, attack_folder: String) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/%s/" % folder
	var anim_map: Dictionary = {
		"idle":   "Idle",
		"walk":   "Walking",
		"attack": attack_folder,
		"hurt":   "Hurt",
		"die":    "Dying",
	}
	for anim_name: String in anim_map:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, anim_name not in ["attack", "hurt", "die"])
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
		"attack", "hurt":
			_anim_state = ""
		"die":
			queue_free()

func _physics_process(delta: float) -> void:
	if not game:
		return
	if _anim_state == "die":
		return

	if slow_timer > 0:
		slow_timer -= delta
		speed = base_speed * 0.4
	else:
		speed = base_speed

	var minion_target = _find_nearby_minion()
	var target_pos: Vector2
	if is_instance_valid(minion_target):
		target_pos = minion_target.global_position
	else:
		target_pos = game.get_node("Castle").global_position

	var dist: float = global_position.distance_to(target_pos)
	if dist < 50.0:
		velocity = Vector2.ZERO
		if _anim_state not in ["attack", "hurt"]:
			_play_anim("idle")
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			_do_attack(minion_target)
	else:
		var dir: Vector2 = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
		attack_timer = 0.0
		anim_sprite.flip_h = dir.x < 0
		if _anim_state not in ["hurt"]:
			_play_anim("walk")

func _do_attack(minion_target) -> void:
	_play_anim("attack")
	if is_instance_valid(minion_target):
		minion_target.take_damage(damage)
	else:
		game.castle_take_damage(damage)

func _find_nearby_minion():
	var nearest = null
	var nearest_dist: float = INF
	for m in get_tree().get_nodes_in_group("minions"):
		if not is_instance_valid(m):
			continue
		var d: float = global_position.distance_to(m.global_position)
		if d < MINION_ENGAGE_RANGE and d < nearest_dist:
			nearest_dist = d
			nearest = m
	return nearest

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

func _hit_flash() -> void:
	anim_sprite.modulate = Color(1.5, 0.4, 0.4, 1.0)
	var t: SceneTreeTimer = get_tree().create_timer(0.1)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			anim_sprite.modulate = Color.WHITE
	)

func apply_slow(duration: float) -> void:
	slow_timer = duration
	anim_sprite.modulate = Color(0.5, 0.5, 1.5, 1.0)
	var t: SceneTreeTimer = get_tree().create_timer(duration)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			anim_sprite.modulate = Color.WHITE
	)

func _die() -> void:
	_play_anim("die")
	if game:
		game.spawn_death_effect(global_position, Color.WHITE)
		game.add_souls(randi_range(12, 20))
		game.enemy_died()
