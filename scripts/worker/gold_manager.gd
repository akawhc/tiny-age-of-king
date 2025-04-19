# @file: gold_manager.gd
# @brief: 管理工人的金币收集和携带
# @author: ponywu
# @date: 2025-04-19

extends ResourceManager

# 金币相关常量
const GOLD_CONFIG = {
	"resource_name": "金币",
	"scene_path": "res://scenes/resources/gold.tscn",
	"drop_offset": Vector2(60, 60),
	"collect_animation": {
		"duration": 0.4  # 收集动画稍快一些
	},
	"max_carry": 5,  # 金币可以携带更多
	"animation": {
		"bob_height": 1.5,
		"bob_speed": 3.5,
		"inertia_amount": 4.0,
		"inertia_smoothing": 5.0
	}
}

# 向后兼容的属性
var gold_count: int:
	get: return resource_count

# 重写prepare_config方法，设置金币特有的配置
func prepare_config() -> void:
	config = GOLD_CONFIG

# 初始化金币管理器
func init(parent_node: Node2D, gold_container: Node2D, gold_sprites: Array) -> void:
	super.init(parent_node, gold_container, gold_sprites)

# 使用基类的丢弃方法
func drop_gold() -> void:
	drop_resource()

func collect_gold(gold = null) -> void:
	collect_resource(gold)

# 特定于金币的功能，例如存入银行或兑换其他资源
func deposit_to_bank() -> int:
	var amount = resource_count
	if amount > 0:
		resource_count = 0
		is_carrying = false
		update_carrier_state()
		print("工人将 " + str(amount) + " 枚金币存入银行！")
	return amount
