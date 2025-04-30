# @file scripts/building/building.gd
# @brief 建筑类，定义建筑的基本属性和行为
# @author ponywu
# @date 2025-04-21

extends StaticBody2D
class_name Building

# 建筑属性
@export var max_health: int = 100
@export var current_health: int = 100
@export var building_type: String = ""

# 建筑状态
var is_destroyed: bool = false

# 摧毁动画相关
var destroy_sprite: Sprite2D
var normal_sprite: Sprite2D

# 血量条相关
var health_bar: ProgressBar
var show_health_bar_timer: Timer
var mouse_hovering: bool = false

# 信号
signal health_changed(current_health, max_health)
signal building_destroyed(building_type, position)

func _ready() -> void:
	add_to_group("buildings")

	# 获取正常状态的精灵节点
	normal_sprite = $Sprite2D

	# 获取血量条
	health_bar = $HealthBar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false

		# 确保血条在顶层显示，不被建筑遮挡
		health_bar.z_index = 10

		# 调整血条位置到建筑顶部，避免被遮挡
		var sprite_height = normal_sprite.texture.get_height() * normal_sprite.scale.y
		var y_offset = -sprite_height / 2 - 15  # 额外偏移，确保血条在建筑上方
		health_bar.position.y = min(health_bar.position.y, y_offset)

	# 创建计时器用于隐藏血量条
	setup_health_bar_timer()

	# 创建摧毁状态的精灵节点，但初始时不可见
	setup_destroy_sprite()

	# 启用鼠标输入
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# 当鼠标进入建筑区域
func _on_mouse_entered() -> void:
	mouse_hovering = true
	if not is_destroyed:
		update_health_bar()

# 当鼠标离开建筑区域
func _on_mouse_exited() -> void:
	mouse_hovering = false
	if not show_health_bar_timer.is_stopped():
		# 保持计时器继续运行，不做处理
		pass
	else:
		# 如果没有其他原因显示血条，则隐藏
		hide_health_bar()

# 设置血量条计时器
func setup_health_bar_timer() -> void:
	show_health_bar_timer = Timer.new()
	show_health_bar_timer.wait_time = 3.0  # 3秒后隐藏血量条
	show_health_bar_timer.one_shot = true
	show_health_bar_timer.timeout.connect(_on_show_health_bar_timeout)
	add_child(show_health_bar_timer)

# 当显示血条计时器超时
func _on_show_health_bar_timeout() -> void:
	# 如果鼠标仍然悬停在建筑上，则保持血条显示
	if not mouse_hovering:
		hide_health_bar()

# 设置摧毁状态的精灵
func setup_destroy_sprite() -> void:
	destroy_sprite = Sprite2D.new()
	destroy_sprite.name = "DestroySprite"
	destroy_sprite.visible = false
	destroy_sprite.z_index = normal_sprite.z_index

	# 加载摧毁状态的纹理
	var texture_path = get_destroy_texture_path()
	if ResourceLoader.exists(texture_path):
		destroy_sprite.texture = load(texture_path)
	else:
		# 如果没有摧毁纹理，就使用正常纹理但添加黑色着色
		destroy_sprite.texture = normal_sprite.texture
		destroy_sprite.modulate = Color(0.3, 0.3, 0.3)

	# 添加到场景树
	add_child(destroy_sprite)

	# 确保位置与正常精灵一致
	destroy_sprite.position = normal_sprite.position

# 获取摧毁状态的纹理路径，子类可以重写此方法
func get_destroy_texture_path() -> String:
	# 默认情况下尝试在同一目录加载 Destroyed 变体
	var path_parts = normal_sprite.texture.resource_path.split(".png")
	return path_parts[0] + "_Destroyed.png"

# 接收伤害
func take_damage(damage_amount: int) -> void:
	if is_destroyed:
		return

	current_health -= damage_amount

	# 确保生命值不会小于0
	current_health = max(0, current_health)

	# 更新血量条并显示
	update_health_bar()

	# 发出生命值变化信号
	health_changed.emit(current_health, max_health)

	# 检查是否摧毁
	if current_health <= 0:
		destroy()

# 更新血量条显示
func update_health_bar() -> void:
	if not health_bar or is_destroyed:
		return

	health_bar.value = current_health
	health_bar.visible = true

	# 重置计时器，3秒后检查是否隐藏血量条
	show_health_bar_timer.start()

# 隐藏血量条
func hide_health_bar() -> void:
	if health_bar:
		health_bar.visible = false

# 血量变化信号回调
func _on_health_changed(_current_health, _max_health) -> void:
	update_health_bar()

# 治疗/修复建筑
func heal(amount: int) -> void:
	if is_destroyed:
		return

	current_health += amount

	# 确保生命值不会超过最大值
	current_health = min(current_health, max_health)

	# 更新血量条并显示
	update_health_bar()

	# 发出生命值变化信号
	health_changed.emit(current_health, max_health)

# 摧毁建筑
func destroy() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	current_health = 0

	# 更新血量条
	if health_bar:
		health_bar.value = 0
		health_bar.visible = false

	# 切换到摧毁状态的精灵
	normal_sprite.visible = false
	destroy_sprite.visible = true

	# 发出建筑被摧毁的信号
	building_destroyed.emit(building_type, global_position)

	# 如果有碰撞形状，禁用它
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = true

# 重建建筑
func rebuild() -> void:
	if not is_destroyed:
		return

	is_destroyed = false
	current_health = max_health

	# 切换回正常状态的精灵
	normal_sprite.visible = true
	destroy_sprite.visible = false

	# 重新启用碰撞
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = false

	# 更新血量条
	update_health_bar()

	# 发出生命值变化信号
	health_changed.emit(current_health, max_health)