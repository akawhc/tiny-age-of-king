extends Node

class_name GlobalResourceManager

static var instance: GlobalResourceManager = GlobalResourceManager.new()

static func get_instance() -> GlobalResourceManager:
	return instance

# 资源数据
var resources = {
	"wood": 1000,
	"gold": 1000,
	"meat": 1000,
	"population": {
		"current": 0,
		"max": 5
	}
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

# 建筑人口加成
const BUILDING_POPULATION = {
	"House": 5,   # 每个房屋增加5人口上限
	"Castle": 10  # 每个城堡增加10人口上限
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
signal population_changed(current, max)
signal resources_changed(resource_type, amount)
signal insufficient_resources(resource_type, required, current)

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

		# 如果是可以增加人口上限的建筑，增加人口上限
		if BUILDING_POPULATION.has(building_type):
			var population_increase = BUILDING_POPULATION[building_type]
			increase_max_population(population_increase)
			print("建造了" + building_type + "，增加了" + str(population_increase) + "人口上限")

		return true
	else:
		return false

# 增加人口上限
func increase_max_population(amount: int) -> void:
	resources["population"]["max"] += amount
	emit_signal("population_changed", resources["population"]["current"], resources["population"]["max"])
	print("人口上限增加了 " + str(amount) + "，当前人口：" + get_population_string())

# 增加当前人口
func increase_current_population(amount: int) -> bool:
	if resources["population"]["current"] + amount <= resources["population"]["max"]:
		resources["population"]["current"] += amount
		emit_signal("population_changed", resources["population"]["current"], resources["population"]["max"])
		print("当前人口增加了 " + str(amount) + "，当前人口：" + get_population_string())
		return true
	else:
		print("人口已达上限！当前人口：" + get_population_string())
		return false

# 减少当前人口
func decrease_current_population(amount: int) -> void:
	resources["population"]["current"] = max(0, resources["population"]["current"] - amount)
	emit_signal("population_changed", resources["population"]["current"], resources["population"]["max"])
	print("当前人口减少了 " + str(amount) + "，当前人口：" + get_population_string())

# 获取人口字符串表示（当前/最大）
func get_population_string() -> String:
	return str(resources["population"]["current"]) + "/" + str(resources["population"]["max"])

# 检查是否有足够的人口上限
func has_sufficient_population(amount: int) -> bool:
	return resources["population"]["current"] + amount <= resources["population"]["max"]

# 尝试生产单位
func try_produce_unit(unit_type: String) -> bool:
	if not UNIT_COSTS.has(unit_type):
		print("未知的单位类型：" + unit_type)
		return false

	# 检查人口上限
	if not has_sufficient_population(1):  # 每个单位消耗1人口
		print(unit_type + " 人口已达上限，无法训练！当前人口：" + get_population_string())
		return false

	var costs = UNIT_COSTS[unit_type]
	if has_sufficient_resources(costs):
		for resource_type in costs:
			consume_resource(resource_type, costs[resource_type])
		# 增加当前人口
		increase_current_population(1)
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
