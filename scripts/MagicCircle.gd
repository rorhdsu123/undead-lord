extends Node2D

const RADIUS: float = 24.0
const C_RING: Color  = Color(0.55, 0.35, 0.95, 0.55)
const C_DOT: Color   = Color(0.75, 0.55, 1.0, 0.85)
const C_INNER: Color = Color(0.45, 0.65, 1.0, 0.35)

var _angle: float = 0.0

func _process(delta: float) -> void:
	_angle += delta * 0.9
	queue_redraw()

func _draw() -> void:
	# 바깥 링
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, C_RING, 1.5)
	# 안쪽 링
	draw_arc(Vector2.ZERO, RADIUS * 0.55, 0.0, TAU, 32, C_INNER, 1.0)
	# 바깥 링 위 4개 회전 점
	for i: int in 4:
		var a: float = _angle + i * (TAU / 4.0)
		draw_circle(Vector2(cos(a), sin(a)) * RADIUS, 2.8, C_DOT)
	# 안쪽 링 위 3개 역회전 점
	for i: int in 3:
		var a: float = -_angle * 1.4 + i * (TAU / 3.0)
		draw_circle(Vector2(cos(a), sin(a)) * RADIUS * 0.55, 1.8, Color(0.8, 0.6, 1.0, 0.65))
