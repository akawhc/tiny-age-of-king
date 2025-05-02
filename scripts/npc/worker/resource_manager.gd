# @file: resource_manager.gd
# @brief: 管理工人的各类资源收集和携带基类
# @author: ponywu
# @date: 2025-04-19

class_name ResourceManager
extends Node

# 资源配置基类 - 子类将根据资源类型覆盖这些配置
var config = {
	"resource_name": "未知资源",  # 资源名称
	"scene_path": "",             # 资源场景路径
	"drop_offset": Vector2(90, 90),  # 丢弃资源的偏移距离
	"collect_animation": {
		"duration": 0.5  # 收集动画持续时间
	},
	"max_carry": 3,  # 工人最多可以携带的资源数量
	"animation": {
		"bob_height": 2.0,       # 上下浮动高度
		"bob_speed": 3.0,        # 上下浮动速度
		"inertia_amount": 5.0,   # 惯性偏移量
		"inertia_smoothing": 5.0 # 惯性平滑系数
	}
}

# 节点引用
var parent: Node2D                # 父节点（通常是工人）
var resource_container: Node2D    # 资源容器节点
var resource_sprites: Array = []  # 资源精灵数组

# 状态变量
var resource_count: int = 0       # 当前携带的资源数量
var is_carrying: bool = false     # 是否正在携带资源
var current_resource = null       # 当前正在收集的资源实例

# 动画变量
var animation_time: float = 0.0
var resource_offset: Vector2 = Vector2.ZERO

# 子类应该重写此方法以提供特定的配置
func prepare_config() -> void:
	pass  # 默认情况下使用基础配置

# 初始化资源管理器
func init(parent_node: Node2D, resource_cont: Node2D, resource_sprs: Array) -> void:
	# 设置配置
	prepare_config()

	# 设置引用
	parent = parent_node
	resource_container = resource_cont
	resource_sprites = resource_sprs

	# 初始化状态
	resource_count = 0
	is_carrying = false

	# 确保资源容器一开始是隐藏的
	if resource_container:
		resource_container.hide()

# 更新资源动画
func update_animation(delta: float, old_velocity: Vector2) -> void:
	animation_time += delta

	# 计算惯性效果（速度变化的反方向）
	var velocity_change = parent.velocity - old_velocity
	var target_offset = Vector2.ZERO

	if velocity_change.length() > 0.1:
		# 计算惯性方向（与速度变化相反）
		target_offset = -velocity_change.normalized() * config.animation.inertia_amount

	# 平滑过渡到目标偏移
	resource_offset = resource_offset.lerp(target_offset, delta * config.animation.inertia_smoothing)

	# 添加上下浮动效果（所有资源一起浮动）
	var bob_offset = sin(animation_time * config.animation.bob_speed) * config.animation.bob_height

	# 应用整体偏移到资源容器节点
	resource_container.position = Vector2(0, bob_offset) + resource_offset

	# 确保资源精灵可见性正确
	update_resource_sprites_visibility()

# 更新资源精灵的可见性
func update_resource_sprites_visibility() -> void:
	for i in range(resource_sprites.size()):
		if i < resource_sprites.size():
			resource_sprites[i].visible = i < resource_count

# 抛物线丢弃效果
func drop_resource() -> void:
	if not is_carrying or resource_count <= 0:
		return

	# 创建资源实例
	var resource_scene = load(config.scene_path)
	if not resource_scene:
		push_error("无法加载资源场景: " + config.scene_path)
		return

	var resource = resource_scene.instantiate()

	# 向前投掷并有一定弧度
	var drop_direction = parent.facing_direction

	# 增加一些垂直偏移，模拟抛物线效果
	var vertical_offset = -20  # 资源会先向上抛起一点
	var throw_offset = drop_direction * config.drop_offset

	# 加入少量随机性，不同资源落点略有不同
	var random_offset = Vector2(0, 0)
	resource.global_position = parent.global_position + throw_offset + Vector2(0, vertical_offset) + random_offset

	# 将资源添加到场景中
	get_tree().get_root().add_child(resource)

	# 更新状态
	resource_count -= 1
	is_carrying = resource_count > 0
	update_carrier_state()
	print("工人丢弃" + config.resource_name + "！剩余数量：", resource_count, "/", config.max_carry)

# 收集资源
func collect_resource(resource = null) -> void:
	# 如果已经达到最大携带数量，不能再收集
	if resource_count >= config.max_carry:
		print("工人已经携带了最大数量的" + config.resource_name + "！")
		return

	# 如果传入了资源实例，说明是从场景中收集的
	if resource != null:
		current_resource = resource

		# 创建收集动画
		var tween = create_tween()
		tween.tween_property(
			current_resource,
			"global_position",
			parent.global_position,
			config.collect_animation.duration
		)

		# 等待动画完成后处理资源
		await tween.finished

		# 资源被收集后消失
		if current_resource:
			current_resource.collected_by_worker()
			current_resource = null

			# 增加资源数量
			resource_count += 1
			is_carrying = true

			# 更新状态
			update_carrier_state()
			print("工人收集" + config.resource_name + "！剩余数量：", resource_count, "/", config.max_carry)

# 更新携带状态
func update_carrier_state() -> void:
	if is_carrying:
		resource_container.show()
		update_resource_sprites_visibility()
	else:
		resource_container.hide()