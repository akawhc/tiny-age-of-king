extends CharacterBody2D

const speed = 150
@onready var animated_sprite_2d = $AnimatedSprite2D

# 该函数用于根据移动方向设置动画
func set_animation(direction):
	if direction.x > 0:
		animated_sprite_2d.flip_h = false
	elif direction.x < 0:
		animated_sprite_2d.flip_h = true

	if direction:
		animated_sprite_2d.play("run")
	else:
		animated_sprite_2d.play("idle")

func _physics_process(_delta: float) -> void:
	var direction = Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction:
		velocity = direction.normalized() * speed
	else:
		velocity = Vector2.ZERO

	set_animation(direction)
	move_and_slide()
