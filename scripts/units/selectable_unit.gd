# file: selectable_unit.gd
# author: ponywu
# date: 2024-03-24
# description: RTS风格的可选择单位基础脚本

extends CharacterBody2D

# 导出变量
@export var move_speed: float = 100.0
@export var selection_indicator_color: Color = Color(0.2, 0.4, 0.8, 0.8)  # 蓝色
@export var selection_indicator_width: float = 2.0  # 轮廓线宽度
@export var health: int = 100  # 生命值

# 状态变量
var is_selected: bool = false
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var collision_shape: CollisionShape2D
var is_dead: bool = false  # 死亡状态

func _ready() -> void:
	# 将单位添加到可选择单位组
	add_to_group("selectable_units")
	# 获取碰撞形状节点
	collision_shape = $CollisionShape2D

func _physics_process(_delta: float) -> void:
	# 如果单位已死亡，不处理移动
	if is_dead:
		velocity = Vector2.ZERO
		return

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

		if distance > 10:  # 到达目标位置的阈值
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
	# 如果已死亡，不响应移动命令
	if is_dead:
		return

	target_position = pos  # 使用全局坐标作为目标位置
	is_moving = true

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

# 受到伤害
func take_damage(damage: int) -> void:
	health -= damage
	print(name, " 受到 ", damage, " 点伤害，剩余生命值：", health)

	if health <= 0:
		handle_death()
	else:
		# 受伤反馈
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		modulate = Color(1, 1, 1)

# 处理死亡
func handle_death() -> void:
	is_dead = true

	# 停止移动
	velocity = Vector2.ZERO
	is_moving = false

	# 禁用碰撞
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# 播放死亡动画或效果
	play_death_animation()

	# 从组中移除
	remove_from_group("selectable_units")
	if is_in_group("soldiers"):
		remove_from_group("soldiers")

	# 将单位回收到对象池，而不是直接销毁
	var unit_manager = UnitManager.get_instance()

	# 获取单位类型
	var unit_type = "Worker"  # 默认类型
	if is_in_group("knights"):
		unit_type = "Knight"
	elif is_in_group("archers"):
		unit_type = "Archer"

	# 回收到对象池
	unit_manager.recycle_unit(self, unit_type)

# 虚函数，由子类实现
func play_death_animation() -> void:
	# 默认实现，子类可重写
	modulate = Color(0.5, 0.5, 0.5, 0.7)  # 变灰表示死亡

# 虚函数，由具体的单位类型实现
func update_animation(_direction: Vector2) -> void:
	pass

# 虚函数，由具体的单位类型实现
func play_idle_animation() -> void:
	pass
