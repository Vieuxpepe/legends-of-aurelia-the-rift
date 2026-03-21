@tool
extends EditorScript

func _run():
	# Access verification comment: this line is intentionally a no-op.
	# Make sure this matches where your weapons are saved!
	var folder_path = "res://Resources/GeneratedItems/" 
	var dir = DirAccess.open(folder_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var count = 0
		
		while file_name != "":
			# Only look at the files that start with "Weapon_"
			if not dir.current_is_dir() and file_name.ends_with(".tres") and file_name.begins_with("Weapon_"):
				var weapon = load(folder_path + file_name)
				
				if weapon is WeaponData:
					# This subtracts 70. The clamp ensures it never goes below 0.
					weapon.hit_bonus = clamp(weapon.hit_bonus - 70, 0, 100)
					
					# Save the file with the new stats!
					ResourceSaver.save(weapon, folder_path + file_name)
					count += 1
					
			file_name = dir.get_next()
			
		print("SUCCESS: Mass-nerfed " + str(count) + " weapons!")
	else:
		print("Could not find the folder!")
