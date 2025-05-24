# @file: bridge_mask_switch.gd
# @brief: 桥梁碰撞遮罩切换器
# @author: ponywu
# @date: 2025-05-24

extends Node2D

# 定义碰撞层宏
class_name BridgeMaskSwitch

const LAYER_DEFAULT = 1       # 默认层 (第1层)
const LAYER_BRIDGE = 2        # 桥梁层 (第2层)

# 发出的信号
signal enter_bridge(new_mask)
signal exit_bridge(new_mask)

# 可切换的碰撞层
@export var bodies_group: String = "soldiers"  # 限制哪些组可以触发切换

@onready var enter_area: Area2D = $enter_bridge
@onready var exit_area: Area2D = $exit_bridge

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 将切换器添加到组中，便于单位查找
	add_to_group("bridge_mask_switches")

	# 连接信号
	enter_area.body_entered.connect(_on_body_entered_bridge)
	exit_area.body_entered.connect(_on_body_exited_bridge)

# 当物体进入区域时触发
func _on_body_entered_bridge(body: Node2D) -> void:
	# 如果指定了特定的组，且物体不在该组中，则忽略
	if bodies_group != "" and !body.is_in_group(bodies_group):
		return

	emit_signal("enter_bridge", LAYER_BRIDGE)

# 当物体离开区域时触发
func _on_body_exited_bridge(body: Node2D) -> void:
	# 如果指定了特定的组，且物体不在该组中，则忽略
	if bodies_group != "" and !body.is_in_group(bodies_group):
		return

	# 发出切换回默认遮罩的信号
	emit_signal("exit_bridge", LAYER_DEFAULT)
