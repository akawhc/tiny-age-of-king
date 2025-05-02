# file: workbench_config.gd
# author: ponywu
# date: 2025-04-12
# description: 工作台通用配置

extends Resource
class_name WorkbenchConfig

# 布局配置
@export var layout: Dictionary = {
	"margin_left": 40,       # 距离屏幕左边的边距
	"margin_bottom": 0,     # 距离屏幕底部的边距
	"scale": Vector2(0.8, 0.8), # 工作台的缩放比例
	"default_visible": true,     # 默认是否可见
	"position_offset": Vector2(0, 0), # 工作台相对于屏幕左下角的偏移
}

# 按钮样式配置
@export var button_style: Dictionary = {
	"min_height": 50,
	"font_size": 24,
	"margin": {
		"left": 10,
		"right": 10,
		"top": 10,
		"bottom": 10
	}
}

# 按钮配置
@export var button_configs: Dictionary = {
	"NONE": [],
	"WORKER": [
		{"id": "build_house", "text": "建造房屋", "action": "build_house"},
		{"id": "build_tower", "text": "建造箭塔", "action": "build_tower"},
		{"id": "build_gate", "text": "建造城堡", "action": "build_castle"},
		{"id": "repair", "text": "修复", "action": "repair"},
	],
	"BUILDING": [
		{"id": "upgrade", "text": "升级", "action": "upgrade"},
		{"id": "demolish", "text": "拆除", "action": "demolish"},
		{"id": "produce", "text": "生产", "action": "produce"},
		{"id": "exit", "text": "退出", "action": "exit"}
	],
	"CASTLE": [
		{"id": "produce_worker", "text": "生产工人", "action": "produce_worker"},
		{"id": "produce_archer", "text": "生产射手", "action": "produce_archer"},
		{"id": "produce_knight", "text": "生产骑士", "action": "produce_knight"},
		{"id": "exit", "text": "退出", "action": "exit"}
	],
	"TREE": [
		{"id": "cut", "text": "派工人砍树", "action": "cut_tree"},
		{"id": "exit", "text": "退出", "action": "exit"}
	],
	"GOLD_MINE": [
		{"id": "mine", "text": "派工人采矿", "action": "mine_gold"},
		{"id": "build_mine", "text": "建造采矿场", "action": "build_mine"},
		{"id": "exit", "text": "退出", "action": "exit"}
	],
	"UNIT": [
		{"id": "move", "text": "移动", "action": "move"},
		{"id": "exit", "text": "退出", "action": "exit"}
	]
}

# 获取指定交互类型的按钮配置
func get_button_config(interaction_type: String) -> Array:
	return button_configs.get(interaction_type, [])

# 添加新的按钮配置
func add_button_config(interaction_type: String, config: Array) -> void:
	button_configs[interaction_type] = config
