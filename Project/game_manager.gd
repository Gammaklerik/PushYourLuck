extends Node

var dev_mode : bool = false :
	set(value):
		dev_mode = value
		if dev_mode:
			ui.get_node("dev_tools").show()
		else:
			ui.get_node("dev_tools").hide()
var immune : bool = false

@onready var dice_pool : Node2D = get_tree().current_scene.get_node("dice_pool")
@onready var ui : Control = get_tree().current_scene.get_node("canvas/ui")
@export var targetting_line : PackedScene
@export var die_scn : PackedScene
var enemy_dice : Array[Area2D]
var die_dcs : Array[Dictionary] = [{"difficulty" : "Very Easy", "min_points" : 2, "max_points" : 6}, {"difficulty" : "Easy", "min_points" : 7, "max_points" : 10}, {"difficulty" : "Medium", "min_points" : 11, "max_points" : 16}, {"difficulty" : "Hard", "min_points" : 17, "max_points" : 21}, {"difficulty" : "Very Hard", "min_points" : 22, "max_points" : 30}]
var combat_dcs : Array[Dictionary] = [{"difficulty" : "Very Easy", "min_points" : 2, "max_points" : 4}, {"difficulty" : "Easy", "min_points" : 5, "max_points" : 7}, {"difficulty" : "Medium", "min_points" : 8, "max_points" : 12}, {"difficulty" : "Hard", "min_points" : 13, "max_points" : 18}, {"difficulty" : "Very Hard", "min_points" : 19, "max_points" : 25}, {"difficulty" : "Impossible", "min_points" : 25}]
var start_enemy_die_faces : Array[Dictionary] = [{"name" : "damage_1", "cost" : 1}, {"name" : "block_1", "cost" : 2}, {"name" : "nullify", "cost" : 3}]
var enemy_face_costs : Array[Dictionary] = [{"name" : "damage_2", "cost" : 1}, {"name" : "damage_3", "cost" : 2}, {"name" : "block_2", "cost" : 1}, {"name" : "block_3", "cost" : 2}]
var round : int = 0 :
	set(value):
		round = value
		ui.get_node("round_count").text = "Round " + str(round)

var max_hp : int = 12
var current_hp : int :
	set(value):
		if current_hp > value:
			print("-" + str(current_hp - value))
		elif current_hp < value:
			print("+" + str(value - current_hp))
		current_hp = clamp(value, 0, max_hp)
		ui.get_node("hp").text = str(current_hp) + "/" + str(max_hp) + " HP"
		if current_hp == 0:
			die()

var targetting : bool = false :
	set(value):
		targetting = value
		if targetting:
			targetting_die.get_node("targetting").show()
			var new_line : Line2D = targetting_line.instantiate()
			targetting_die.target_lines.append(new_line)
			targetting_die.current_target_line = targetting_die.target_lines.find(new_line)
			targetting_die.add_child(new_line)
		else:
			targetting_die.get_node("targetting").hide()
			var line : Line2D = targetting_die.target_lines[targetting_die.current_target_line]
			if targetting_die.target_lines.size() == targetting_die.targets.size():
				line.set_point_position(1, targetting_die.to_local(targetting_die.targets[targetting_die.current_target_line].global_position))
			else:
				targetting_die.target_lines.remove_at(targetting_die.target_lines.find(line))
				line.free()
var targetting_die : Area2D

func _ready() -> void:
	current_hp = max_hp
	create_combat(0)

func _process(delta : float) -> void:
	if Input.is_action_just_pressed("dev_toggle"):
		if !dev_mode:
			dev_mode = true
		else:
			dev_mode = false

func _on_ready_pressed() -> void:
	# Activate enemy die pool then player die pool
	for pool in dice_pool.get_children():
		# Activate every die in the pool
		for die in pool.get_children():
			var die_face : String = die.current_faces[die.face_i]
			if !die.inactive:
				if die.is_in_group("enemy_die") && die.face_is("damage"):
					if !immune:
						# Deal damage to player
						current_hp -= int(die_face.get_slice("_", 1))
				elif !die.targets.is_empty() && die.is_in_group("player_die"):
					if die.face_is("damage"):
						for target in die.targets:
							target.damage(int(die_face.get_slice("_", 1)))
				elif die.face_is("heal"):
					# Heal player health equal to face value
					if die_face.ends_with("1"):
						current_hp += 1
					elif die_face.ends_with("2"):
						current_hp += 2
					elif die_face.ends_with("3"):
						current_hp += 3
	dice_pool.roll_all()

func new_targetting_die(die : Area2D):
	targetting_die = die
	targetting = true

func enemy_has(face : String) -> bool:
	# Check to see if there is an enemy die in play, with ability uses,
	# matching the given String.
	for die in dice_pool.get_child(0).get_children():
		if die.face_is(face) && die.ability_count != 0 && !die.inactive:
			return true
	return false

func _on_invalid_target_visibility_changed() -> void:
	if ui.get_node("invalid_target").is_visible():
		await get_tree().create_timer(0.75).timeout
		ui.get_node("invalid_target").hide()

func create_combat(dc_index : int):
	round += 1
	var combat_dc : String = combat_dcs[dc_index].get("difficulty")
	var combat_points : int
	var max_die_dc : Dictionary
	if combat_dc != "Impossible":
		combat_points = randi_range(combat_dcs[dc_index].get("min_points"), combat_dcs[dc_index].get("max_points"))
		if combat_dc != "Very Hard":
			max_die_dc = combat_dcs[dc_index + 1]
		else:
			max_die_dc = combat_dcs[4]
	else:
		#combat_points = 25 + (randi_range(1, 4) * (rounds/2 - 'rounds after Very Hard))
		max_die_dc = combat_dcs[4]
	while combat_points != 0:
		var action : int = randi_range(0, 1)
		if enemy_dice.size() != 2 || action == 0 || enemy_dice_maxed(max_die_dc):
			var new_enemy : Area2D = die_scn.instantiate()
			new_enemy.add_to_group("enemy_die")
			new_enemy.connect("die", Callable(self, "enemy_death"))
			dice_pool.get_child(0).add_child(new_enemy)
			new_enemy.position = Vector2(928.0, (113.0 + (70 * new_enemy.get_index())))
			enemy_dice.append(new_enemy)
			new_enemy.dc = combat_dcs[0]
			new_enemy.gm = self
			combat_points -= 1
		else:
			var die : Area2D = dice_pool.get_child(0).get_children().pick_random()
			while die.dc == max_die_dc:
				die = dice_pool.get_child(0).get_children().pick_random()
			die.dc = combat_dcs[combat_dcs.find(die.dc) + 1]
			combat_points -= 1
	for pool in dice_pool.get_children():
		for die in pool.get_children():
			die.setup()
	dice_pool.roll_all()

func enemy_death(die : Area2D):
	enemy_dice.remove_at(enemy_dice.find(die))
	if enemy_dice.is_empty():
		create_combat(0)

func enemy_dice_maxed(max_dc : Dictionary):
	for die in enemy_dice:
		if die.dc.get("difficulty") != max_dc.get("difficulty"):
			return false
	return true

func die():
	ui.get_node("death").show()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_immune_toggled(toggled_on: bool) -> void:
	immune = toggled_on

func _on_help_pressed() -> void:
	ui.get_node("help_menu").show()

func _on_close_pressed() -> void:
	ui.get_node("help_menu").hide()
