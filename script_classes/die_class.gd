extends Area2D
class_name Dice

@onready var gm : Node = get_tree().current_scene.get_node("game_manager")
var target_lines : Array[Line2D]
var current_target_line : int
var dc : Dictionary
var is_setup : bool = false
signal die(dice)

@export_category("Die Faces")
@export_enum("block_1", "block_2", "block_3", "damage_1", "damage_2", "damage_3", "duplicate", "heal_1", "heal_2", "heal_3", "nullify", "reroll", "ursa_major") var face_1 : String
@export_enum("block_1", "block_2", "block_3", "damage_1", "damage_2", "damage_3", "duplicate", "heal_1", "heal_2", "heal_3", "nullify", "reroll", "ursa_major") var face_2 : String
@export_enum("block_1", "block_2", "block_3", "damage_1", "damage_2", "damage_3", "duplicate", "heal_1", "heal_2", "heal_3", "nullify", "reroll", "ursa_major") var face_3 : String
@export_enum("block_1", "block_2", "block_3", "damage_1", "damage_2", "damage_3", "duplicate", "heal_1", "heal_2", "heal_3", "nullify", "reroll", "ursa_major") var face_4 : String
@export_enum("block_1", "block_2", "block_3", "damage_1", "damage_2", "damage_3", "duplicate", "heal_1", "heal_2", "heal_3", "nullify", "reroll", "ursa_major") var face_5 : String
@export_enum("block_1", "block_2", "block_3", "damage_1", "damage_2", "damage_3", "duplicate", "heal_1", "heal_2", "heal_3", "nullify", "reroll", "ursa_major") var face_6 : String
var base_faces : Array[String] = [face_1, face_2, face_3, face_4, face_5, face_6]
var current_faces : Array[String] = [face_1, face_2, face_3, face_4, face_5, face_6]
var face_i : int : # Index of the current visible die face
	set(value):
		face_i = clampi(value, 0, 5)
		$die_face.texture = face_textures[face_i]

var face_textures : Array[CompressedTexture2D] # Array of the die face textures
var interactable : bool = false # Determines whether or not the player can interact with the die
var max_ability_count : int
var ability_count : int = 1 :
	set(value):
		ability_count = value
		if ability_count == 0:
			$die_bg.modulate.a = 0.75
		else:
			$die_bg.modulate.a = 1.0
var inactive : bool = false :
	set(value):
		inactive = value
		if inactive:
			$inactive.show()
			for target in targets:
				target.inactive = false
		else:
			$inactive.hide()
var selecting_face : bool = false :
	set(value):
		selecting_face = value
		if selecting_face:
			$die_faces.show()
			$selection_area.show()
		else:
			$die_faces.hide()
			$selection_area.hide()
var hovered_face : Area2D
var duplicating : bool = false:
	set(value):
		duplicating = value
		if duplicating:
			$duplication.show()
			for target in targets:
				target.targetter = null
			targets.clear()
			set_ability_count()
		else:
			$duplication.hide()
			current_faces.set(face_i, base_faces[face_i])
			$die_face.texture = face_textures[face_i]
			for target in targets:
				target.inactive = false
				target.targetter = null
			targets.clear()
			set_ability_count()

var targets : Array[Area2D]
var targetter : Area2D

func _ready() -> void:
	# Set player dice to blue and enemy dice to red.
	if is_in_group("player_die"):
		base_faces = [face_1, face_2, face_3, face_4, face_5, face_6]
		current_faces = [face_1, face_2, face_3, face_4, face_5, face_6]
		load_faces()
		$die_bg.modulate = Color(0, 1, 1, 1)
		for face in $die_faces.get_children():
			face.modulate = Color(0, 1, 1, 1)
		is_setup = true
		roll()
	elif is_in_group("enemy_die"):
		print("THIS IS AN ENEMY")
		$die_bg.modulate = Color(1, 0, 0, 1)
		for face in $die_faces.get_children():
			face.modulate = Color(1, 0, 0, 1)
		connect("die", Callable(gm, "enemy_death"))

