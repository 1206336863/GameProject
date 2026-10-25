extends RefCounted
## Test in the actual Godot scene and physics world; no mock skeleton or mesh.
func run(g):
	var checked=0
	for name in ["player","enemy_chase","enemy_gun","enemy_dash","enemy_tank","boss"]:
		var model=g.models[name].instantiate();g.world.add_child(model)
		var driver=g.register_animation(model)
		assert(driver.skeleton.get_bone_count()==16,"Expected 16-bone rig: "+name)
		for clip in ["Idle","Walk","Shoot","Dash","Hurt","Death"]:assert(driver.clips.has(clip),name+" missing "+clip)
		var skinned=0
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if mesh.skin!=null:skinned+=1
		assert(skinned>0,"Imported character must have weighted skin")
		var left=driver.skeleton.find_bone("thigh.L")
		var right=driver.skeleton.find_bone("thigh.R")
		assert(left>=0 and right>=0)
		driver.base.play(driver.clips.Walk);driver.base.seek(0,true)
		var before=driver.skeleton.get_bone_pose_rotation(left)
		driver.base.advance(.2)
		var after=driver.skeleton.get_bone_pose_rotation(left)
		assert(not before.is_equal_approx(after),"Walk must deform bones")
		assert(not after.is_equal_approx(driver.skeleton.get_bone_pose_rotation(right)),"Legs must alternate")
		driver.trigger("Shoot");driver.upper.advance(.1)
		assert(after.is_equal_approx(driver.skeleton.get_bone_pose_rotation(left)),"Upper-body recoil must preserve walking legs")
		driver.trigger("Dash");assert(driver.priority==2);driver.base.advance(.1)
		var dash_position=driver.base.current_animation_position
		driver.trigger("Dash");assert(is_equal_approx(dash_position,driver.base.current_animation_position),"Repeated charge tick must not restart dash clip")
		driver.trigger("Hurt");assert(driver.priority==2,"Hurt cannot cancel dash animation")
		driver.trigger("Death");assert(driver.dying)
		model.queue_free();checked+=1
	var old_marks=g.marks
	g.start_game();g.state="menu"
	g.marks=7;g.chain=1;assert(14 not in g.eligible_upgrades())
	g.marks=8;assert(14 in g.eligible_upgrades())
	g.pending=1;g.apply_upgrade(14);g.state="menu";assert(g.storm==1 and 14 not in g.eligible_upgrades())
	g.marks=12;g.ice=1;g.explosive=1;assert(15 in g.eligible_upgrades())
	g.pending=1;g.apply_upgrade(15);g.state="menu";assert(g.crystal==1 and 15 not in g.eligible_upgrades())
	g.multi=5;g.crit_chance=.8;g.orbit=4;assert(2 not in g.eligible_upgrades() and 12 not in g.eligible_upgrades() and 13 not in g.eligible_upgrades())
	var old_radius=g.magnet_radius;g.pending=1;g.apply_upgrade(5);g.state="menu";assert(g.magnet_radius==old_radius+2)
	# Advanced lightning distance and recharge are observable combat behavior.
	g.start_game();g.state="menu"
	for e in g.enemies:e.body.free()
	g.enemies.clear()
	g.spawn_enemy("tank",Vector3(0,0,0));g.spawn_enemy("chase",Vector3(6.5,0,0))
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	g.storm=1;g.chain=1;g.crit_chance=0;g.dash_cd=1.5;g.enemies[1].hp=1
	g.projectile_hit(g.enemies[0],16)
	assert(g.enemies[1].hp<=0,"Storm must reach enemy at 6.5 meters")
	assert(is_equal_approx(g.dash_cd,1.0),"Storm kill must recharge 0.5 seconds")
	g.start_game();g.state="menu"
	for e in g.enemies:e.body.free()
	g.enemies.clear();g.spawn_enemy("tank",Vector3.ZERO);g.spawn_enemy("chase",Vector3(2.95,0,0))
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	g.ice=1;g.explosive=1;g.crit_chance=0;g.enemies[0].freeze=1
	var life_before=g.enemies[1].hp
	g.projectile_hit(g.enemies[0],16);assert(g.enemies[1].hp==life_before,"Ordinary ice blast must not reach 2.95m target")
	g.crystal=1;g.enemies[0].freeze=1;g.projectile_hit(g.enemies[0],16)
	assert(is_equal_approx(g.enemies[1].hp,life_before-19.2),"Crystal blast must increase both radius and damage")
	# Statistics grade boundaries and storage round trip keep old progress fields.
	g.run_floor=12;g.elapsed=359;g.run_damage=99;assert(g.rank_for(true)=="S")
	g.run_damage=100;assert(g.rank_for(true)=="A")
	g.elapsed=600;assert(g.rank_for(true)=="B")
	g.run_floor=4;assert(g.rank_for(false)=="D")
	g.run_floor=9;assert(g.rank_for(false)=="B")
	var count_before=g.total_runs
	g.state="play";g.finish(true);assert(g.total_runs==count_before+1)
	g.finish(true);assert(g.total_runs==count_before+1,"Settlement must be idempotent")
	var cfg=ConfigFile.new();g.write_progress(cfg)
	var copy=ConfigFile.new();assert(copy.parse(cfg.encode_to_text())==OK)
	assert(copy.get_value("progress","marks")==g.marks)
	assert(copy.get_value("statistics","history").size()>0)
	g.load_statistics(copy);assert(g.total_runs==count_before+1)
	g.marks=old_marks
	# Native touch press / drag / release and pause reset.
	g.start_game();g.state="menu"
	var pad=g.move_pad
	assert(pad.vector_for(Vector2(3,0))==Vector2.ZERO)
	var press=InputEventScreenTouch.new();press.index=7;press.position=Vector2(70,70);press.pressed=true;pad._gui_input(press)
	var drag=InputEventScreenDrag.new();drag.index=7;drag.position=Vector2(115,70);pad._gui_input(drag)
	assert(g.touch_move.x>.5)
	g.reset_touch();assert(g.touch_move==Vector2.ZERO and pad.finger==-1)
	assert(g.world.find_child("Rain",true,false)!=null)
	assert(g.hp_bar.size.y<=12 and g.dash_bar.size.y<=8,"HUD progress bars must not expand over build text")
	print("NEON25D_DEEP_TESTS_OK: ",checked," genuine skinned rigs / 36 clips, alternating legs, layered shoot, advanced unlocks, storm range/recharge, capped choices, statistics grades/storage, native touch events, scene dressing")
	return true
