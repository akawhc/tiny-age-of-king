# @file: animation_manager.gd
# @brief: 设置工人的动画状态
# @author: ponywu
# @date: 2025-03-22

extends Node

# 动画状态
const ANIMATION_STATES = {
	"IDLE": "idle",
	"RUN": "run",
	"IDLE_LIFT": "lift",  # 携带物品时的待机动画
	"RUN_LIFT": "lift_run",  # 携带物品时的跑步动画
	"CHOP": "chop",  # 砍树动画
	"HAMMER": "hammer",  # 挖矿动画
	"GOLD_LIFT": "gold_lift",  # 携带金块时的待机动画
	"GOLD_LIFT_RUN": "gold_lift_run"  # 携带金块时的跑步动画
}

# 组件变量
var animated_sprite: AnimatedSprite2D
var current_animation: String = ANIMATION_STATES.IDLE

# 初始化组件
func init(sprite: AnimatedSprite2D) -> void:
	animated_sprite = sprite
	current_animation = ANIMATION_STATES.IDLE
	animated_sprite.play(current_animation)
	print("动画管理器初始化完成")

# 设置动画状态，根据速度和是否携带物品
func set_animation_state(velocity: Vector2, is_carrying: bool = false, is_carrying_gold: bool = false) -> void:
	var new_animation: String

	if velocity == Vector2.ZERO:
		# 静止状态
		if is_carrying_gold:
			new_animation = ANIMATION_STATES.GOLD_LIFT
		elif is_carrying:
			new_animation = ANIMATION_STATES.IDLE_LIFT
		else:
			new_animation = ANIMATION_STATES.IDLE
	else:
		# 移动状态
		if is_carrying_gold:
			new_animation = ANIMATION_STATES.GOLD_LIFT_RUN
		elif is_carrying:
			new_animation = ANIMATION_STATES.RUN_LIFT
		else:
			new_animation = ANIMATION_STATES.RUN

	# 如果动画状态改变，播放新动画
	if new_animation != current_animation:
		current_animation = new_animation
		animated_sprite.play(current_animation)
