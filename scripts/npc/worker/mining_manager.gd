# @file: mining_manager.gd
# @brief: 管理工人的挖矿动作
# @author: ponywu
# @date: 2025-03-22

extends Node

# 挖矿相关常量
const MINING_CONFIG = {
	"animation": "hammer",  # 挖矿使用锤子动作
	"damage": 20,
	"hit_frame": 5,  # 在第5帧检测伤害
	"efficiency": 1.0,  # 基础挖矿效率
	"arc_distance": 120.0,  # 攻击弧度距离
}

# 引用
var parent: Node2D
var animated_sprite: AnimatedSprite2D
var has_hit: bool = false
var mining_efficiency: float = 1.0

# 初始化
func init(parent_node: Node2D, sprite: AnimatedSprite2D) -> void:
	parent = parent_node
	animated_sprite = sprite
	has_hit = false
	mining_efficiency = MINING_CONFIG.efficiency

# 开始挖矿动作
func start_mine(facing_direction: Vector2, _nearest_mine) -> void:
	has_hit = false

	# 根据朝向设置动画翻转
	animated_sprite.flip_h = facing_direction.x < 0

	# 播放挖矿动画
	animated_sprite.play(MINING_CONFIG.animation)

# 动画帧变化时检查是否应该造成伤害
func check_frame_change(sprite: AnimatedSprite2D, nearest_mine) -> void:
	if not has_hit and sprite.animation == MINING_CONFIG.animation:
		var current_frame = sprite.frame
		if current_frame == MINING_CONFIG.hit_frame:
			check_mine_hit(nearest_mine)
			has_hit = true

# 动画完成时的处理
func finish_animation() -> void:
	has_hit = false

# 检查是否命中金矿
func check_mine_hit(nearest_mine) -> void:
	if not nearest_mine:
		print("无法挖矿：附近没有金矿")
		return

	if nearest_mine.is_depleted:
		print("无法挖矿：金矿已被挖空")
		return

	# 检查工人是否在金矿附近
	var distance_to_mine = parent.global_position.distance_to(nearest_mine.global_position)
	print("与金矿的距离: ", distance_to_mine, " 攻击范围: ", MINING_CONFIG.arc_distance)

	if distance_to_mine <= MINING_CONFIG.arc_distance:
		# 计算实际伤害（基础伤害 * 效率）
		var actual_damage = int(MINING_CONFIG.damage * mining_efficiency)

		# 对金矿造成伤害
		nearest_mine.take_damage(actual_damage)
		print("工人挖掘金矿！造成 ", actual_damage, " 点伤害")

		# 可以添加挖矿效果，比如粒子效果
		_play_mining_effect(nearest_mine)
	else:
		print("金矿太远了，无法挖掘！需要靠近些")

# 播放挖矿效果
func _play_mining_effect(_mine) -> void:
	# 这里可以添加粒子效果或其他视觉反馈
	# 例如显示伤害数字，或者金矿闪烁效果
	pass

# 设置挖矿效率
func set_efficiency(value: float) -> void:
	mining_efficiency = value
