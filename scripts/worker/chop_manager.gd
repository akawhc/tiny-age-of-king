# @file: chop_manager.gd
# @brief: 管理工人的砍树动作
# @author: ponywu
# @date: 2025-03-22

extends Node

# 砍树相关常量
const CHOP_CONFIG = {
	"animation": "chop",
	"damage": 20,
	"hit_frame": 5,  # 在第5帧检测伤害
	"arc_angle": 60.0,  # 攻击弧度角度（度）
	"arc_distance": 70.0  # 攻击弧度距离
}

# 引用
var parent: Node2D
var animated_sprite: AnimatedSprite2D
var has_hit: bool = false

# 初始化
func init(parent_node: Node2D, sprite: AnimatedSprite2D) -> void:
	parent = parent_node
	animated_sprite = sprite
	has_hit = false

# 开始砍树动作
func start_chop(facing_direction: Vector2) -> void:
	has_hit = false

	# 根据朝向设置动画翻转
	animated_sprite.flip_h = facing_direction.x < 0

	# 播放砍树动画
	animated_sprite.play(CHOP_CONFIG.animation)

# 动画帧变化时检查是否应该造成伤害
func check_frame_change(sprite: AnimatedSprite2D) -> void:
	if not has_hit and sprite.animation == CHOP_CONFIG.animation:
		var current_frame = sprite.frame
		if current_frame == CHOP_CONFIG.hit_frame:
			check_tree_hit()
			has_hit = true

# 动画完成时的处理
func finish_animation() -> void:
	has_hit = false

# 检查是否命中树木
func check_tree_hit() -> void:
	# 使用弧形区域检测来判断是否砍到树
	var space_state = parent.get_world_2d().direct_space_state
	var attack_direction = Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT

	# 计算攻击弧度的参数
	var arc_angle_rad = deg_to_rad(CHOP_CONFIG.arc_angle)  # 将角度转换为弧度
	var arc_distance = CHOP_CONFIG.arc_distance
	var hit_trees = []

	# 在弧形区域内进行多次射线检测，模拟弧形区域
	var num_rays = 5  # 使用5条射线来模拟弧形
	var base_angle = attack_direction.angle()  # 基础角度
	var start_angle = base_angle - arc_angle_rad / 2
	var angle_step = arc_angle_rad / (num_rays - 1)

	for i in range(num_rays):
		var current_angle = start_angle + i * angle_step
		var ray_direction = Vector2(cos(current_angle), sin(current_angle))

		var query = PhysicsRayQueryParameters2D.create(
			parent.global_position,
			parent.global_position + ray_direction * arc_distance
		)
		query.collide_with_areas = true
		var result = space_state.intersect_ray(query)

		if result and "collider" in result:
			var collider = result.collider
			if collider.get_parent() is AnimatedSprite2D and collider.get_parent().is_in_group("trees"):
				# 避免重复添加同一棵树
				if not hit_trees.has(collider.get_parent()):
					hit_trees.append(collider.get_parent())

	# 对所有在弧形范围内的树造成伤害
	for tree in hit_trees:
		tree.take_damage(CHOP_CONFIG.damage)
		print("命中树木！造成", CHOP_CONFIG.damage, "点伤害")

	if hit_trees.is_empty():
		print("没有砍到树！")
