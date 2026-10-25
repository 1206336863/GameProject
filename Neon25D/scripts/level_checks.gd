extends RefCounted
func clear_enemies(g):
	for e in g.enemies:e.body.free()
	g.enemies.clear()
func accessible(layout,target):
	var obstacles=preload("res://scripts/level_director.gd").new().positions(layout)
	var queue=[Vector2i(-22,0)];var seen={Vector2i(-22,0):true}
	while not queue.is_empty():
		var cell=queue.pop_front()
		if Vector2(cell).distance_to(target*2)<1:return true
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next=cell+step
			if next in seen or abs(next.x)>24 or abs(next.y)>10:continue
			var blocked=false
			for pos in obstacles:
				if abs(next.x*.5-pos.x)<1.15 and abs(next.y*.5-pos.z)<1.15:blocked=true
			if not blocked:seen[next]=true;queue.append(next)
	return false
func run(g):
	g.start_game();g.state="menu"
	for iteration in range(40):
		g.levels.configure(g)
		var goals=[];var layouts=[]
		for i in range(g.rooms.size()):
			var r=g.rooms[i]
			if i>2 and r.type=="fight":goals.append(r.goal)
			if i>2 and r.layout not in layouts:layouts.append(r.layout)
		assert(goals.size()==4 and 1 in goals and 2 in goals and 3 in goals)
		assert(layouts.size()==4 and g.rooms[0].goal==0 and g.rooms[2].type=="shop")
	for layout in range(5):
		for target in [Vector2(11,0),Vector2.ZERO,Vector2(0,-4.2),Vector2(8,0)]:
			assert(accessible(layout,target),"Layout must connect entrance, exit and objectives with player clearance")
		g.rooms[0].layout=layout;g.enter_room(0);g.state="menu"
		await g.get_tree().physics_frame
		await g.get_tree().physics_frame
		var pos=g.levels.obstacles[0]
		assert(not g.has_sight(pos+Vector3(-2,0,0),pos+Vector3(2,0,0)),"Authored cover must block projectiles")
	var r=g.rooms[0];clear_enemies(g);r.goal=1;r.wave=1;r.clear=false
	g.levels.tick(g,.1);assert(r.wave==2 and not g.enemies.is_empty() and not g.levels.complete(r))
	clear_enemies(g);g.levels.tick(g,.1);assert(r.wave==3 and not g.enemies.is_empty())
	clear_enemies(g);g.levels.tick(g,.1);assert(g.levels.complete(r))
	r.goal=2;r.progress=0;r.wave=1;g.player.position=Vector3(8,0,0)
	g.levels.tick(g,5);assert(r.progress==0)
	g.player.position=Vector3.ZERO;g.levels.tick(g,6);assert(r.progress==6 and r.wave==2 and not g.levels.complete(r))
	g._physics_process(6);assert(r.progress==6,"Paused game must not advance objective")
	g.levels.tick(g,6);assert(g.levels.complete(r));clear_enemies(g)
	r.goal=3;r.lit=[];g.enter_room(0);g.state="menu";clear_enemies(g)
	for node in g.levels.zones:g.player.position=node.position;g.levels.tick(g,.01)
	assert(r.lit.size()==3 and g.levels.complete(r))
	g.levels.tick(g,1);assert(r.lit.size()==3,"Beacon progress must be idempotent")
	r.lit=[];g.player.position=Vector3.ZERO;g.pending=0;g.state="play"
	var reward_before=g.coins;g._physics_process(.01)
	assert(not r.clear and g.coins==reward_before,"Empty room cannot open before objective")
	r.lit=[0,1,2];g._physics_process(.01);assert(r.clear and g.coins==reward_before+10)
	g._physics_process(.01);assert(g.coins==reward_before+10,"Completion reward must not repeat")
	g.enter_room(11);g.state="menu";var boss=g.enemies[0]
	var full=boss.hp;g.hit_enemy(boss,100);assert(boss.hp==full,"Intro shield")
	boss.mode="rest";g.hit_enemy(boss,99999);assert(boss.hp==full*.65,"Burst damage cannot skip phases")
	g.spawn_bullet(Vector3.ZERO,Vector3.RIGHT,true);g.boss_behavior(boss,.01)
	assert(boss.phase==2 and boss.mode=="transition")
	for bullet in g.bullets:assert(not bullet.enemy,"Phase transition clears hostile bullets")
	g.hit_enemy(boss,100);assert(boss.hp==full*.65)
	boss.timer=0;g.boss_behavior(boss,.01);assert(boss.mode=="rest")
	g.hit_enemy(boss,99999);g.boss_behavior(boss,.01);assert(boss.phase==3 and boss.mode=="transition")
	boss.timer=0;g.boss_behavior(boss,.01);boss.move=2;boss.timer=0
	g.player.position=Vector3.ZERO;g.boss_behavior(boss,.01);assert(boss.move==3 and boss.mode=="windup")
	var safe=boss.dir;boss.timer=0;g.boss_behavior(boss,.01)
	assert(g.bullets.size()==19,"Radial attack leaves a five-ray safe sector")
	for bullet in g.bullets:assert(bullet.vel.normalized().dot(safe)<cos(.55))
	assert(boss.mode=="rest" and boss.timer>=1.0,"Every attack leaves a punish window")
	var coins=g.coins;boss.hp=0;g.kill_enemy(boss);assert(g.state=="win" and g.coins>=coins+100)
	print("NEON25D_LEVEL_TESTS_OK: 40 randomized plans, 5 connected layouts, actual cover collision, waves/control/beacons, pause, 3 boss phases, shields, safe-sector barrage and victory")
	return true