func _process(delta: float) -> void:
	if is_setup:
		if interactable && Input.is_action_just_pressed("dev_ursa_major") && gm.dev_mode:
			selecting_face = true
		
		if gm.targetting && !target_lines.is_empty() && gm.targetting_die == self:
			target_lines[current_target_line].set_point_position(1, get_local_mouse_position())
		
		if selecting_face && Input.is_action_just_pressed("interact"):
			face_i = hovered_face.get_index()
			selecting_face = false
			for target in targets:
				target.inactive = false
				target.targetter = null
			targets.clear()
			set_ability_count()
		
		# If the player isn't already targetting with a die, 
		# this die is an interactable player die when the interact key
		# was pressed, and this die has more uses of its ability available;
		# the pressed die is set as the targetting die and targetting is activated.
		if !gm.targetting && interactable && is_in_group("player_die") && Input.is_action_just_pressed("interact") && ability_count != 0:
			gm.new_targetting_die(self)
		# If targetting is active, the interact key is pressed while the die
		# is interactable and this die is a valid target for the targetting die
		# this die is selected as the target for the targetting die.
		elif gm.targetting && interactable && Input.is_action_just_pressed("interact") && is_valid_target(gm.targetting_die):
			gm.targetting_die.ability_count -= 1
			gm.targetting_die.targets.append(self) # This die is added to the target list
			# If the targetting die is a block or nullify, this die is set to 'inactive'
			if gm.targetting_die.face_is("block") || gm.targetting_die.face_is("nullify"):
				self.inactive = true
			elif gm.targetting_die.face_is("damage") && self.face_is("block") && self.ability_count != 0 && !self.inactive:
				gm.targetting_die.inactive = true
				self.ability_count -= 1
			elif gm.targetting_die.face_is("reroll"):
				self.roll()
			elif gm.targetting_die.face_is("ursa_major"):
				selecting_face = true
			elif gm.targetting_die.face_is("duplicate"):
				gm.targetting_die.current_faces.set(gm.targetting_die.face_i, self.current_faces[face_i])
				gm.targetting_die.duplicating = true
				gm.targetting_die.get_node("die_face").texture = face_textures[face_i]
			# If the targetting die has no more ability uses left, it is
			# removed as the current targetting die and the game is no longer targetting
			#if gm.targetting_die.ability_count == 0 || #gm.targetting_die.duplicating:
			#	gm.targetting = false
			#else:
			#	pass
			gm.targetting = false
			targetter = gm.targetting_die # Set this die's targetter to the current targetting die
		elif gm.targetting && Input.is_action_just_pressed("deselect"):
			gm.targetting = false
		elif Input.is_action_just_pressed("deselect") && is_in_group("enemy_die") && interactable:
			targetter.target_lines[targetter.targets.find(self)].queue_free()
			targetter.target_lines.remove_at(targetter.targets.find(self))
			targetter.targets.remove_at(targetter.targets.find(self))
			inactive = false
			targetter.inactive = false
			if targetter.ability_count < targetter.max_ability_count:
				targetter.ability_count += 1
			if ability_count < max_ability_count:
				ability_count += 1

func load_faces() -> void:
	# Load die face textures
	for face in current_faces:
		if face != null || face != "":
			var image : CompressedTexture2D = load("res://art/dieFaces/" + face + ".png")
			face_textures.append(image)
		else:
			face_textures.append(null)

func roll() -> void:
	# Set a random face
	face_i = randi_range(0, face_textures.size() - 1)
	set_ability_count()
	
	if is_in_group("enemy_die") && face_is("nullify"):
		var random_player_die : Area2D = gm.dice_pool.get_child(1).get_children().pick_random()
		random_player_die.inactive = true
		targets.append(random_player_die)
		random_player_die.targetter = self

func set_ability_count() -> void:
	# Set the ability uses of the die; 1-3 or 1
	if !face_is("block"):
		ability_count = 1
	else:
		if current_faces[face_i].ends_with("2"):
			ability_count = 2
		elif current_faces[face_i].ends_with("3"):
			ability_count = 3
		else:
			ability_count = 1
	max_ability_count = ability_count

func damage(total_damage: int) -> void:
	for damage in total_damage:
		# If the die doesn't have an empty face, that face is removed
		# if the face up face is empty, a random face is removed.
		if current_faces[face_i] != "":
			current_faces[face_i] = ""
			face_textures[face_i] = null
			$die_face.texture = null
		else:
			var random_i : int = randi_range(0, current_faces.size() - 1)
			while current_faces[random_i] == "":
				random_i = randi_range(0, current_faces.size() - 1)
			current_faces[random_i] = ""
			face_textures[random_i] = null
			# If all the faces are empty, remove the die and return
			if current_faces.count("") == 6:
				die.emit(self)
				return
	# Reload the faces
	load_faces()

func is_valid_target(die : Area2D) -> bool:
	# Check if this die's face is a valid target for the targetting die
	if die.face_is("block") && self.is_in_group("enemy_die") && self.face_is("damage"):
		return true
	elif die.face_is("damage") && self.is_in_group("enemy_die") && (!gm.enemy_has("block") || self.face_is("block")):
		return true
	elif die.face_is("duplicate") && (self.current_faces[face_i] != "" && !self.face_is("duplicate")) && die != self:
		return true
	elif die.face_is("nullify") && self.is_in_group("enemy_die") && self.current_faces[face_i] != "":
		return true
	elif die.face_is("reroll") && die != self && ability_count != 0:
		return true
	elif die.face_is("ursa_major") && self.is_in_group("player_die") && die != self && !die.duplicating:
		return true
	else:
		# If the target is invalid, exit targetting mode
		gm.targetting = false
		gm.ui.get_node("invalid_target").show()
		return false

