extends RefCounted
func run(g):
	g.start_game();g.state="menu"
	for e in g.enemies:e.body.free()
	g.enemies.clear()
	for i in range(30):g.spawn_enemy("chase",Vector3(-8+i*.5,0,(i%3)-1))
	g.rebuild_enemy_grid()
	for x in range(-10,11):
		var a=Vector3(x,1,0);var b=a+Vector3(1.5,0,0);var candidates=g.nearby_targets(a,b)
		for e in g.enemies:
			var pos=e.body.position+Vector3.UP
			if Geometry3D.get_closest_point_to_segment(pos,a,b).distance_to(pos)<.42:assert(e in candidates,"Broadphase must preserve all possible hits")
	g.spawn_bullet(Vector3.ZERO,Vector3.RIGHT,false);var first=g.bullets[-1].node
	g.recycle_bullet(first);g.bullets.clear();g.spawn_bullet(Vector3.ONE,Vector3.LEFT,true)
	assert(g.bullets[-1].node==first and first.visible and first.position==Vector3.ONE)
	for e in g.enemies:e.body.free()
	g.enemies.clear()
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	assert(g.animation_drivers.size()==1,"Freed actor drivers must be pruned during the same room")
	g.feel.spark_frame=-1;g.feel.spark_count=0
	for i in range(100):g.feel.impact(g,Vector3.ZERO,Color.WHITE,12)
	assert(g.feel.spark_count<=40 and g.feel.debris.size()<=120)
	g.enter_room(1);g.state="menu";assert(g.bullet_pool.is_empty())
	print("NEON25D_PERF_TESTS_OK: broadphase coverage, projectile reuse/reset, animation driver release, frame spark budget and room cleanup")
	return true
