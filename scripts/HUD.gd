extends CanvasLayer
## 화면 UI: 체력 바, 스킬 쿨다운 3칸, 웨이브 표시, 웨이브 안내, 피격 비네트, 결과 화면.
## 플레이어·WaveManager의 신호만 듣는다. 결과 화면을 띄울 때만 WaveManager의 처치 수·경과 시간을 읽는다.

@export var wave_manager: Node
@export var announce_time := 1.5
@export var vignette_time := 0.2
## 쓰러진 뒤 / 마지막 적을 잡은 뒤 결과 화면이 뜨기까지
@export var defeat_delay := 1.0
@export var victory_delay := 0.6
@export var font_names := PackedStringArray(["Apple SD Gothic Neo", "Malgun Gothic", "Noto Sans CJK KR", "NanumGothic", "sans-serif"])

const SKILLS := [
	{"id": &"melee", "name": "근접", "key": "우클릭"},
	{"id": &"missile", "name": "미사일", "key": "Q"},
	{"id": &"teleport", "name": "순간이동", "key": "Space"},
]
const SLOT_SIZE := 76.0
const SLOT_GAP := 12.0
const MARGIN := 24.0

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float edge = smoothstep(0.8, 1.45, length((UV - 0.5) * 2.0));
	COLOR = vec4(0.85, 0.0, 0.0, edge * 0.6 * intensity);
}
"""

var _player: Node3D
var _root: Control
var _health_fill: ColorRect
var _health_label: Label
var _wave_label: Label
var _announce_label: Label
var _vignette: ColorRect
var _result: Control
var _result_title: Label
var _result_stats: Label
## 스킬 id → {overlay, time_label, name_label, left}
var _slots := {}
var _wave_number := 0
var _wave_count := 0
var _announce_tween: Tween
var _vignette_tween: Tween
var _result_shown := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_build()
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_on_player_died)
	_player.skill_used.connect(_on_skill_used)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.remaining_changed.connect(_on_remaining_changed)
	wave_manager.all_waves_cleared.connect(_on_all_waves_cleared)
	_set_health(_player.health, _player.max_health)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	for id in _slots:
		var slot: Dictionary = _slots[id]
		if slot.left <= 0.0:
			continue
		slot.left = maxf(slot.left - delta, 0.0)
		slot.overlay.visible = slot.left > 0.0
		slot.time_label.visible = slot.left > 0.0
		slot.name_label.visible = slot.left <= 0.0
		slot.time_label.text = "%.1f" % slot.left


# --- 신호 --------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	_set_health(current, maximum)
	_flash_vignette()


func _on_skill_used(skill: StringName, cooldown: float) -> void:
	if _slots.has(skill):
		_slots[skill].left = cooldown
		_slots[skill].name_label.visible = false


func _on_wave_started(wave_number: int, wave_count: int) -> void:
	_wave_number = wave_number
	_wave_count = wave_count
	_announce("웨이브 %d" % wave_number)


func _on_remaining_changed(remaining: int) -> void:
	_wave_label.text = "웨이브 %d / %d · 남은 적 %d" % [_wave_number, _wave_count, remaining]


func _on_player_died() -> void:
	await get_tree().create_timer(defeat_delay).timeout
	_show_result("쓰러졌다…")


func _on_all_waves_cleared() -> void:
	await get_tree().create_timer(victory_delay).timeout
	_show_result("승리!")


# --- 표시 --------------------------------------------------------------

func _set_health(current: float, maximum: float) -> void:
	_health_fill.set_anchor(SIDE_RIGHT, clampf(current / maximum, 0.0, 1.0), true)
	_health_label.text = "%d / %d" % [ceili(current), maximum]


func _flash_vignette() -> void:
	if _vignette_tween:
		_vignette_tween.kill()
	_vignette.material.set_shader_parameter("intensity", 1.0)
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(
		func(v: float): _vignette.material.set_shader_parameter("intensity", v), 1.0, 0.0, vignette_time)


func _announce(text: String) -> void:
	_announce_label.text = text
	_announce_label.modulate.a = 1.0
	_announce_label.visible = true
	if _announce_tween:
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(announce_time - 0.3)
	_announce_tween.tween_property(_announce_label, "modulate:a", 0.0, 0.3)
	_announce_tween.tween_callback(_announce_label.hide)


func _show_result(title: String) -> void:
	if _result_shown:
		return
	_result_shown = true
	var seconds := int(wave_manager.elapsed)
	_result_title.text = title
	_result_stats.text = "처치 %d · 시간 %d:%02d" % [wave_manager.kills, seconds / 60, seconds % 60]
	_result.visible = true


# --- 만들기 ------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette.material = ShaderMaterial.new()
	_vignette.material.shader = shader
	_root.add_child(_vignette)

	_build_health_bar()
	_build_skill_slots()

	_wave_label = _make_label("준비", 26)
	_wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_set_offsets(_wave_label, -300, 16, 300, 56)
	_root.add_child(_wave_label)

	_announce_label = _make_label("", 64)
	_announce_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_set_offsets(_announce_label, -300, -140, 300, -60)
	_announce_label.visible = false
	_root.add_child(_announce_label)

	_build_result()

	for control in _root.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_health_bar() -> void:
	var panel := _make_panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_set_offsets(panel, MARGIN, -MARGIN - 34, MARGIN + 300, -MARGIN)
	_root.add_child(panel)

	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.85, 0.15, 0.15)
	_health_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_offsets(_health_fill, 3, 3, -3, -3)
	panel.add_child(_health_fill)

	_health_label = _make_label("", 20)
	_health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_health_label)


func _build_skill_slots() -> void:
	var width := SKILLS.size() * SLOT_SIZE + (SKILLS.size() - 1) * SLOT_GAP
	for i in SKILLS.size():
		var skill: Dictionary = SKILLS[i]
		var slot := _make_panel()
		slot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		var left := -width * 0.5 + i * (SLOT_SIZE + SLOT_GAP)
		_set_offsets(slot, left, -MARGIN - SLOT_SIZE, left + SLOT_SIZE, -MARGIN)
		_root.add_child(slot)

		var name_label := _make_label(skill.name, 18)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_set_offsets(name_label, 0, 6, 0, -22)
		slot.add_child(name_label)

		var key_label := _make_label(skill.key, 13)
		key_label.modulate = Color(1, 1, 1, 0.7)
		key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_set_offsets(key_label, 0, SLOT_SIZE - 26, 0, -4)
		slot.add_child(key_label)

		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.65)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		slot.add_child(overlay)

		var time_label := _make_label("", 26)
		time_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		time_label.visible = false
		slot.add_child(time_label)

		_slots[skill.id] = {"overlay": overlay, "time_label": time_label, "name_label": name_label, "left": 0.0}


func _build_result() -> void:
	_result = ColorRect.new()
	_result.color = Color(0, 0, 0, 0.6)
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	_root.add_child(_result)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_set_offsets(box, -300, -110, 300, 110)
	box.add_theme_constant_override("separation", 14)
	_result.add_child(box)

	_result_title = _make_label("", 64)
	_result_stats = _make_label("", 26)
	var hint := _make_label("R 키로 다시 시작", 22)
	hint.modulate = Color(1, 1, 1, 0.8)
	box.add_child(_result_title)
	box.add_child(_result_stats)
	box.add_child(hint)


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = font_names
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	theme.set_constant("outline_size", "Label", 5)
	return theme


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel() -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(6)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _set_offsets(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom
