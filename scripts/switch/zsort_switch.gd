# @file: zsort_switch.gd
# @brief: zsort切换器
# @author: ponywu
# @date: 2025-05-24

extends Node2D

# 定义z排序层宏
class_name ZSortSwitch

const ZSORT_DEFAULT = 0
const ZSORT_ABOVE = 1

# 发出的信号
signal zsort_switched(new_zsort)

# 高地区域和低地区域引用
@onready var high_zsort: Area2D = $high_zsort
@onready var low_zsort: Area2D = $low_zsort
@export var allowed_groups: Array[String] = ["soldiers", "goblin"]

func _ready() -> void:
	add_to_group("zsort_switches")
	# 连接信号
	if high_zsort:
		high_zsort.body_entered.connect(_on_high_zsort_body_entered)

	if low_zsort:
		low_zsort.body_entered.connect(_on_low_zsort_body_entered)

# 当物体进入高地区域时
func _on_high_zsort_body_entered(body: Node2D) -> void:
	# 检查进入的物体是否在允许的组中
	var is_allowed = false
	for group in allowed_groups:
		if body.is_in_group(group):
			is_allowed = true
			break

	if is_allowed:
		emit_signal("zsort_switched", ZSORT_ABOVE)

# 当物体进入低地区域时
func _on_low_zsort_body_entered(body: Node2D) -> void:
	var is_allowed = false
	for group in allowed_groups:
		if body.is_in_group(group):
			is_allowed = true
			break

	if is_allowed:
		emit_signal("zsort_switched", ZSORT_DEFAULT)
