# @file: collectible_resource.gd
# @brief: 可收集资源的基类
# @author: ponywu
# @date: 2025-04-19

class_name CollectibleResource
extends Area2D

# 资源配置 - 子类应该覆盖这些常量
const DEFAULT_CONFIG = {
	"resource_name": "Resource", # 资源名称，用于日志和函数映射
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

# 当前资源配置
var config = DEFAULT_CONFIG

# 初始化
func _ready() -> void:
	# 准备配置 - 子类应在继承后设置自己的配置
	_prepare_config()

	# 播放掉落动画
	_play_drop_animation()

	# 连接信号
	body_entered.connect(_on_body_entered)

# 子类应覆盖此方法以设置自己的配置
func _prepare_config() -> void:
	# 默认实现使用默认配置
	config = DEFAULT_CONFIG

# 播放掉落动画
func _play_drop_animation() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"position",
		position + Vector2(0, -config.drop_animation.height),
		config.drop_animation.up_time
	)
	tween.tween_property(
		self,
		"position",
		position,
		config.drop_animation.down_time
	)

# 处理碰撞
func _on_body_entered(body: Node2D) -> void:
	# 构建收集方法名
	var collect_method = "collect_" + config.resource_name.to_lower()

	if body.is_in_group("workers") or body.is_in_group("players"):
		if body.has_method(collect_method):
			if body.name == "worker":  # 如果是工人，则等待工人收集
				# 先通知工人收集资源
				body.call(collect_method, self)  # 传递资源实例给工人
			else:  # 其他角色（如骑士）则播放消失动画
				_play_collect_animation()
		else:
			# 如果没有特定方法但在可收集组中，也播放动画
			_play_collect_animation()

# 播放收集动画
func _play_collect_animation() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"modulate",
		Color(1, 1, 1, 0),
		config.collect_animation.fade_time
	)
	tween.tween_property(
		self,
		"scale",
		config.collect_animation.scale_target,
		config.collect_animation.fade_time
	)
	await tween.finished
	queue_free()

# 被工人收集时调用此方法
func collected_by_worker() -> void:
	queue_free()  # 直接删除资源实例