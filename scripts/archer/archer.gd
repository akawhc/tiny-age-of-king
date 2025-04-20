# @file: archer.gd
# @brief: 弓箭手单位脚本
# @author: ponywu

extends "res://scripts/units/selectable_unit.gd"

# 弓箭手配置
const ARCHER_CONFIG = {
	"detection_radius": 200.0,  # 检测半径
	"attack_damage": 15,        # 攻击伤害
	"attack_cooldown": 2.0,     # 攻击冷却时间(秒)
	"arrow_speed": 300.0,       # 箭矢速度
}

# 弓箭手状态
enum ArcherState {
	IDLE,
	ATTACKING
}

# 当前状态 (基本移动状态由父类处理)
var current_state: ArcherState = ArcherState.IDLE

# 攻击相关
var target_enemy: Node2D = null
var attack_cooldown_timer: float = 0.0
var can_attack: bool = true

# 箭矢场景路径
var arrow_scene_path: String = "res://scenes/projectiles/arrow.tscn"

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var arrow_spawn_point: Marker2D = $ArrowSpawnPoint

func _ready() -> void:
	super._ready()

	# 设置移动速度（覆盖父类的默认值）
	move_speed = 75.0

	# 初始化检测区域
	var detection_shape = detection_area.get_node_or_null("CollisionShape2D")
	if detection_shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = ARCHER_CONFIG.detection_radius
		detection_shape.shape = circle_shape
	else:
		print("WARN: archer's DetectionArea has no CollisionShape2D child node")

	# 连接信号
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)

	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

	animated_sprite.play("idle")

func _process(delta: float) -> void:
	# 更新攻击冷却
	if !can_attack:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true

	# 处理攻击状态
	if current_state == ArcherState.ATTACKING:
		_process_attacking(delta)

# 覆盖父类的physics_process，添加自己的逻辑
func _physics_process(delta: float) -> void:
	# 调用父类方法处理移动
	super._physics_process(delta)

	# 在移动过程中如果发现敌人，优先攻击
	if is_moving and target_enemy and can_attack:
		is_moving = false
		velocity = Vector2.ZERO
		_change_state(ArcherState.ATTACKING)

# 处理攻击状态
func _process_attacking(delta: float) -> void:
	if !target_enemy or !is_instance_valid(target_enemy):
		target_enemy = null
		_change_state(ArcherState.IDLE)
		return

	# 面向敌人
	_face_target(target_enemy.global_position)

	# 如果可以攻击且没有在移动，发起攻击
	if can_attack and !is_moving:
		_play_shoot_animation()

# 改变当前弓箭手状态
func _change_state(new_state: ArcherState) -> void:
	if current_state == new_state:
		return

	current_state = new_state

	match new_state:
		ArcherState.IDLE:
			play_idle_animation()
		ArcherState.ATTACKING:
			pass # 攻击动画会在_play_shoot_animation中处理

# 检测区域有单位进入
func _on_detection_area_body_entered(body: Node2D) -> void:
	# 检查是否是敌人
	if body.is_in_group("enemies"):
		# 设置为目标敌人
		target_enemy = body

		# 如果可以攻击并且不在移动，切换到攻击状态
		if can_attack and !is_moving:
			_change_state(ArcherState.ATTACKING)

# 检测区域有单位离开
func _on_detection_area_body_exited(body: Node2D) -> void:
	# 如果离开的是当前目标敌人
	if body == target_enemy:
		target_enemy = null

		# 返回空闲状态
		if current_state == ArcherState.ATTACKING:
			_change_state(ArcherState.IDLE)

# 动画完成回调
func _on_animation_finished() -> void:
	var current_animation = animated_sprite.animation

	# 处理射击动画完成
	if current_animation.begins_with("shoot_"):
		_on_shoot_animation_finished()

		# 进入冷却
		can_attack = false
		attack_cooldown_timer = ARCHER_CONFIG.attack_cooldown

		# 射击后返回空闲状态
		_change_state(ArcherState.IDLE)

# 射击动画完成回调
func _on_shoot_animation_finished() -> void:
	# 检查是否有有效目标和箭矢生成点
	if !target_enemy or !arrow_spawn_point:
		return

	# 加载箭矢场景
	var arrow_scene = load(arrow_scene_path)
	if !arrow_scene:
		print("错误：无法加载箭矢场景，请检查路径：", arrow_scene_path)
		return

	# 实例化箭矢
	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)

	# 设置箭矢位置和方向
	arrow.global_position = arrow_spawn_point.global_position
	var direction = (target_enemy.global_position - arrow.global_position).normalized()

	# 初始化箭矢属性
	arrow.initialize(
		direction,
		ARCHER_CONFIG.attack_damage,
		ARCHER_CONFIG.arrow_speed,
		self
	)

	print("弓箭手发射了一支箭！")

# 播放射击动画
func _play_shoot_animation() -> void:
	if !target_enemy:
		return

	# 计算到目标的角度
	var angle = global_position.angle_to_point(target_enemy.global_position)
	# 将弧度转换为角度
	var degrees = rad_to_deg(angle)

	# 根据角度选择合适的射击动画
	var is_flipped = false
	var animation_name = ""

	if degrees >= -22.5 and degrees < 22.5:
		# 向右射击
		animation_name = "shoot_right_normal"
		is_flipped = false
	elif degrees >= 22.5 and degrees < 67.5:
		# 右下射击
		animation_name = "shoot_right_down"
		is_flipped = false
	elif degrees >= 67.5 and degrees < 112.5:
		# 向下射击
		animation_name = "shoot_down"
		is_flipped = false
	elif degrees >= 112.5 and degrees < 157.5:
		# 左下射击
		animation_name = "shoot_right_down"
		is_flipped = true
	elif degrees >= 157.5 or degrees < -157.5:
		# 向左射击
		animation_name = "shoot_right_normal"
		is_flipped = true
	elif degrees >= -157.5 and degrees < -112.5:
		# 左上射击
		animation_name = "shoot_right_up"
		is_flipped = true
	elif degrees >= -112.5 and degrees < -67.5:
		# 向上射击
		animation_name = "shoot_upwards"
		is_flipped = false
	elif degrees >= -67.5 and degrees < -22.5:
		# 右上射击
		animation_name = "shoot_right_up"
		is_flipped = false

	# 设置翻转和播放动画
	animated_sprite.flip_h = is_flipped
	_play_animation(animation_name)

# 面向目标
func _face_target(target_pos: Vector2) -> void:
	var direction = (target_pos - global_position).normalized()

	# 如果有明显的水平分量，根据水平方向设置翻转
	if abs(direction.x) > 0.1:
		animated_sprite.flip_h = direction.x < 0

# 播放动画的辅助函数
func _play_animation(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	else:
		print("警告: 动画 ", anim_name, " 不存在")

# 实现父类的虚函数：更新移动动画
func update_animation(direction: Vector2) -> void:
	# 播放run动画
	if animated_sprite.sprite_frames.has_animation("run"):
		animated_sprite.play("run")
	else:
		# 尝试使用walk动画作为后备
		if animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")

	# 设置水平方向
	if abs(direction.x) > 0.1:
		animated_sprite.flip_h = direction.x < 0

# 实现父类的虚函数：播放待机动画
func play_idle_animation() -> void:
	if animated_sprite:
		animated_sprite.play("idle")
