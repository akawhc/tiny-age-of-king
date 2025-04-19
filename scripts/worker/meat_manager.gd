# @file: meat_manager.gd
# @brief: 管理工人的肉类资源收集和携带
# @author: ponywu
# @date: 2025-04-19

extends ResourceManager

# 肉类相关常量
const MEAT_CONFIG = {
	"resource_name": "肉类",
	"scene_path": "res://scenes/resources/meat.tscn",
	"drop_offset": Vector2(50, 50),
	"collect_animation": {
		"duration": 0.6  # 收集动画稍慢一些
	},
	"max_carry": 2,  # 肉类较重，携带量更少
	"animation": {
		"bob_height": 2.5,
		"bob_speed": 2.5,
		"inertia_amount": 6.0,
		"inertia_smoothing": 4.0
	},
	"decay": {
		"enabled": true,
		"time": 60.0,  # 肉类在60秒后会腐烂
		"value_reduction": 0.5  # 腐烂后价值减半
	}
}

# 肉类状态
var is_fresh: bool = true
var decay_timer: float = 0.0

# 向后兼容的属性
var meat_count: int:
	get: return resource_count

# 重写prepare_config方法，设置肉类特有的配置
func prepare_config() -> void:
	config = MEAT_CONFIG

# 初始化肉类管理器
func init(parent_node: Node2D, meat_container: Node2D, meat_sprites: Array) -> void:
	super.init(parent_node, meat_container, meat_sprites)
	is_fresh = true
	decay_timer = 0.0

# 扩展_process方法处理腐烂计时
func _process(delta: float) -> void:
	if is_carrying and config.decay.enabled and is_fresh:
		decay_timer += delta
		if decay_timer >= config.decay.time:
			is_fresh = false
			# 更新腐烂后的视觉效果
			_update_meat_visual()
			print("工人携带的肉类已经腐烂！")

# 更新肉类视觉效果（新鲜/腐烂）
func _update_meat_visual() -> void:
	if not is_fresh:
		# 为腐烂的肉添加视觉效果（如变色）
		for sprite in resource_sprites:
			sprite.modulate = Color(0.7, 0.7, 0.7)  # 灰暗色调
	else:
		# 恢复新鲜肉的外观
		for sprite in resource_sprites:
			sprite.modulate = Color(1, 1, 1)  # 正常颜色

# 提供向后兼容API，使用基类的丢弃方法并保留腐烂状态传递功能
func drop_meat() -> void:
	if not is_carrying or resource_count <= 0:
		return

	# 记录当前腐烂状态
	var was_fresh = is_fresh

	# 调用基类的丢弃方法
	drop_resource()

	# 如果已经丢弃了肉类，且肉类是腐烂的，尝试设置资源的腐烂状态
	# 注：由于drop_resource会修改resource_count和is_carrying，需要在调用后立即检查
	var just_dropped = resource_count < config.max_carry
	if just_dropped and not was_fresh:
		# 寻找刚刚丢弃的肉类资源
		var dropped_resources = get_tree().get_nodes_in_group("resources")
		for resource in dropped_resources:
			if resource.scene_file_path == config.scene_path and resource.has_method("set_freshness"):
				# 只检查最近的一个资源
				resource.set_freshness(false)
				break

func collect_meat(meat = null) -> void:
	collect_resource(meat)
	is_fresh = true
	decay_timer = 0.0
	_update_meat_visual()

# 获取肉类的价值（考虑新鲜度）
func get_value() -> float:
	var base_value = 1.0
	if not is_fresh and config.decay.enabled:
		return base_value * config.decay.value_reduction
	return base_value
