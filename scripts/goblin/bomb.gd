extends Area2D

enum BombState {
	FLYING,
	EXPLODING
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_state = BombState.FLYING
var velocity = Vector2.ZERO
var _gravity = 500
var damage = 20
var explosion_radius = 100
var target_position = Vector2.ZERO
var flight_height = 200.0  # 抛物线最高点的高度

func _ready():
	animated_sprite.play("fire")

func initialize(initial_position: Vector2, target_pos: Vector2, bomb_damage: float):
	position = initial_position
	target_position = target_pos
	damage = bomb_damage

	# 计算到达目标所需的初始速度
	calculate_initial_velocity()

func calculate_initial_velocity():
	var distance = target_position - position
	var flight_time = sqrt(2 * flight_height / _gravity) * 2  # 总飞行时间

	# 计算水平速度（匀速）
	velocity.x = distance.x / flight_time

	# 计算垂直初速度（达到指定高度）
	velocity.y = -sqrt(2 * _gravity * flight_height)

func _physics_process(delta):
	match current_state:
		BombState.FLYING:
			handle_flying_state(delta)
		BombState.EXPLODING:
			handle_exploding_state()

func handle_flying_state(delta):
	velocity.y += _gravity * delta
	position += velocity * delta

	# 检查是否到达目标位置附近或超过目标
	var reached_target = position.distance_to(target_position) < 10 or \
						position.x > target_position.x if velocity.x > 0 else position.x < target_position.x

	if reached_target:
		current_state = BombState.EXPLODING
		position = target_position  # 确保在目标位置爆炸
		animated_sprite.play("explode")

func handle_exploding_state():
	var total_frames = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
	# 在倒数第二帧触发伤害
	if animated_sprite.frame == total_frames - 2:
		explode_damage()

	# 动画播放完毕后销毁
	if not animated_sprite.is_playing():
		queue_free()

func explode_damage():
	# 获取爆炸范围内的所有对象
	var overlapping_areas = get_overlapping_areas()

	for area in overlapping_areas:
		if area.is_in_group("soldiers") or area.is_in_group("buildings"):
			# 计算伤害衰减
			var distance = position.distance_to(area.position)
			var damage_multiplier = 1.0 - (distance / explosion_radius)
			damage_multiplier = clamp(damage_multiplier, 0, 1)

			# 如果目标有 take_damage 方法，则造成伤害
			if area.has_method("take_damage"):
				area.take_damage(damage * damage_multiplier)
