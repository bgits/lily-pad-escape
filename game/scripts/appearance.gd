class_name LilyAppearance
extends RefCounted

const DEFAULTS := {"character":0,"skin":1,"hair_style":0,"hair_color":0,"top_style":0,"top_color":0,"pants_style":0,"pants_color":0,"shoe_style":0,"shoe_color":0}
const OPTIONS := {
	"character":["Boy","Girl","Neutral"],
	"skin":["Porcelain","Warm","Golden","Honey","Chestnut","Deep"],
	"hair_style":["Short","Bob","Ponytail","Curls","Buzz","No hair"],
	"hair_color":["Brown","Blond","Black","Copper","Silver","Plum"],
	"top_style":["Hoodie","T-shirt","Jacket"],
	"top_color":["Sunshine","Coral","Sky","Moonflower","Mint","Ivory"],
	"pants_style":["Shorts","Jeans","Joggers"],
	"pants_color":["Navy","Denim","Olive","Charcoal","Sand","Plum"],
	"shoe_style":["Sneakers","Boots","High-tops"],
	"shoe_color":["Red","Cream","Navy","Plum","Sky","Moss"]
}
const COLORS := {
	"skin":["f5d7c1","edb88b","dca777","bc865c","8e5d43","593b32"],
	"hair_color":["593420","b0834b","251f26","aa543a","d9ccad","885599"],
	"top_color":["f3cc58","e58f76","91b4d2","b69add","83b8a3","fff2d3"],
	"pants_color":["243c51","547b9c","687e50","495256","b89770","755e84"],
	"shoe_color":["d65a42","fff2d3","243c51","8f74ad","74a9bb","7dad74"]
}

static func sanitize(raw: Variant, secret_unlocked: bool) -> Dictionary:
	var result := DEFAULTS.duplicate()
	if raw is Dictionary:
		for key: String in DEFAULTS:
			var value: Variant = raw.get(key,DEFAULTS[key])
			if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= 0 and value < OPTIONS[key].size():
				result[key] = int(value)
	if result.top_color == 3 and not secret_unlocked:
		result.top_color = 0
	return result

static func color_for(outfit: Dictionary, key: String) -> Color:
	return Color(COLORS[key][outfit[key]])
