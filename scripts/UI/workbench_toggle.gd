# file: workbench_toggle.gd
# author: ponywu
# date: 2025-03-23
# description: 工作台切换脚本，按 B 键切换工作台的显示状态

extends Node

# 工作台场景路径
@export var workbench_scene: PackedScene

# 工作台实例
var workbench_instance = null
var is_workbench_visible = false

func _ready() -> void:
	# 预载工作台场景，如果未设置
	if not workbench_scene:
		workbench_scene = load("res://scenes/workbench.tscn")

	# 连接输入处理
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# 按下B键切换工作台显示状态
	if event.is_action_pressed("toggle_workbench"):
		toggle_workbench()

# 切换工作台显示状态
func toggle_workbench() -> void:
	if is_workbench_visible:
		hide_workbench()
	else:
		show_workbench()

# 显示工作台
func show_workbench() -> void:
	if workbench_instance == null:
		workbench_instance = workbench_scene.instantiate()
		add_child(workbench_instance)

	if workbench_instance.has_node("workbench"):
		var workbench = workbench_instance.get_node("workbench")
		if workbench.has_method("show_workbench"):
			workbench.show_workbench()

	is_workbench_visible = true
	print("显示工作台")

# 隐藏工作台
func hide_workbench() -> void:
	if workbench_instance and workbench_instance.has_node("workbench"):
		var workbench = workbench_instance.get_node("workbench")
		if workbench.has_method("hide_workbench"):
			workbench.hide_workbench()

	is_workbench_visible = false
	print("隐藏工作台")