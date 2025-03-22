# @file: wood_manager.gd
# @brief: 管理工人的木材收集和丢弃
# @author: ponywu
# @date: 2025-03-22

extends Node

# 木材相关常量
const WOOD_CONFIG = {
	"drop_offset": Vector2(60, 60),  # 丢弃木材的偏移距离
	"collect_animation": {
		"duration": 0.5  # 收集动画持续时间
	},
	"max_carry": 3,  # 工人最多可以携带的木材数量
	"animation": {
		"bob_height": 2.0,       # 上下浮动高度
		"bob_speed": 3.0,        # 上下浮动速度
		"inertia_amount": 5.0,   # 惯性偏移量
		"inertia_smoothing": 5.0 # 惯性平滑系数
	}
}

# 节点引用
var parent: Node2D
var carried_wood_sprite: Node2D
var wood_sprite_1: Sprite2D
var wood_sprite_2: Sprite2D
var wood_sprite_3: Sprite2D

# 状态变量
var wood_count: int = 0
var is_carrying: bool = false
var current_wood = null

# 动画变量
var animation_time: float = 0.0
var wood_offset: Vector2 = Vector2.ZERO

# 初始化木材管理器
func init(parent_node: Node2D, wood_sprite: Node2D, sprite1: Sprite2D, sprite2: Sprite2D, sprite3: Sprite2D) -> void:
	parent = parent_node
	carried_wood_sprite = wood_sprite
	wood_sprite_1 = sprite1
	wood_sprite_2 = sprite2
	wood_sprite_3 = sprite3

	# 初始化状态
	wood_count = 0
	is_carrying = false

	# 确保木材一开始是隐藏的
	if carried_wood_sprite:
		carried_wood_sprite.hide()

# 更新木材动画
func update_animation(delta: float, old_velocity: Vector2) -> void:
	animation_time += delta

	# 计算惯性效果（速度变化的反方向）
	var velocity_change = parent.velocity - old_velocity
	var target_offset = Vector2.ZERO

	if velocity_change.length() > 0.1:
		# 计算惯性方向（与速度变化相反）
		target_offset = -velocity_change.normalized() * WOOD_CONFIG.animation.inertia_amount

	# 平滑过渡到目标偏移
	wood_offset = wood_offset.lerp(target_offset, delta * WOOD_CONFIG.animation.inertia_smoothing)

	# 添加上下浮动效果（所有木材一起浮动）
	var bob_offset = sin(animation_time * WOOD_CONFIG.animation.bob_speed) * WOOD_CONFIG.animation.bob_height

	# 应用整体偏移到CarriedWood节点
	carried_wood_sprite.position = Vector2(0, bob_offset) + wood_offset

	# 确保木材可见性正确
	update_wood_sprites_visibility()

# 更新木材精灵的可见性
func update_wood_sprites_visibility() -> void:
	var wood_sprites = [wood_sprite_1, wood_sprite_2, wood_sprite_3]
	for i in range(wood_sprites.size()):
		if wood_sprites[i]:
			wood_sprites[i].visible = i < wood_count

# 丢弃木材
func drop_wood() -> void:
	if not is_carrying or wood_count <= 0:
		return

	# 创建木材实例
	var wood_scene = preload("res://scenes/wood.tscn")
	var wood = wood_scene.instantiate()

	# 根据朝向设置木材位置
	var drop_direction = Vector2.RIGHT if not parent.animated_sprite_2d.flip_h else Vector2.LEFT
	var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	wood.global_position = parent.global_position + drop_direction * WOOD_CONFIG.drop_offset + random_offset

	# 将木材添加到场景中
	parent.get_parent().add_child(wood)

	# 更新状态
	wood_count -= 1
	is_carrying = wood_count > 0
	update_carrier_state()
	print("工人丢弃木材！剩余数量：", wood_count, "/", WOOD_CONFIG.max_carry)

# 收集木材
func collect_wood(wood = null) -> void:
	# 如果已经达到最大携带数量，不能再收集
	if wood_count >= WOOD_CONFIG.max_carry:
		print("工人已经携带了最大数量的木材！")
		return

	# 如果传入了木材实例，说明是从场景中收集的
	if wood != null:
		current_wood = wood

		# 创建收集动画
		var tween = create_tween()
		tween.tween_property(
			current_wood,
			"global_position",
			parent.global_position,
			WOOD_CONFIG.collect_animation.duration
		)

		# 等待动画完成后处理木材
		await tween.finished

		# 木材被收集后消失
		if current_wood:
			current_wood.collected_by_worker()
			current_wood = null

			# 增加木材数量
			wood_count += 1
			is_carrying = true

			# 更新状态
			update_carrier_state()
			print("工人收集木材！剩余数量：", wood_count, "/", WOOD_CONFIG.max_carry)

# 更新携带状态
func update_carrier_state() -> void:
	if is_carrying:
		carried_wood_sprite.show()
		update_wood_sprites_visibility()
	else:
		carried_wood_sprite.hide()
