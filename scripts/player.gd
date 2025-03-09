extends CharacterBody2D


const speed = 100
var current_dir = "none"

func _physics_process(delta: float) -> void:
	player_movement(delta)

func _ready() -> void:
	$AnimatedSprite2D.play("front_idle")

# 角色移动
func player_movement(delta: float) -> void:	
	
	if Input.is_action_pressed("ui_right") :
		velocity.x = speed
		velocity.y = 0 
		current_dir = "right"
		play_animate(true)
	elif Input.is_action_pressed("ui_left") :
		velocity.x = -speed
		velocity.y = 0
		current_dir = "left"
		play_animate(true)
	elif Input.is_action_pressed("ui_down") :
		velocity.x = 0
		velocity.y = speed
		current_dir = "down"
		play_animate(true)
	elif Input.is_action_pressed("ui_up") :
		velocity.x = 0
		velocity.y = -speed
		current_dir = "up"
		play_animate(true)
	else : 
		velocity.x = 0 
		velocity.y = 0
		play_animate(false)
		
	move_and_slide()   

# 根据是否运动以及是否运动方向播放 animate frame
func play_animate(moving: bool) -> void:
	var dir = current_dir
	var anim = $AnimatedSprite2D
	
	if dir == "right" :
		anim.flip_h = false
		if moving: 
			anim.play("side_walk")
		else:
			anim.play("side_idle")
	elif dir == "left" :
		anim.flip_h = true 
		if moving: 
			anim.play("side_walk")
		else:
			anim.play("side_idle")
	elif dir == "down" :
		if moving: 
			anim.play("front_walk")
		else:
			anim.play("front_idle")
	elif dir == "up" :
		if moving: 
			anim.play("back_walk")
		else:
			anim.play("back_idle")
	
