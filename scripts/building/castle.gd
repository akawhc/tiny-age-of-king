# @file scripts/building/castle.gd
# @brief 城堡类，继承自Building类
# @author ponywu
# @date 2025-04-21

extends Building

const RESOURCE_DETECTION_RADIUS = 100  # 资源检测半径
const RESOURCE_COLLECT_INTERVAL = 1.0  # 资源收集间隔（秒）

var detection_area: Area2D
var collection_timer: Timer
var resource_manager: Node

func _ready() -> void:
	building_type = "Castle"
	max_health = 1000
	current_health = max_health

	add_to_group("castles")
	super._ready()

	# 初始化资源管理器引用
	resource_manager = GlobalResourceManager.get_instance()

	# 创建检测区域
	setup_detection_area()

	# 创建收集计时器
	setup_collection_timer()

func setup_detection_area() -> void:
	# 获取场景中的 DetectionArea 节点
	detection_area = $DetectionArea
	# 连接区域进入信号
	detection_area.area_entered.connect(_on_resource_entered)

func setup_collection_timer() -> void:
	collection_timer = Timer.new()
	collection_timer.wait_time = RESOURCE_COLLECT_INTERVAL
	collection_timer.one_shot = false
	add_child(collection_timer)

	collection_timer.timeout.connect(_on_collection_timer_timeout)
	collection_timer.start()

func _on_resource_entered(area: Area2D) -> void:
	# 检查是否是资源
	if area.is_in_group("resources"):
		collect_resource(area)

func _on_collection_timer_timeout() -> void:
	# 检查范围内的所有资源
	var areas = detection_area.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("resources"):
			collect_resource(area)

func collect_resource(resource_node: Node2D) -> void:
	# 获取资源类型和数量
	var resource_type = resource_node.resource_type
	var amount = resource_node.amount

	# 更新全局资源数量
	match resource_type:
		"wood":
			resource_manager.add_resource("wood", amount)
		"gold":
			resource_manager.add_resource("gold", amount)
		"meat":
			resource_manager.add_resource("meat", amount)

	# 销毁资源节点
	resource_node.queue_free()

# 重写摧毁纹理路径获取方法，如果有特定的城堡摧毁纹理
func get_destroy_texture_path() -> String:
	return "res://sprites/Tiny Swords/Factions/Knights/Buildings/Castle/Castle_Destroyed.png"
