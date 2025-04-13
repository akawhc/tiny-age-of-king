# file: selection_box.gd
# author: ponywu
# date: 2024-03-24
# description: RTS风格的单位选择框系统

extends Node2D

var start_pos = Vector2.ZERO
var current_pos = Vector2.ZERO
var is_selecting = false
var selection_color = Color(0.2, 0.4, 0.8, 0.2)  # 半透明蓝色
var border_color = Color(0.2, 0.4, 0.8, 0.8)     # 不透明蓝色

func _ready() -> void:
	# 确保选择框总是显示在最上层
	z_index = 100
	print("选择框系统已初始化")

func _input(event: InputEvent) -> void:
	# 如果点击在 UI 元素上，不处理选择
	var workbench = get_tree().get_first_node_in_group("workbench")
	if workbench:
		var buttons_container = workbench.get_node("ActionButtons")
		if buttons_container:
			var local_pos = buttons_container.get_local_mouse_position()
			if buttons_container.get_rect().has_point(local_pos):
				print("点击了工作台按钮，不处理选择")
				return

	if event.is_action_pressed("select_unit"):
		start_pos = get_global_mouse_position()
		current_pos = start_pos
		is_selecting = true
		print("开始选择，起始位置：", start_pos)
		queue_redraw()
	elif event.is_action_released("select_unit"):
		# 如果没有开始选择，不处理释放事件
		if not is_selecting:
			return

		# 结束选择
		is_selecting = false
		print("结束选择，结束位置：", current_pos)
		# 发出选择完成信号
		emit_selection_box()
		queue_redraw()
	elif event is InputEventMouseMotion and is_selecting:
		current_pos = get_global_mouse_position()
		queue_redraw()

func _draw() -> void:
	if is_selecting:
		# 计算选择框的矩形
		var rect = get_selection_rect()
		# 转换为局部坐标
		rect.position = to_local(rect.position)
		# 绘制填充的半透明矩形
		draw_rect(rect, selection_color)
		# 绘制边框
		draw_rect(rect, border_color, false, 2.0)

func get_selection_rect() -> Rect2:
	# 计算选择框的矩形区域
	var top_left = Vector2(
		min(start_pos.x, current_pos.x),
		min(start_pos.y, current_pos.y)
	)
	var size = Vector2(
		abs(current_pos.x - start_pos.x),
		abs(current_pos.y - start_pos.y)
	)
	return Rect2(top_left, size)
func emit_selection_box() -> void:
	# 获取选择框内的所有单位
	var selection_rect = get_selection_rect()
	var units = get_tree().get_nodes_in_group("selectable_units")
	var selected_units = []

	print("检测到 ", units.size(), " 个可选择单位")

	for unit in units:
		if selection_rect.has_point(unit.global_position):
			selected_units.append(unit)
			print("单位 ", unit.name, " 在选择框内，位置：", unit.global_position)
		else:
			print("单位 ", unit.name, " 在选择框外，位置：", unit.global_position)

	print("选中了 ", selected_units.size(), " 个单位")

	# 通知单位选择管理器
	get_parent().update_selection(selected_units)