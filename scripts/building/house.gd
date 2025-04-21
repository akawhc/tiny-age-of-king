# @file scripts/building/house.gd
# @brief 房屋类，继承自Building类
# @author ponywu
# @date 2025-04-21

extends Building

func _ready() -> void:
	building_type = "House"
	max_health = 150  # 房屋有中等生命值
	current_health = max_health
	super._ready()  # 调用父类的_ready方法

	# 可以在这里添加房屋特有的属性和行为

# 重写摧毁纹理路径获取方法，如果有特定的房屋摧毁纹理
func get_destroy_texture_path() -> String:
	return "res://sprites/Tiny Swords/Factions/Knights/Buildings/House/House_Destroyed.png"