func _on_mouse_entered() -> void:
	# Show the die's faces above the die if there is no Ursa Major target
	if !selecting_face:
		$die_faces.show()
	# Set the die to interactable
	if !interactable:
		interactable = true
	set_active_face()

func _on_mouse_exited() -> void:
	# Hide the die faces above the die and set the die to not
	# interactable if there is no Ursa Major target
	if !selecting_face:
		$die_faces.hide()
	if interactable:
		interactable = false

func set_active_face() -> void:
	# Set the die faces above the die set the faces that are not the
	# face up face to be halfway transparent
	for face in $die_faces.get_children():
		face.get_node("symbol").texture = face_textures[face.get_index()]
		if face.get_index() != face_i:
			face.modulate.a = 0.5
		else:
			face.modulate.a = 1.0

func face_is(face : String) -> bool:
	if current_faces[face_i].contains(face):
		return true
	else:
		return false

func _on_face_mouse_entered(index : int) -> void:
	for face in $die_faces.get_children():
		if face == $die_faces.get_child(index):
			face.modulate.a = 1.0
			hovered_face = face
		else:
			face.modulate.a = 0.5

func _on_selection_area_mouse_exited() -> void:
	set_active_face()
	hovered_face = null

func _on_remove_button_pressed() -> void:
	duplicating = false

func setup() -> void:
	# Randomize the points based on the difficulty level
	var points : int = randi_range(dc.get("min_points"), dc.get("max_points"))
	while points != 0:
		# Get a random index
		var f_i : int = randi_range(0, current_faces.size() - 1)
		# Create a variable to reference the face
		var face : String = current_faces[f_i]
		# If all faces on the die are maxed out or a face that cannot
		# be upgraded, the die setup is completed.
		if faces_maxed():
			base_faces = current_faces
			load_faces()
			is_setup = true
			roll()
			return
		# Reference what the max level faces are
		var max_faces : Array[String] = ["block_3", "damage_3", "nullify"]
		# Randomize the selected die face again if the selected die face
		# is already maxed or there are not enough points to purchase
		# an upgrade for the face.
		while max_faces.has(face) || cannot_purchase(face, points):
			f_i = randi_range(0, current_faces.size() - 1)
			face = current_faces[f_i]
		# If the selected face is blank and the die has less than 2
		# non-blank sides or if the face is just blank, add an ability
		# to this blank face
		if current_faces.count("") > 4:
			while face != "":
				f_i = randi_range(0, current_faces.size() - 1)
				face = current_faces[f_i]
			if !current_faces.has("damage_1") || !current_faces.has("damage_2") || !current_faces.has("damage_3"):
				current_faces[f_i] = "damage_1"
				points -= gm.start_enemy_die_faces[0].get("cost")
		elif face == "":
			var new_face : Dictionary = gm.start_enemy_die_faces.pick_random()
			while points - new_face.get("cost") < 0:
				new_face = gm.start_enemy_die_faces.pick_random()
			current_faces[f_i] = new_face.get("name")
			points -= new_face.get("cost")
		else:
			if face.contains("block"):
				if face.contains("1"):
					current_faces[f_i] = "block_2"
					points -= gm.enemy_face_costs[2].get("cost")
				elif face.contains("2"):
					current_faces[f_i] = "block_3"
					points -= gm.enemy_face_costs[3].get("cost")
			elif face.contains("damage"):
				if face.contains("1"):
					current_faces[f_i] = "damage_2"
					points -= gm.enemy_face_costs[0].get("cost")
				elif face.contains("2"):
					current_faces[f_i] = "damage_3"
					points -= gm.enemy_face_costs[1].get("cost")
	#print(current_faces)
	base_faces = current_faces
	load_faces()
	is_setup = true
	roll()

func faces_maxed() -> bool:
	var max_faces : Array[String] = ["block_3", "damage_3", "nullify"]
	for face in current_faces:
		if !max_faces.has(face):
			return false
	return true

func cannot_purchase(face : String, points : int) -> bool:
	if face.contains("block"):
		if face.contains("1"):
			if points - gm.enemy_face_costs[2].get("cost") < 0:
				return true
		elif face.contains("2"):
			if points - gm.enemy_face_costs[3].get("cost") < 0:
				return true
	elif face.contains("damage"):
		if face.contains("1"):
			if points - gm.enemy_face_costs[0].get("cost") < 0:
				return true
		elif face.contains("2"):
			if points - gm.enemy_face_costs[1].get("cost") < 0:
				return true
	return false
