extends Area2D

var direction: Vector2 = Vector2.UP
var damage: float = 8.0
var speed: float = 420.0
var lifetime: float = 1.8
var source: Node = null
var lifesteal: float = 0.0
var max_distance: float = -1.0  # >=0이면 이 거리만큼 날아간 뒤 소멸 (시각용 화살이 대상 지점에서 멈추도록)
var arrival_callback: Callable  # 시각용 화살이 목표(성벽)에 닿는 순간 1회 호출 — 데미지·피격 이펙트
var target_node: Node = null  # 조준 대상(아군 화살). 보스 몸통이 뒤편 사수 저격을 가로막지 않게 통과 판정에 사용.
var _traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _process(delta: float) -> void:
	var step: float = speed * delta
	position += direction * step
	_traveled += step
	if max_distance >= 0.0 and _traveled >= max_distance:
		if arrival_callback.is_valid():
			arrival_callback.call()
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		# 보스 몸통이 뒤편 사수 저격을 가로막지 않게 — 보스는 조준 대상일 때만 피격, 아니면 통과.
		# (사수 없을 때 궁수가 보스를 직접 조준하면 target_node=보스라 정상 명중)
		if body.is_in_group("boss") and body != target_node:
			return
		body.take_damage(damage)
		if lifesteal > 0.0 and is_instance_valid(source) and source.has_method("_heal"):
			source._heal(damage * lifesteal)
		queue_free()
