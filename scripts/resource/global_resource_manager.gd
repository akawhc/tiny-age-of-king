extends Node

class_name GlobalResourceManager

# 单例实例
static var instance: GlobalResourceManager = null

# 资源数据
var resources = {
	"wood": 0,
	"gold": 0,
	"meat": 0
}

# 建筑成本配置
const BUILDING_COSTS = {
	"House": {
		"wood": 50,
		"gold": 30
	},
	"Tower": {
		"wood": 100,
		"gold": 80
	},
	"Castle": {
		"wood": 200,
		"gold": 150
	}
}

# 单位成本配置
const UNIT_COSTS = {
	"Worker": {
		"gold": 50,
		"meat": 1
	},
	"Knight": {
		"gold": 100,
		"meat": 2
	},
	"Archer": {
		"gold": 80,
		"meat": 1
	}
}

# 信号
signal resources_changed(resource_type, amount)
signal insufficient_resources(resource_type, required, current)

# 获取单例实例
static func get_instance() -> GlobalResourceManager:
	if instance == null:
		instance = GlobalResourceManager.new()

		# 确保添加到场景树中
		if Engine.is_editor_hint():
			return instance

		var scene_tree = Engine.get_main_loop()
		if scene_tree and scene_tree is SceneTree:
			scene_tree.root.call_deferred("add_child", instance)
			print("GlobalResourceManager 单例已添加到场景树")
	return instance

# 添加资源
func add_resource(type: String, amount: int) -> void:
	if resources.has(type):
		resources[type] += amount
		emit_signal("resources_changed", type, resources[type])
		print(type + " 增加了 " + str(amount) + "，当前数量：" + str(resources[type]))

# 消耗资源
func consume_resource(type: String, amount: int) -> bool:
	if not resources.has(type):
		return false

	if resources[type] >= amount:
		resources[type] -= amount
		emit_signal("resources_changed", type, resources[type])
		print(type + " 消耗了 " + str(amount) + "，当前数量：" + str(resources[type]))
		return true
	else:
		emit_signal("insufficient_resources", type, amount, resources[type])
		print(type + " 资源不足！需要: " + str(amount) + "，当前: " + str(resources[type]))
		return false

# 检查是否有足够的资源
func has_sufficient_resources(costs: Dictionary) -> bool:
	for resource_type in costs:
		if not resources.has(resource_type) or resources[resource_type] < costs[resource_type]:
			return false
	return true

# 尝试建造建筑
func try_build(building_type: String) -> bool:
	if not BUILDING_COSTS.has(building_type):
		print("未知的建筑类型：" + building_type)
		return false

	var costs = BUILDING_COSTS[building_type]
	if has_sufficient_resources(costs):
		for resource_type in costs:
			consume_resource(resource_type, costs[resource_type])
		print(building_type + " 建造成功！")
		return true
	else:
		print(building_type + " 资源不足，无法建造！")
		return false

# 尝试生产单位
func try_produce_unit(unit_type: String) -> bool:
	if not UNIT_COSTS.has(unit_type):
		print("未知的单位类型：" + unit_type)
		return false

	var costs = UNIT_COSTS[unit_type]
	if has_sufficient_resources(costs):
		for resource_type in costs:
			consume_resource(resource_type, costs[resource_type])
		print(unit_type + " 训练成功！")
		return true
	else:
		print(unit_type + " 资源不足，无法训练！")
		return false

# 获取资源数量
func get_resource_amount(type: String) -> int:
	return resources.get(type, 0)

# 获取所有资源数量
func get_all_resources() -> Dictionary:
	return resources.duplicate()