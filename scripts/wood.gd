extends Area2D

signal collected

# 木材相关常量
const WOOD_CONFIG = {
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
		position + Vector2(0, -WOOD_CONFIG.drop_animation.height),
		WOOD_CONFIG.drop_animation.up_time
	)
	tween.tween_property(
		self,
		"position",
		position,
		WOOD_CONFIG.drop_animation.down_time
	)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		emit_signal("collected")
		if body.has_method("collect_wood"):
			if body.name == "worker":  # 如果是工人，则等待工人收集
				# 先通知工人收集木材
				body.collect_wood(self)  # 传递木材实例给工人
			else:  # 其他角色（如骑士）则播放消失动画
				_play_collect_animation()

func _play_collect_animation() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"modulate",
		Color(1, 1, 1, 0),
		WOOD_CONFIG.collect_animation.fade_time
	)
	tween.tween_property(
		self,
		"scale",
		WOOD_CONFIG.collect_animation.scale_target,
		WOOD_CONFIG.collect_animation.fade_time
	)
	await tween.finished
	queue_free()

# 被工人收集时调用此方法
func collected_by_worker() -> void:
	queue_free()  # 直接删除木材实例
