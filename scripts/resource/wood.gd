# @file: wood.gd
# @brief: 木材资源
# @author: ponywu
# @date: 2025-04-19

extends CollectibleResource

# signal collected

# 木材相关常量
const WOOD_CONFIG = {
	"resource_name": "wood",
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
	super._ready()  # 调用父类的_ready方法
	add_to_group("resources")  # 将木材资源添加到resources组
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
	if body.is_in_group("workers"):
		if body.has_method("collect_wood"):
			if body.name == "worker":  # 如果是工人，则等待工人收集
				# 先通知工人收集木材
				body.collect_wood(self)  # 传递木材实例给工人
	else:
		# 其他玩家就直接让木材消失
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

# 重写准备配置方法
func _prepare_config() -> void:
	config = WOOD_CONFIG
