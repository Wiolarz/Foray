class_name Discount
extends Resource

enum discount_type_enum {
	SUBTRACT,
	DIVIDE,
	INCREASING_SUBTRACT
}

@export var wood_mult : int
@export var iron_mult : int
@export var ruby_mult : int

@export var type := discount_type_enum.SUBTRACT 

@export var value : int = 0

@export var counter : int = 0

func apply_discount(price: Goods) -> Goods:
	var wood_price : int = price.wood
	var iron_price : int = price.iron
	var ruby_price : int = price.ruby
	match type:
		discount_type_enum.SUBTRACT:
			wood_price = (price.wood - value * wood_mult)
			iron_price = (price.iron - value * iron_mult)
			ruby_price = (price.ruby - value * ruby_mult)
		discount_type_enum.DIVIDE:
			wood_price = price.wood / (1 + counter * wood_mult)
			iron_price = price.iron / (1 + counter * iron_mult)
			ruby_price = price.ruby / (1 + counter * ruby_mult)
		discount_type_enum.INCREASING_SUBTRACT:
			wood_price = (price.wood - value * counter * wood_mult)
			iron_price = (price.iron - value * counter * iron_mult)
			ruby_price = (price.ruby - value * counter * ruby_mult)
	return Goods.new(
		0 if price.wood == 0 else 1 if wood_price <= 0 else wood_price,
		0 if price.iron == 0 else 1 if iron_price <= 0 else iron_price,
		0 if price.ruby == 0 else 1 if ruby_price <= 0 else ruby_price
	)


func on_end_of_round() -> void:
	counter += 1


func on_purchase() -> void:
	counter = 0


func copy() -> Discount:
	var new_discount = Discount.new()
	new_discount.type = type
	new_discount.wood_mult = wood_mult
	new_discount.iron_mult = iron_mult
	new_discount.ruby_mult = ruby_mult
	new_discount.value = value
	new_discount.counter = 0
	return new_discount
