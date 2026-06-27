extends Control

# ─── 레이아웃 상수 (플테 조정 대상) ──────────────────────────────────────
const SPEAKER_BOTTOM:     float = 776.0   # 위젯 하단 Y (조작부 TRAY_TOP=795 바로 위)
const SPEAKER_LEFT:       float = 10.0    # 좌측 여백 (px)
const PORTRAIT_H:         float = 68.0    # 초상(얼굴) 표시 높이 (px). 폭은 크롭 종횡비로 자동
const FRAME_PAD:          float = 5.0     # 프레임 안쪽 여백 (px)
const BUBBLE_MAX_WIDTH:   float = 300.0   # 말풍선 최대 폭 (초상+말풍선이 480 안에)
const HOLD_BASE:          float = 1.9    # 기본 유지 시간 (초)
const HOLD_PER_CHAR:      float = 0.07   # 글자당 추가 (초)
const HOLD_MAX:           float = 3.3    # 유지 시간 상한 (초)
const SLIDE_IN_DURATION:  float = 0.22
const SLIDE_OUT_DURATION: float = 0.20

# 말풍선 패딩
const _BUBBLE_PAD_H: float = 10.0              # 좌우 패딩
const _BUBBLE_PAD_V: float = 10.0              # 상하 패딩
const _PORTRAIT_BUBBLE_GAP: float = 4.0        # 초상 프레임과 말풍선 사이 간격(px)

# ─── 텍스처 (전신 원본에서 얼굴만 미리 잘라 구운 크롭 PNG, 320×258) ──────
# 4종 모두 포즈 동일·얼굴만 달라 동일 크롭 영역 Rect2(290,296,320,258)으로 bake됨.
const _TEX_ATTACK:  Texture2D = preload("res://assets/characters/DemonLord/face_attack.png")
const _TEX_HURT:    Texture2D = preload("res://assets/characters/DemonLord/face_hurt.png")
const _TEX_VICTORY: Texture2D = preload("res://assets/characters/DemonLord/face_victory.png")
const _TEX_DEFEAT:  Texture2D = preload("res://assets/characters/DemonLord/face_defeat.png")

# ─── 내부 노드 ──────────────────────────────────────────────────────────
var _frame:        Panel       = null      # 라운드 사각 초상 프레임
var _portrait:     TextureRect = null      # 얼굴 크롭
var _bubble_panel: Panel       = null
var _bubble_label: Label       = null
var _bubble_tail:  Polygon2D   = null      # 말풍선 좌측 삼각형 꼬리

# ─── 내부 상태 ──────────────────────────────────────────────────────────
var _frame_w:    float          = 0.0
var _frame_h:    float          = 0.0
var _tween:      Tween          = null
var _hold_timer: SceneTreeTimer = null   # 홀드 타이머 (취소는 시그널 연결 여부로 판정)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 프레임 크기 = 얼굴 표시 크기(크롭 PNG 종횡비) + 안쪽 여백
	var face_w: float = PORTRAIT_H * float(_TEX_ATTACK.get_width()) / float(_TEX_ATTACK.get_height())
	_frame_w = face_w + FRAME_PAD * 2.0
	_frame_h = PORTRAIT_H + FRAME_PAD * 2.0

	# ── 라운드 사각 초상 프레임 ──────────────────────────────────────────
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color     = Color(0.10, 0.08, 0.16, 0.95)
	frame_style.border_color = Color(0.72, 0.58, 0.30, 0.95)   # 골드 테두리
	frame_style.border_width_left   = 2
	frame_style.border_width_right  = 2
	frame_style.border_width_top    = 2
	frame_style.border_width_bottom = 2
	frame_style.corner_radius_top_left     = 12
	frame_style.corner_radius_top_right    = 12
	frame_style.corner_radius_bottom_left  = 12
	frame_style.corner_radius_bottom_right = 12

	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", frame_style)
	_frame.custom_minimum_size = Vector2(_frame_w, _frame_h)
	_frame.size = Vector2(_frame_w, _frame_h)
	_frame.clip_contents = true   # 얼굴이 프레임 밖으로 새지 않게
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	# ── 얼굴 크롭 TextureRect (프레임 안쪽) ──────────────────────────────
	_portrait = TextureRect.new()
	_portrait.texture = _TEX_ATTACK   # 기본 텍스처 (say()에서 교체)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(FRAME_PAD, FRAME_PAD)
	_portrait.size = Vector2(face_w, PORTRAIT_H)
	_portrait.custom_minimum_size = Vector2(face_w, PORTRAIT_H)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_portrait)

	# ── 말풍선 패널 ──────────────────────────────────────────────────────
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color        = Color(0.10, 0.08, 0.16, 0.92)
	style.border_color    = Color(0.55, 0.45, 0.75, 0.90)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10

	_bubble_panel = Panel.new()
	_bubble_panel.add_theme_stylebox_override("panel", style)
	_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble_panel)

	# ── 말풍선 텍스트 라벨 ───────────────────────────────────────────────
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_size_override("font_size", 18)
	_bubble_label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.97, 1.0))
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_bubble_panel.add_child(_bubble_label)

	# ── 말풍선 좌측 꼬리 삼각형 (말풍선 패널의 자식) ──────────────────────
	_bubble_tail = Polygon2D.new()
	_bubble_tail.color = style.bg_color   # 말풍선 배경색과 동일
	_bubble_tail.polygon = PackedVector2Array([Vector2(0, -7), Vector2(0, 7), Vector2(-8, 0)])
	_bubble_panel.add_child(_bubble_tail)

	# 초기 상태: 숨김
	modulate.a = 0.0
	_reposition_widget("")   # 초기 위치 설정 (텍스트 없음)

