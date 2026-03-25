extends Node2D

func _on_reroll_pressed() -> void:
	for pool in get_children():
		for die in pool.get_children():
			die.inactive = false
			die.duplicating = false
			for target in die.targets:
				target.targetter = null
			die.targets.clear()
			if !die.target_lines.is_empty():
				for line in die.target_lines:
					line.free()
				die.target_lines.clear()
	for pool in get_children():
		for die in pool.get_children():
			die.roll()
