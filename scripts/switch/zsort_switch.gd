# @file: zsort_switch.gd
# @brief: zsort切换器
# @author: ponywu
# @date: 2025-05-24

extends Node2D

# 定义z排序层宏
class_name ZSortSwitch

const ZSORT_DEFAULT = 1      # 默认层 (第1层)
const ZSORT_ABOVE = 2        # 高地区域 (第2层)

# 发出的信号
signal zsort_switched(new_zsort)

# 高地区域和低地区域引用
@onready var high_zsort: Area2D = $high_zsort
@onready var low_zsort: Area2D = $low_zsort

func _ready() -> void:
	add_to_group("zsort_switches")
	# 连接信号
	if high_zsort:
		high_zsort.body_entered.connect(_on_high_zsort_body_entered)

	if low_zsort:
		low_zsort.body_entered.connect(_on_low_zsort_body_entered)

# 当物体进入高地区域时
func _on_high_zsort_body_entered(body: Node2D) -> void:
	emit_signal("zsort_switched", ZSORT_ABOVE)

# 当物体进入低地区域时
func _on_low_zsort_body_entered(body: Node2D) -> void:
	emit_signal("zsort_switched", ZSORT_DEFAULT)
