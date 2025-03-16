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
	},
	"respawn": {
		"time": 300.0,  # 重生时间（秒）
		"grow_duration": 0.5,  # 生长动画持续时间
		"start_scale": Vector2(0.5, 0.5),  # 开始大小
		"end_scale": Vector2(1.0, 1.0)  # 最终大小
	}
}

# 动画状态常量
const TREE_ANIMATIONS = {
	"DEFAULT": "default",  # 正常状态
	"CHOP": "chop",       # 被砍状态
	"STUMP": "stump"      # 树桩状态
}

@export var max_health: int = 100
var current_health: int = max_health
var is_being_chopped: bool = false
var chop_cooldown: bool = false
var is_stump: bool = false  # 是否已经变成树桩
var original_scale: Vector2  # 保存原始缩放值

# 节点引用
@onready var detection_area: Area2D = $DetectionArea
@onready var collision_body: StaticBody2D = $CollisionBody
# 预加载木材资源场景
@onready var wood_scene = preload("res://scenes/wood.tscn")

func _ready() -> void:
	add_to_group("trees")
	current_health = max_health
	original_scale = scale
	play(TREE_ANIMATIONS.DEFAULT)

	# 连接信号
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

	print("树木初始化完成")

func take_damage(damage: int) -> void:
	if is_stump or chop_cooldown:
		return

	current_health -= damage
	print("树木受到伤害：", damage, "，剩余生命：", current_health)

	# 播放砍树动画
	play(TREE_ANIMATIONS.CHOP)

	# 添加视觉反馈
	_play_damage_feedback()

	if current_health <= 0:
		_on_tree_destroyed()

	# 设置砍树冷却时间
	chop_cooldown = true
	await get_tree().create_timer(TREE_CONFIG.damage_cooldown).timeout
	chop_cooldown = false
	if not is_stump:
		play(TREE_ANIMATIONS.DEFAULT)

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
	play(TREE_ANIMATIONS.STUMP)
	emit_signal("tree_chopped", global_position)

	# 启动重生计时器
	await get_tree().create_timer(TREE_CONFIG.respawn.time).timeout
	_respawn_tree()

func _respawn_tree() -> void:
	# 重置状态
	is_stump = false
	current_health = max_health
	chop_cooldown = false

	# 设置初始状态
	scale = original_scale * TREE_CONFIG.respawn.start_scale
	play(TREE_ANIMATIONS.DEFAULT)

	# 创建生长动画
	var grow_tween = create_tween()
	grow_tween.tween_property(
		self,
		"scale",
		original_scale * TREE_CONFIG.respawn.end_scale,
		TREE_CONFIG.respawn.grow_duration
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	print("树木重生完成")  # 调试信息

func spawn_wood() -> void:
	var wood_count = randi_range(
		TREE_CONFIG.wood_spawn.min_count,
		TREE_CONFIG.wood_spawn.max_count
	)

	for i in range(wood_count):
		var wood = wood_scene.instantiate()
		var spawn_offset = Vector2(
			randf_range(-TREE_CONFIG.wood_spawn.spread_range, TREE_CONFIG.wood_spawn.spread_range),
			randf_range(-TREE_CONFIG.wood_spawn.spread_range, TREE_CONFIG.wood_spawn.spread_range)
		)
		wood.global_position = global_position + spawn_offset
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
