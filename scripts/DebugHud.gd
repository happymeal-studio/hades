extends CanvasLayer
## 3단계 확인용 임시 체력 표시. 7단계에서 HUD를 만들면 지운다.

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	var player = get_tree().get_first_node_in_group("player")
	player.health_changed.connect(_on_health_changed)
	player.died.connect(func(): _label.text += "  (쓰러짐)")
	_on_health_changed(player.health, player.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	_label.text = "HP %d / %d" % [current, maximum]
