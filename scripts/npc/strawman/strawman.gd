# @file: strawman.gd
# @brief: 草人假人脚本，展示受伤反馈
# @author: ponywu

extends StaticBody2D

# 草人配置
const STRAWMAN_CONFIG = {
	"detection_radius": 64,  # 检测范围
	"damage_cooldown": 0.2,  # 受伤冷却时间
	"visual_feedback": {
		"damage_color": Color(1, 0.7, 0.7),  # 受伤颜色
		"normal_color": Color(1, 1, 1),  # 正常颜色
		"shake_offset": Vector2(5, 0),  # 晃动偏移
		"color_recovery_time": 0.2,  # 颜色恢复时间
		"shake_time": 0.1  # 晃动时间
	}
}

var is_hit: bool = false
var hit_cooldown: bool = false

func _ready() -> void:
	add_to_group("strawmen")

# 受到伤害函数
func take_damage(damage: int, knockback_direction: Vector2 = Vector2.ZERO, knockback_time: float = 0.0) -> void:
	if hit_cooldown:
		return

	print("草人受到攻击！伤害: ", damage)

	# 添加视觉反馈
	_play_damage_feedback()

	# 设置受击冷却时间
	hit_cooldown = true
	await get_tree().create_timer(STRAWMAN_CONFIG.damage_cooldown).timeout
	hit_cooldown = false

# 播放受伤视觉反馈
func _play_damage_feedback() -> void:
	# 颜色变化效果
	modulate = STRAWMAN_CONFIG.visual_feedback.damage_color
	var color_tween = create_tween()
	color_tween.tween_property(
		self,
		"modulate",
		STRAWMAN_CONFIG.visual_feedback.normal_color,
		STRAWMAN_CONFIG.visual_feedback.color_recovery_time
	)

	# 晃动效果
	var original_position = position
	var shake_tween = create_tween()
	shake_tween.tween_property(
		self,
		"position",
		position + STRAWMAN_CONFIG.visual_feedback.shake_offset,
		STRAWMAN_CONFIG.visual_feedback.shake_time
	)
	shake_tween.tween_property(
		self,
		"position",
		original_position,
		STRAWMAN_CONFIG.visual_feedback.shake_time
	)
