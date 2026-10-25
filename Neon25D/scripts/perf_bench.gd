extends RefCounted
var random=RandomNumberGenerator.new()
var samples=[]
var memory=[]
func populate(g,count):
	for e in g.enemies:e.body.free()
	g.enemies.clear()
	for i in range(count):
		g.spawn_enemy(["chase","gun","tank","dash"][i%4],Vector3(random.randf_range(-10,10),0,random.randf_range(-4,4)))
		g.enemies[-1].hp=100000;g.enemies[-1].max=100000
	g.player.position=Vector3(-9,0,0);g.invulnerable=99999
	for particles in g.world.find_children("*","GPUParticles3D",true,false):particles.amount=1500 if particles.name=="Rain" else 180
func measure(g):
	return {"seconds":Time.get_ticks_msec()/1000.0,"static_mb":OS.get_static_memory_usage()/1048576.0,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"video_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"drivers":g.animation_drivers.size(),"bullets":g.bullets.size(),"enemies":g.enemies.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func run(g,duration,output):
	print("PERF_PID ",OS.get_process_id())
	random.seed=12345;g.rng.seed=12345
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
	g.start_game();g.options.quality=2;g.options.apply_quality(g);populate(g,72)
	var start=Time.get_ticks_usec();var last=start;var next_sample=0.0;var next_churn=10.0
	var peak_bullets=0;var peak_enemies=0
	while (Time.get_ticks_usec()-start)/1000000.0<duration:
		await g.get_tree().process_frame
		var now=Time.get_ticks_usec();var elapsed=(now-start)/1000000.0
		if elapsed>8:samples.append((now-last)/1000.0)
		last=now
		g.invulnerable=99999;g.pending=0;g.hp=g.max_hp;g.state="play"
		g.player.position=Vector3(sin(elapsed*.3)*9,0,cos(elapsed*.23)*4)
		while g.bullets.size()<320:
			var dir=Vector3(cos(random.randf()*TAU),0,sin(random.randf()*TAU)).normalized()
			g.spawn_bullet(Vector3(random.randf_range(-9,9),1,random.randf_range(-4,4)),dir*8,random.randf()<.5,0)
		peak_bullets=max(peak_bullets,g.bullets.size());peak_enemies=max(peak_enemies,g.enemies.size())
		if elapsed>=next_churn:
			next_churn+=10
			for i in range(12):
				var e=g.enemies[0];e.hp=0;g.kill_enemy(e)
				g.spawn_enemy(["chase","gun","tank","dash"][i%4],Vector3(random.randf_range(-10,10),0,random.randf_range(-4,4)));g.enemies[-1].hp=100000
			g.collect_all();g.pending=0
		if elapsed>=next_sample:next_sample+=5;memory.append(measure(g))
	print("PERF_COMBAT_COMPLETE")
	var sorted=samples.duplicate();sorted.sort()
	var total=0.0
	for value in samples:total+=value
	var report={"duration_s":duration,"warmup_s":8,"quality":"high","renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":str(g.get_viewport().get_visible_rect().size),"fps_cap":120,"mean_fps":1000/(total/max(1,samples.size())),"p95_ms":sorted[int((sorted.size()-1)*.95)],"p99_ms":sorted[int((sorted.size()-1)*.99)],"max_ms":sorted[-1],"peak_enemies":peak_enemies,"peak_bullets":peak_bullets,"samples":memory}
	# Fixed cleanup boundary after combat; repeat room creation/free to expose retained resources.
	g.state="menu"
	var retention=[]
	for i in range(40):
		g.enter_room(i%12);g.state="menu"
		for frame in range(3):await g.get_tree().process_frame
		if i%5==0:retention.append(measure(g));print("PERF_ROOM_CYCLE ",i)
	report.room_cycles=retention
	g.world.free();g.animation_drivers.clear();g.feel.reset(g);g.enemies.clear();g.bullets.clear();g.fx.clear();g.loot.clear()
	for frame in range(5):await g.get_tree().process_frame
	report.after_cleanup=measure(g)
	var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PERF_BENCH_OK ",JSON.stringify({"mean_fps":report.mean_fps,"p95_ms":report.p95_ms,"p99_ms":report.p99_ms,"duration":duration}))
	g.get_tree().quit()
