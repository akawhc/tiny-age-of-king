# @file scripts/building/tower.gd
# @brief 塔类，继承自Building类
# @author ponywu
# @date 2025-04-21

extends Building

func _ready() -> void:
	building_type = "Tower"
	max_health = 500
	current_health = max_health

	super._ready()


# 重写摧毁纹理路径获取方法，如果有特定的塔摧毁纹理
func get_destroy_texture_path() -> String:
	return "res://sprites/Tiny Swords/Factions/Knights/Buildings/Tower/Tower_Destroyed.png"
