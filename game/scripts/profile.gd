class_name LilyProfile
extends RefCounted

const WEB_KEY := "lily-pad-escape.secret-perch.v1"
const OUTFIT_KEY := "lily-pad-escape.appearance.v1"
const FIREFLY_KEY := "lily-pad-escape.fireflies.v1"
var firefly_masks: Array[int] = [0,0,0]
var storage_path := "user://achievements.cfg"
var secret_perch := false
var outfit: Dictionary = LilyAppearance.DEFAULTS.duplicate()
var player_name := ""

func load_progress() -> void:
	secret_perch = false
	outfit = LilyAppearance.DEFAULTS.duplicate()
	player_name = ""
	firefly_masks = [0,0,0]
	if OS.has_feature("web"):
		secret_perch = bool(JavaScriptBridge.eval("(() => { try { return localStorage.getItem('%s') === '1'; } catch (_) { return false; } })()" % WEB_KEY))
		var raw: Variant = JavaScriptBridge.eval("(() => { try { return localStorage.getItem('%s') || '{}'; } catch (_) { return '{}'; } })()" % OUTFIT_KEY)
		if raw is String:
			var parser := JSON.new()
			if parser.parse(raw) == OK and parser.data is Dictionary:
				var parsed: Dictionary = parser.data
				outfit = LilyAppearance.sanitize(parsed.get("outfit",{}),secret_perch)
				player_name = clean_name(parsed.get("name",""))
		var fly_raw: Variant = JavaScriptBridge.eval("(() => { try { return localStorage.getItem('%s') || '[]'; } catch (_) { return '[]'; } })()" % FIREFLY_KEY)
		if fly_raw is String:
			var parser := JSON.new()
			if parser.parse(fly_raw) == OK:
				firefly_masks = sanitize_fireflies(parser.data)
	else:
		var config := ConfigFile.new()
		if config.load(storage_path) == OK:
			secret_perch = config.get_value("achievements","secret_perch",false) == true
			outfit = LilyAppearance.sanitize(config.get_value("customization","outfit",{}),secret_perch)
			player_name = clean_name(config.get_value("customization","name",""))
			firefly_masks = sanitize_fireflies(config.get_value("collection","fireflies",[]))

static func sanitize_fireflies(raw: Variant) -> Array[int]:
	var result: Array[int] = [0,0,0]
	if raw is Array:
		for i in mini(raw.size(),3):
			var value: Variant = raw[i]
			if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= 0 and value <= 7:
				result[i] = int(value)
	return result

func has_firefly(level: int, index: int) -> bool:
	return level >= 0 and level < 3 and index >= 0 and index < 3 and (firefly_masks[level] & (1 << index)) != 0

func firefly_count(level: int) -> int:
	var count := 0
	for i in 3:
		if has_firefly(level,i):
			count += 1
	return count

func collect_firefly(level: int, index: int) -> bool:
	if level < 0 or level >= 3 or index < 0 or index >= 3:
		return false
	firefly_masks[level] |= 1 << index
	if OS.has_feature("web"):
		var payload := JSON.stringify(JSON.stringify(firefly_masks))
		return bool(JavaScriptBridge.eval("(() => { try { localStorage.setItem('%s', %s); return true; } catch (_) { return false; } })()" % [FIREFLY_KEY,payload]))
	return save_native()

static func clean_name(value: Variant) -> String:
	return value.substr(0,18).replace("\n","").replace("\r","").strip_edges() if value is String else ""

func save_customization() -> bool:
	outfit = LilyAppearance.sanitize(outfit,secret_perch)
	player_name = clean_name(player_name)
	if OS.has_feature("web"):
		# Encode the complete JSON string as a JS string literal, including names.
		var payload := JSON.stringify(JSON.stringify({"outfit":outfit,"name":player_name}))
		return bool(JavaScriptBridge.eval("(() => { try { localStorage.setItem('%s', %s); return true; } catch (_) { return false; } })()" % [OUTFIT_KEY,payload]))
	return save_native()

func save_native() -> bool:
	var config := ConfigFile.new()
	config.set_value("achievements","secret_perch",secret_perch)
	config.set_value("customization","outfit",outfit)
	config.set_value("customization","name",player_name)
	config.set_value("collection","fireflies",firefly_masks)
	return config.save(storage_path) == OK

func unlock_secret() -> bool:
	secret_perch = true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(() => { try { localStorage.setItem('%s', '1'); return true; } catch (_) { return false; } })()" % WEB_KEY))
	return save_native()
