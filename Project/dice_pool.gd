extends Node2D

func roll_all() -> void:
	for pool in get_children():
		for die in pool.get_children():
			die.inactive = false
			if die.duplicating:
				die.duplicating = false
			die.prev_face_i = -1
			for target in die.targets:
				target.targetters.clear()
			die.targets.clear()
			if !die.target_lines.is_empty():
				for line in die.target_lines:
					line.free()
				die.target_lines.clear()
	for pool in get_children():
		for die in pool.get_children():
			die.roll()
	for die in get_child(0).get_children():
		if die.is_in_group("enemy_die") && die.face_is("nullify"):
			var random_player_die : Area2D = get_child(1).get_children().pick_random()
			var all_blank : bool = true
			for d in get_child(1).get_children():
				if d.current_faces[d.face_i] != "":
					all_blank = false
			if !all_blank:
				while random_player_die.current_faces[random_player_die.face_i] == "":
					random_player_die = get_child(1).get_children().pick_random()
				random_player_die.inactive = true
				die.targets.append(random_player_die)
				random_player_die.targetters.append(die)
			else:
				random_player_die.inactive = true
				die.targets.append(random_player_die)
				random_player_die.targetters.append(die)
