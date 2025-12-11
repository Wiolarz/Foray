extends Node


func smart_unit_purchase_test():
	print("smart_unit_purchase_test")

	var available_goods := Goods.new(20, 10, 6)

	var faction := Faction.new()
	faction.race = CFG.RACES_LIST[0]
	faction.goods = available_goods

	var city := City.new()
	city.faction = faction
	var army := Army.new()
	army.hero = Hero.new()

	var result = WS.smart_unit_purchases(city, army, available_goods)
	print(result.size())
	for purchase in result:
		print(purchase.data.unit_name)


func _ready() -> void:
	smart_unit_purchase_test()
