# @file: gold.gd
# @brief: 金币资源
# @author: ponywu
# @date: 2025-04-19

extends CollectibleResource

# signal collected

# 金币相关常量
const GOLD_CONFIG = {
	"resource_name": "gold",
	"drop_animation": {
		"height": 20,  # 掉落高度
		"up_time": 0.3,  # 上升时间
		"down_time": 0.2  # 下降时间
	},
	"collect_animation": {
		"fade_time": 0.2,  # 淡出时间
		"scale_target": Vector2(0.5, 0.5)  # 缩放目标
	}
}

func _ready() -> void:
	# 设置资源类型和数量
	resource_type = "gold"
	amount = 3  # 每个金币资源提供3单位

	super._ready()  # 调用父类的_ready方法
	add_to_group("resources")  # 将金币资源添加到resources组
	_play_drop_animation()
	# body_entered.connect(_on_body_entered)

func _play_drop_animation() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"position",
		position + Vector2(0, -GOLD_CONFIG.drop_animation.height),
		GOLD_CONFIG.drop_animation.up_time
	)
	tween.tween_property(
		self,
		"position",
		position,
		GOLD_CONFIG.drop_animation.down_time
	)

func _play_collect_animation() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"modulate",
		Color(1, 1, 1, 0),
		GOLD_CONFIG.collect_animation.fade_time
	)
	tween.tween_property(
		self,
		"scale",
		GOLD_CONFIG.collect_animation.scale_target,
		GOLD_CONFIG.collect_animation.fade_time
	)
	await tween.finished
	queue_free()

# 被工人收集时调用此方法
func collected_by_worker() -> void:
	queue_free()  # 直接删除金币实例

# 重写准备配置方法
func _prepare_config() -> void:
	config = GOLD_CONFIG
