# @file: wood_manager.gd
# @brief: 管理工人的木材收集和丢弃
# @author: ponywu
# @date: 2025-04-19

extends ResourceManager

# 木材相关常量
const WOOD_CONFIG = {
	"resource_name": "木材",
	"scene_path": "res://scenes/resources/wood.tscn",
	"drop_offset": Vector2(60, 60),
	"collect_animation": {
		"duration": 0.5
	},
	"max_carry": 3,
	"animation": {
		"bob_height": 2.0,
		"bob_speed": 3.0,
		"inertia_amount": 5.0,
		"inertia_smoothing": 5.0
	}
}

# 向后兼容的属性
var wood_count: int:
	get: return resource_count

# 重写prepare_config方法，设置木材特有的配置
func prepare_config() -> void:
	config = WOOD_CONFIG

# 初始化木材管理器 - 提供向后兼容性的函数签名
# 将旧格式转换为新格式调用
func init(parent_node: Node2D, wood_container: Node2D, sprite1 = null, sprite2 = null, sprite3 = null) -> void:
	var sprites = []

	# 兼容两种调用方式：单独的精灵参数或数组参数
	if sprite1 is Array:
		sprites = sprite1
	else:
		if sprite1: sprites.append(sprite1)
		if sprite2: sprites.append(sprite2)
		if sprite3: sprites.append(sprite3)

	super.init(parent_node, wood_container, sprites)

# 提供向后兼容的API
func drop_wood() -> void:
	drop_resource()

func collect_wood(wood = null) -> void:
	collect_resource(wood)