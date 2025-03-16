extends CharacterBody2D

const speed = 100
var current_dir = "none"
var wood_count = 0  # 木材数量
var chop_damage = 20  # 每次砍树造成的伤害
var nearest_tree = null  # 最近的树

func _ready() -> void:
	add_to_group("players")
	$AnimatedSprite2D.play("front_idle")

func _physics_process(delta: float) -> void:
	player_movement(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("chop"):  # 需要在项目设置中添加"chop"动作
		if nearest_tree != null:
			nearest_tree.take_damage(chop_damage)
			# 播放砍树动画
			var current_anim = $AnimatedSprite2D.animation
			if "idle" in current_anim:
				$AnimatedSprite2D.play(current_anim.replace("idle", "walk"))
			await get_tree().create_timer(0.5).timeout
			if "walk" in $AnimatedSprite2D.animation:
				$AnimatedSprite2D.play($AnimatedSprite2D.animation.replace("walk", "idle"))

# 角色移动
func player_movement(_delta: float) -> void:
	if Input.is_action_pressed("ui_right"):
		velocity.x = speed
		velocity.y = 0
		current_dir = "right"
		play_animate(true)
	elif Input.is_action_pressed("ui_left"):
		velocity.x = -speed
		velocity.y = 0
		current_dir = "left"
		play_animate(true)
	elif Input.is_action_pressed("ui_down"):
		velocity.x = 0
		velocity.y = speed
		current_dir = "down"
		play_animate(true)
	elif Input.is_action_pressed("ui_up"):
		velocity.x = 0
		velocity.y = -speed
		current_dir = "up"
		play_animate(true)
	else:
		velocity.x = 0
		velocity.y = 0
		play_animate(false)

	move_and_slide()

# 根据是否运动以及是否运动方向播放 animate frame
func play_animate(moving: bool) -> void:
	var dir = current_dir
	var anim = $AnimatedSprite2D

	if dir == "right":
		anim.flip_h = false
		if moving:
			anim.play("side_walk")
		else:
			anim.play("side_idle")
	elif dir == "left":
		anim.flip_h = true
		if moving:
			anim.play("side_walk")
		else:
			anim.play("side_idle")
	elif dir == "down":
		if moving:
			anim.play("front_walk")
		else:
			anim.play("front_idle")
	elif dir == "up":
		if moving:
			anim.play("back_walk")
		else:
			anim.play("back_idle")

# 收集木材
func collect_wood() -> void:
	wood_count += 1
	# 这里可以更新UI显示木材数量
	print("收集到木材！当前数量：", wood_count)

# 设置最近的树
func set_nearest_tree(tree) -> void:
	nearest_tree = tree
