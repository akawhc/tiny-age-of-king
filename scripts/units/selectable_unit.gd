# file: selectable_unit.gd
# author: ponywu
# date: 2024-03-24
# description: RTS风格的可选择单位基础脚本

extends CharacterBody2D

# 导出变量
@export var move_speed: float = 100.0
@export var selection_indicator_color: Color = Color(0.2, 0.4, 0.8, 0.8)  # 蓝色
@export var selection_indicator_width: float = 2.0  # 轮廓线宽度

# 状态变量
var is_selected: bool = false
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var collision_shape: CollisionShape2D

func _ready() -> void:
	# 将单位添加到可选择单位组
	add_to_group("selectable_units")
	# 获取碰撞形状节点
	collision_shape = $CollisionShape2D

func _physics_process(_delta: float) -> void:
	# 只有被选中的单位才响应键盘输入
	if is_selected:
		var input_dir = Vector2.ZERO
		input_dir.x = Input.get_axis("ui_left", "ui_right")
		input_dir.y = Input.get_axis("ui_up", "ui_down")

		if input_dir != Vector2.ZERO:
			is_moving = false

			# 根据键盘输入设置速度
			input_dir = input_dir.normalized()
			velocity = input_dir * move_speed

			update_animation(input_dir)

			move_and_slide()
			return
		else:
			# 当没有键盘输入但之前有输入时，停止移动并播放待机动画
			if velocity != Vector2.ZERO and !is_moving:
				velocity = Vector2.ZERO
				play_idle_animation()

	# 处理目标点移动 (无键盘输入或未选中时)
	if is_moving:
		var direction = (target_position - global_position)  # 使用全局坐标计算方向
		var distance = direction.length()

		if distance > 5:  # 到达目标位置的阈值
			direction = direction.normalized()
			velocity = direction * move_speed
			# 使用 move_and_slide 移动
			var collision = move_and_slide()

			# 如果发生碰撞，可以选择绕开障碍物或停止移动
			# TODO：智能躲避物
			if collision:
				print(name, " 发生碰撞")

			# 更新动画状态
			update_animation(direction)
		else:
			is_moving = false
			velocity = Vector2.ZERO
			play_idle_animation()
	elif velocity == Vector2.ZERO and !is_moving:
		play_idle_animation()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func move_to(pos: Vector2) -> void:
	target_position = pos  # 使用全局坐标作为目标位置
	is_moving = true
	print(name, " 开始移动到位置：", pos)

func _draw() -> void:
	if is_selected and collision_shape:
		# 使用碰撞形状的位置作为选择指示器的中心，并向下偏移
		var center = collision_shape.position + Vector2(0, 20)  # 向下偏移更多，以适应精灵位置

		# 获取碰撞形状的半径（假设使用CircleShape2D）
		var radius = 25  # 默认值，增大一些以适应精灵大小
		if collision_shape.shape is CircleShape2D:
			radius = collision_shape.shape.radius * 1  # 将半径扩大1.5倍

		# 绘制椭圆形选择指示器
		var points = PackedVector2Array()
		var num_points = 32
		for i in range(num_points + 1):
			var angle = i * TAU / num_points
			var point = Vector2(
				cos(angle) * (radius + 3),
				sin(angle) * (radius + 5) * 0.32  # Y轴压缩为0.3倍，使椭圆更扁
			)
			points.push_back(center + point)

		# 绘制主要轮廓
		draw_polyline(points, selection_indicator_color, selection_indicator_width)

		# 绘制内部椭圆装饰
		points.clear()
		var inner_scale = 0.7  # 内部椭圆的缩放比例
		for i in range(num_points + 1):
			var angle = i * TAU / num_points
			var point = Vector2(
				cos(angle) * (radius + 6) * inner_scale,
				sin(angle) * (radius + 5) * 0.32 * inner_scale  # 保持与外部椭圆相同的扁平比例
			)
			points.push_back(center + point)

		draw_polyline(points, selection_indicator_color.darkened(0.3), 1.0)

# 虚函数，由具体的单位类型实现
func update_animation(_direction: Vector2) -> void:
	pass

# 虚函数，由具体的单位类型实现
func play_idle_animation() -> void:
	pass
