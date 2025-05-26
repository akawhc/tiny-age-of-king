extends AnimatedSprite2D

# signal tree_chopped(position)

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
		"time": 00.0,  # 重生时间（秒）
		"grow_duration": 0.5,  # 生长动画持续时间
		"start_scale": Vector2(0.5, 0.5),  # 开始大小
		"end_scale": Vector2(1.0, 1.0),  # 最终大小
		"check_radius": 40  # 重生时检查范围
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
@onready var wood_scene = preload("res://scenes/resources/wood.tscn")

func _ready() -> void:
	add_to_group("trees")
	current_health = max_health
	original_scale = scale
	play(TREE_ANIMATIONS.DEFAULT)

	# 连接信号
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

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

	print("树木被砍倒")

	# 禁用碰撞体积
	if collision_body:
		collision_body.set_collision_layer_value(1, false)  # 禁用碰撞层
		collision_body.set_collision_mask_value(1, false)   # 禁用碰撞掩码

	# emit_signal("tree_chopped", global_position)

	# 启动重生计时器
	# await get_tree().create_timer(TREE_CONFIG.respawn.time).timeout
	# _respawn_tree()

func _respawn_tree() -> void:
	# 检查重生位置是否有角色
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = TREE_CONFIG.respawn.check_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 1  # 角色所在的碰撞层

	var results = space_state.intersect_shape(query)

	# 如果检测到角色，延迟重生
	for result in results:
		if result.collider.is_in_group("players"):
			print("检测到角色，延迟重生")
			await get_tree().create_timer(1.0).timeout  # 等待1秒后重试
			_respawn_tree()
			return

	# 重置状态
	is_stump = false
	current_health = max_health
	chop_cooldown = false

	# 启用碰撞体积
	if collision_body:
		collision_body.set_collision_layer_value(1, true)  # 启用碰撞层
		collision_body.set_collision_mask_value(1, true)   # 启用碰撞掩码

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
		get_tree().get_root().add_child(wood)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("workers"):
		is_being_chopped = true
		if body.has_method("set_nearest_tree"):
			body.set_nearest_tree(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("workers"):
		is_being_chopped = false
		if body.has_method("set_nearest_tree"):
			body.set_nearest_tree(null)
