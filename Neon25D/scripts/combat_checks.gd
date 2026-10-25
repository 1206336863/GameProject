extends RefCounted
func run(g):
	g.start_game();g.state="menu"
	for e in g.enemies:e.body.free()
	g.enemies.clear();g.player.position=Vector3.ZERO
	g.spawn_enemy("gun",Vector3(0,0,4));var gun=g.enemies[0]
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	gun.cd=0;g.attack_gap=0;g.update_enemies(.01)
	assert(gun.mode=="aim" and g.bullets.is_empty(),"Rifleman must telegraph before firing")
	var direction=gun.dir;g.player.position.x=2
	g.update_enemies(.66);assert(gun.mode=="volley" and g.bullets.is_empty())
	g.update_enemies(.13);assert(g.bullets.size()==1 and gun.dir==direction,"First round must follow locked aim after recoil lead-in")
	g.update_enemies(.23);g.update_enemies(.23)
	assert(g.bullets.size()==3 and gun.mode=="recover")
	g.spawn_enemy("tank",Vector3(2,0,2));var tank=g.enemies[-1]
	tank.mode="windup";tank.timer=.5;tank.dir=Vector3.FORWARD;tank.freeze=.4
	var before=tank.timer;g.update_enemies(.1);assert(tank.timer==before,"Freeze must suspend attack timeline")
	assert(not g.contact_active(tank));tank.freeze=0;tank.mode="charge";assert(g.contact_active(tank))
	tank.mode="recover";assert(not g.contact_active(tank))
	g.spawn_enemy("dash",Vector3(3,0,0));var jumper=g.enemies[-1]
	jumper.mode="windup";jumper.target=Vector3(1,0,0);jumper.dir=Vector3.LEFT
	g.feel.telegraph(g,jumper);assert(jumper.warning.mesh is TorusMesh)
	jumper.mode="charge";assert(not g.contact_active(jumper),"Airborne enemy must not apply contact damage")
	# Occlusion uses rendered bounds, including props without collision; restore is reversible.
	var occluder=g.cube(g.world,Vector3(0,2,1.5),Vector3(2,2,1),Color.WHITE)
	g.feel.collect_occluders(g.world);g.player.position=Vector3.ZERO
	g.feel.update(g,.3)
	assert(g.feel.fading_count>0,"Near-side geometry must fade when covering player")
	var faded=false
	for item in g.feel.occluders:
		if item.mesh==occluder:faded=item.alpha<.3
	assert(faded)
	g.player.position=Vector3(-10,0,0);g.feel.update(g,.3)
	for item in g.feel.occluders:
		if item.mesh==occluder:assert(item.alpha==1.0)
	g.shake_strength=0;g.feel.kick(.2);g.feel.update(g,.01)
	assert(g.camera.h_offset==0 and g.camera.v_offset==0)
	g.shoot(Vector3.RIGHT);assert(g.feel.recoil>0 and g.feel.debris.size()>0)
	for i in range(30):g.feel.impact(g,Vector3.ZERO,Color.WHITE,10)
	assert(g.feel.debris.size()<=120,"Feedback particles must be bounded")
	g.feel.update(g,2);assert(g.feel.debris.is_empty())
	g.start_game();g.state="menu"
	for e in g.enemies:e.body.free()
	g.enemies.clear();g.player.position=Vector3.ZERO
	g.spawn_enemy("dash",Vector3(.5,0,0));var landing=g.enemies[0]
	landing.mode="windup";landing.timer=.5;landing.dir=Vector3.LEFT;landing.target=Vector3.ZERO
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	g.state="play";g.invulnerable=0;var hp_before=g.hp
	g.update_enemies(.1);assert(g.hp==hp_before,"Windup cannot deal contact damage")
	landing.mode="charge";landing.timer=.01;g.update_enemies(.02)
	assert(g.hp==hp_before-16 and landing.mode=="recover","Damage fires once at landing")
	g.invulnerable=0;g.update_enemies(.1);assert(g.hp==hp_before-16,"Recovery cannot repeat landing damage")
	g.state="menu";g.shake_strength=1
	print("NEON25D_COMBAT_TESTS_OK: delayed locked volleys, freeze timeline, charge damage windows, leap markers, occlusion fade/restore, shake off, bounded recoil/sparks")
	return true