# ─── 공개 API ─────────────────────────────────────────────────────────────

## 화자 바크. emotion: "attack"|"hurt"|"victory"|"defeat"
## 진행 중인 트윈/홀드 타이머를 kill하고 최신 우선 재시작.
func say(emotion: String, text: String) -> void:
	var tex: Texture2D = _emotion_to_texture(emotion)
	if tex == null or text.is_empty():
		return

	_portrait.texture = tex
	_bubble_label.text = text

	# 최신 우선: 진행 중 트윈·홀드 타이머 취소
	_kill_tween()
	_cancel_hold_timer()

	# 말풍선 크기 측정 → 위젯 배치
	_reposition_widget(text)

	# 강화 팝업 등 move_to_front된 UI보다 위에 그려지도록 매번 최상단으로 끌어올린다.
	# (루트·자식 전부 MOUSE_FILTER_IGNORE라 입력은 그대로 통과 — 시각 레이어만 상승)
	move_to_front()

	# 슬라이드-업 + 페이드-인
	_animate_in()

	# 홀드 후 슬라이드-다운 + 페이드-아웃
	var hold: float = clampf(HOLD_BASE + HOLD_PER_CHAR * float(text.length()), HOLD_BASE, HOLD_MAX)
	_hold_timer = get_tree().create_timer(hold)
	_hold_timer.timeout.connect(_animate_out, CONNECT_ONE_SHOT)

# ─── 내부 헬퍼 ──────────────────────────────────────────────────────────

func _emotion_to_texture(emotion: String) -> Texture2D:
	match emotion:
		"attack":  return _TEX_ATTACK
		"hurt":    return _TEX_HURT
		"victory": return _TEX_VICTORY
		"defeat":  return _TEX_DEFEAT
	return null

## 텍스트 길이에 맞춰 말풍선 크기를 계산하고 위젯 전체를 배치한다.
## 슬라이드 기준점: Y는 SPEAKER_BOTTOM(하단), X는 SPEAKER_LEFT(좌측).
func _reposition_widget(text: String) -> void:
	# 폰트로 직접 텍스트 크기 측정 (autowrap 상태의 get_minimum_size가
	# 최소폭을 한 글자 폭으로 잡아 말풍선이 쪼그라드는 버그 회피)
	var font: Font = _bubble_label.get_theme_font("font")
	var fsize: int = _bubble_label.get_theme_font_size("font_size")
	var max_text_w: float = BUBBLE_MAX_WIDTH - _BUBBLE_PAD_H * 2.0
	var measured: Vector2 = font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, max_text_w, fsize)
	var text_w: float = min(measured.x, max_text_w)
	var text_h: float = measured.y

	_bubble_label.text = text
	_bubble_label.custom_minimum_size = Vector2(text_w, text_h)
	_bubble_label.size     = Vector2(text_w, text_h)
	_bubble_label.position = Vector2(_BUBBLE_PAD_H, _BUBBLE_PAD_V)

	var panel_w: float = text_w + _BUBBLE_PAD_H * 2.0
	var panel_h: float = text_h + _BUBBLE_PAD_V * 2.0
	_bubble_panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_bubble_panel.size = Vector2(panel_w, panel_h)

	# 꼬리: 말풍선 좌변 세로 중앙
	if _bubble_tail != null:
		_bubble_tail.position = Vector2(0.0, panel_h * 0.5)

	# 초상 프레임과 말풍선 세로 중앙 정렬
	var total_h: float = max(_frame_h, panel_h)
	_frame.position        = Vector2(0.0, (total_h - _frame_h) * 0.5)
	_bubble_panel.position = Vector2(_frame_w + _PORTRAIT_BUBBLE_GAP, (total_h - panel_h) * 0.5)

	# 위젯 전체 크기
	size = Vector2(_frame_w + _PORTRAIT_BUBBLE_GAP + panel_w, total_h)

	# 위젯을 SPEAKER_LEFT / SPEAKER_BOTTOM 기준 배치 (슬라이드 복귀 위치)
	position = Vector2(SPEAKER_LEFT, SPEAKER_BOTTOM - total_h)

## 아래에서 위로 슬라이드-업 + 페이드-인
func _animate_in() -> void:
	if not is_inside_tree():
		return
	# 슬라이드 시작: 현재 Y + 18px 아래에서 시작
	var target_y: float = position.y
	position.y = target_y + 18.0
	modulate.a  = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", target_y, SLIDE_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, SLIDE_IN_DURATION * 0.7) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

## 아래로 슬라이드-다운 + 페이드-아웃
func _animate_out() -> void:
	if not is_inside_tree():
		return
	_kill_tween()
	var from_y: float = position.y
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", from_y + 18.0, SLIDE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, SLIDE_OUT_DURATION) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

## 홀드 타이머의 _animate_out 콜백을 해제한다.
## SceneTreeTimer에는 is_stopped()가 없으므로 시그널 연결 여부로 판정.
func _cancel_hold_timer() -> void:
	if _hold_timer != null:
		if _hold_timer.timeout.is_connected(_animate_out):
			_hold_timer.timeout.disconnect(_animate_out)
		_hold_timer = null

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
