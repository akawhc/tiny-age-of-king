# file: unit_selection_manager.gd
# author: ponywu
# date: 2024-03-24
# description: RTS风格的单位选择和移动管理器

extends Node2D

const GROUND_INDICATOR = preload("res://scenes/deco/ground_indicator.tscn")

var selected_units: Array = []
var is_moving = false

signal selection_type_changed(type: String)

func _ready() -> void:
	print("单位选择管理器初始化")

	# 将自己添加到选择管理器组
	add_to_group("selection_manager")

	# 创建选择框节点
	var selection_box = Node2D.new()
	selection_box.set_script(load("res://scripts/units/selection_box.gd"))
	add_child(selection_box)
	print("选择框节点已创建")

func _input(event: InputEvent) -> void:
	# 如果点击在 UI 元素上，不处理移动
	if event.is_action_pressed("mouse_right"):
		var workbench = get_tree().get_first_node_in_group("workbench")
		if workbench:
			var buttons_container = workbench.get_node("ActionButtons")
			if buttons_container and is_instance_valid(buttons_container):
				# 检查点击是否在按钮容器内
				var buttons_container_global_rect = Rect2(
					buttons_container.global_position,
					buttons_container.size * buttons_container.scale
				)

				if buttons_container_global_rect.has_point(get_global_mouse_position()):
					print("点击了UI元素，不处理移动")
					get_viewport().set_input_as_handled()
					return

		if not selected_units.is_empty():
			# 获取目标位置（转换为全局坐标）
			var target_pos = get_viewport().get_mouse_position()
			target_pos = get_viewport().get_canvas_transform().affine_inverse() * target_pos
			print("右键点击位置（全局坐标）：", target_pos, "，开始移动选中的单位")
			move_units_to(target_pos)
			# 显示移动指示器
			show_ground_indicator(target_pos)

# 更新选中的单位
func update_selection(units: Array) -> void:
	print("\n开始更新单位选择")
	print("当前选中的单位数量：", selected_units.size())

	# 更新选中的单位
	selected_units = units

	# 高亮新选中的单位
	for unit in selected_units:
		print("设置单位选中状态：", unit.name)
		unit.set_selected(true)

	# 发送选择类型变化信号
	if not selected_units.is_empty():
		if selected_units[0].is_in_group("workers"):
			print("发送工人选择类型变化信号")
			selection_type_changed.emit("WORKER", selected_units)
		else:
			print("发送空选择类型变化信号")
			selection_type_changed.emit("NONE", [])
	else:
		selection_type_changed.emit("NONE", [])

	print("选择更新完成，当前选中 ", selected_units.size(), " 个单位")

# 清除所有单位的选中状态
func clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			print("取消单位选中状态：", unit.name)
			unit.set_selected(false)
	selected_units.clear()
	selection_type_changed.emit("NONE", [])  # 发送清除选择信号

# 移动单位到目标位置
func move_units_to(target_pos: Vector2) -> void:
	# 检查是否有选中的单位
	if selected_units.is_empty():
		print("没有选中的单位，无法移动")
		return

	print("\n开始移动单位")
	print("选中的单位数量：", selected_units.size())

	# 计算单位的目标位置
	var unit_count = selected_units.size()
	var formation_width: int = int(ceil(sqrt(unit_count)))  # 确保formation_width是整数
	var spacing = 50  # 单位之间的间距

	print("编队宽度：", formation_width)

	for i in range(unit_count):
		var row = i * 1.0 / formation_width
		var col = i % formation_width
		var offset = Vector2(
			col * spacing - (formation_width - 1) * spacing / 2.0,
			row * spacing - (ceil(unit_count / float(formation_width)) - 1) * spacing / 2.0
		)
		var unit_target = target_pos + offset

		if is_instance_valid(selected_units[i]):
			print("移动单位 ", selected_units[i].name, " 到位置：", unit_target)
			selected_units[i].move_to(unit_target)

# 显示地面指示器
func show_ground_indicator(_position: Vector2) -> void:
	var indicator = GROUND_INDICATOR.instantiate()
	add_child(indicator)
	indicator.global_position = _position
