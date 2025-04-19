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
	_play_drop_animation()
	body_entered.connect(_on_body_entered)

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

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("workers"):
		# emit_signal("collected")
		if body.has_method("collect_gold"):
			if body.name == "worker":  # 如果是工人，则等待工人收集
				body.collect_gold(self)  # 传递金币实例给工人
			else:  # 其他角色（如骑士）则播放消失动画
				_play_collect_animation()

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
