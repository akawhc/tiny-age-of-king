extends AnimatedSprite2D

signal tree_chopped(position)

# 树木相关常量
const TREE_CONFIG = {
	"detection_radius": 64,  # 检测范围
	"damage_cooldown": 0.2,  # 受伤冷却时间
	"wood_spawn": {
		"min_count": 2,  # 最小木材生成数量
		"max_count": 4,  # 最大木材生成数量
		"spread_range": 20  # 木材散布范围
	},
	"visual_feedback": {
		"damage_color": Color(1, 0.7, 0.7),  # 受伤颜色
		"normal_color": Color(1, 1, 1),  # 正常颜色
		"shake_offset": Vector2(5, 0),  # 晃动偏移
		"color_recovery_time": 0.2,  # 颜色恢复时间
		"shake_time": 0.1  # 晃动时间
	}
}

@export var max_health: int = 100
var current_health: int = max_health
var is_being_chopped: bool = false
var chop_cooldown: bool = false
var is_stump: bool = false  # 是否已经变成树桩

# 预加载木材资源场景
@onready var wood_scene = preload("res://scenes/wood.tscn")

func _ready() -> void:
	add_to_group("trees")
	current_health = max_health
	_setup_collision()
	print("树木初始化完成")  # 调试信息

func _setup_collision() -> void:
	# 设置碰撞区域
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = TREE_CONFIG.detection_radius
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	# 连接信号
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func take_damage(damage: int) -> void:
	if is_stump or chop_cooldown:  # 如果已经是树桩或在冷却中则不再受伤
		return

	current_health -= damage
	print("树木受到伤害：", damage, "，剩余生命：", current_health)

	# 播放砍树动画
	play("chop")

	# 添加视觉反馈
	_play_damage_feedback()

	if current_health <= 0:
		_on_tree_destroyed()

	# 设置砍树冷却时间
	chop_cooldown = true
	await get_tree().create_timer(TREE_CONFIG.damage_cooldown).timeout
	chop_cooldown = false
	if not is_stump:
		play("default")

func _play_damage_feedback() -> void:
	# 颜色变化效果
	modulate = TREE_CONFIG.visual_feedback.damage_color
	var color_tween = create_tween()
	color_tween.tween_property(
		self,
		"modulate",
		TREE_CONFIG.visual_feedback.normal_color,
		TREE_CONFIG.visual_feedback.color_recovery_time
	)

	# 晃动效果
	var original_position = position
	var shake_tween = create_tween()
	shake_tween.tween_property(
		self,
		"position",
		position + TREE_CONFIG.visual_feedback.shake_offset,
		TREE_CONFIG.visual_feedback.shake_time
	)
	shake_tween.tween_property(
		self,
		"position",
		original_position,
		TREE_CONFIG.visual_feedback.shake_time
	)

func _on_tree_destroyed() -> void:
	spawn_wood()
	is_stump = true
	play("stump")
	emit_signal("tree_chopped", global_position)

func spawn_wood() -> void:
	var wood_count = randi_range(
		TREE_CONFIG.wood_spawn.min_count,
		TREE_CONFIG.wood_spawn.max_count
	)

	for i in range(wood_count):
		var wood = wood_scene.instantiate()
		var offset = Vector2(
			randf_range(-TREE_CONFIG.wood_spawn.spread_range, TREE_CONFIG.wood_spawn.spread_range),
			randf_range(-TREE_CONFIG.wood_spawn.spread_range, TREE_CONFIG.wood_spawn.spread_range)
		)
		wood.global_position = global_position + offset
		get_parent().add_child(wood)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		is_being_chopped = true
		if body.has_method("set_nearest_tree"):
			body.set_nearest_tree(self)
			print("设置最近的树")  # 调试信息

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		is_being_chopped = false
		if body.has_method("set_nearest_tree"):
			body.set_nearest_tree(null)
			print("清除最近的树")  # 调试信息
