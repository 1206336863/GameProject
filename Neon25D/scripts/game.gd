extends Node3D
## Blender-authored meshes, Godot lighting, orthographic projection, native physics.
var rng = RandomNumberGenerator.new()
var world: Node3D
var camera: Camera3D
var player: CharacterBody3D
var player_model: Node3D
var ui: CanvasLayer
var hud: Label
var hint: Label
var boss_hud: Label
var boss_bar: ProgressBar
var exit_marker: MeshInstance3D
var dash_bar: ProgressBar
var overlay: Control
var menu_box: VBoxContainer
var enemies: Array = []
var bullets: Array = []
var loot: Array = []
var fx: Array = []
var hazards: Array = []
var rooms: Array = []
var models = {}
var state = "menu"
var room_index = 0
var hp = 100.0
var max_hp = 100.0
var damage_value = 16.0
var speed = 6.2
var fire_rate = 0.24
var shot_cd = 0.0
var dash_cd = 0.0
var dash_time = 0.0
var dash_dir = Vector3.RIGHT
var invulnerable = 0.0
var elapsed = 0.0
var coins = 0
var kills = 0
var level = 1
var xp = 0
var xp_need = 30
var pending = 0
var multi = 1
var pierce = 0
var chain = 0
var ice = 0
var explosive = 0
var leech = 0
var orbit = 0
var regen = 0.0
var crit_chance = 0.08
var attack_gap = 0.0
var build_counts = {}
var marks = 0
var total_kills = 0
var wins = 0
var chosen_runner = 0
var chosen_weapon = 0
var settled = false
var muted = false
var test_mode = false
var capture_path = ""
var frame_count = 0
var sound_bank = {}
const TITLES = ["过载电容","极速扳机","双生弹道","热汤续命","轻盈步伐","磁力拾取","穿巷弹头","回春霓虹","雷电链","绝对零度","爆炸弹","血色回路","环绕刃","致命节拍"]
const DESCS = ["伤害 +30%","射击间隔 ×0.8","弹丸 +1，最多五枚","上限 +25，恢复 40","移动速度 +15%","自动收集当前房间掉落","额外穿透一名敌人","每秒回复 0.7","跳跃电击，击杀回充冲刺","三次命中冻结，可与爆炸联动","命中造成范围爆炸","恢复实际命中伤害的 4%","近战旋转刃，可与吸血联动","暴击概率 +15%"]

func _ready():
	rng.randomize()
	for arg in OS.get_cmdline_user_args():
		if arg == "--test": test_mode = true
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
	var cfg = ConfigFile.new()
	if cfg.load("user://progress.cfg") == OK:
		marks = int(cfg.get_value("progress","marks",0))
		total_kills = int(cfg.get_value("progress","kills",0))
		wins = int(cfg.get_value("progress","wins",0))
	for name in ["player","boss","enemy_chase","enemy_gun","enemy_dash","enemy_tank","stall_ramen","stall_tea","stall_arcade","crate","lantern"]:
		models[name] = load("res://assets/"+name+".glb")
	create_camera()
	create_ui()
	prepare_audio()
	show_title()
	if test_mode: call_deferred("run_tests")
	elif capture_path != "": start_game()

func material(color: Color, emission = false):
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.28
	m.metallic = 0.35
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.5
	return m

func cube(parent, pos: Vector3, size: Vector3, color: Color, emission = false):
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(color, emission)
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func instantiate_model(name, pos: Vector3, scale_value = 1.0):
	var node = models[name].instantiate()
	world.add_child(node)
	node.position = pos
	node.scale = Vector3.ONE * scale_value
	return node

func solid(pos: Vector3, size: Vector3):
	var body = StaticBody3D.new()
	body.collision_layer = 1
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.position = pos
	return body

func actor(pos: Vector3, radius = 0.34):
	var body = CharacterBody3D.new()
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.collision_layer = 2
	body.collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.75
	body.add_child(shape)
	world.add_child(body)
	body.position = pos
	return body

func create_camera():
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 32.5
	camera.position = Vector3(0,25,19)
	camera.look_at(Vector3(0,0,0))
	camera.current = true
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("090e21")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("5e719b")
	settings.ambient_light_energy = 0.55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-65,-25,0)
	moon.light_color = Color("a2baff")
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	add_child(moon)

func create_ui():
	ui = CanvasLayer.new()
	add_child(ui)
	var top = PanelContainer.new()
	ui.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 18
	var row = HBoxContainer.new()
	top.add_child(row)
	hud = Label.new()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_theme_font_size_override("font_size",20)
	row.add_child(hud)
	var sound_button = Button.new()
	sound_button.text = "音效 开/关"
	sound_button.pressed.connect(func(): muted = not muted)
	row.add_child(sound_button)
	var pause_button = Button.new()
	pause_button.text = "暂停 Esc"
	pause_button.pressed.connect(toggle_pause)
	row.add_child(pause_button)
	dash_bar = ProgressBar.new()
	ui.add_child(dash_bar)
	dash_bar.position = Vector2(24,67)
	dash_bar.size = Vector2(200,8)
	dash_bar.show_percentage = false
	boss_hud = Label.new()
	ui.add_child(boss_hud)
	boss_hud.position = Vector2(390,84)
	boss_hud.add_theme_font_size_override("font_size",22)
	boss_hud.modulate = Color("ff8fba")
	boss_bar = ProgressBar.new()
	ui.add_child(boss_bar)
	boss_bar.position = Vector2(350,64)
	boss_bar.size = Vector2(740,12)
	boss_bar.show_percentage = false
	hint = Label.new()
	ui.add_child(hint)
	hint.position = Vector2(24,855)
	hint.add_theme_font_size_override("font_size",17)
	overlay = Control.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0.025,0.035,0.08,0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	menu_box = VBoxContainer.new()
	menu_box.custom_minimum_size = Vector2(650,0)
	menu_box.add_theme_constant_override("separation",12)
	center.add_child(menu_box)

func menu(title_text, description):
	state = "menu"
	overlay.show()
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",36)
	title.modulate = Color("75f5d6")
	menu_box.add_child(title)
	var text_label = Label.new()
	text_label.text = description
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size",18)
	menu_box.add_child(text_label)

func button(text_value, callback):
	var b = Button.new()
	b.text = text_value
	b.custom_minimum_size.y = 48
	b.pressed.connect(callback)
	menu_box.add_child(b)
	return b

func show_title():
	menu("霓虹夜市 / 2.5D", "午夜营业中 · 立体夜市\n十二街区 / 实体掩体 / 异能构筑 / 最终 Boss\nWASD 或方向键移动 · 鼠标左键射击 · 空格冲刺 · E 交互\n永久印记 %d · 累计击败 %d · 通关 %d" % [marks,total_kills,wins])
	button("角色："+["夜行信使 100HP","滑板游侠 85HP / 高移速","夜摊守卫 120HP / 低移速"][chosen_runner]+"  [点击切换]",cycle_runner)
	button("武器："+["脉冲手枪","近距散射","穿巷长针"][chosen_weapon]+"  [点击切换]",cycle_weapon)
	button("开始午夜突围",start_game)
	button("退出游戏",func(): get_tree().quit())

func cycle_runner():
	chosen_runner = (chosen_runner+1)%3
	if marks < [0,3,6][chosen_runner]: chosen_runner = 0
	show_title()

func cycle_weapon():
	chosen_weapon = (chosen_weapon+1)%3
	if marks < [0,2,5][chosen_weapon]: chosen_weapon = 0
	show_title()

func start_game():
	hp = [100.0,85.0,120.0][chosen_runner]
	max_hp = hp
	speed = [6.2,7.1,5.3][chosen_runner]
	damage_value = [16.0,7.0,28.0][chosen_weapon]
	fire_rate = [0.24,0.38,0.48][chosen_weapon]
	multi = 3 if chosen_weapon == 1 else 1
	pierce = 1 if chosen_weapon == 2 else 0
	coins = 0; kills = 0; level = 1; xp = 0; xp_need = 30; pending = 0
	chain = 0; ice = 0; explosive = 0; leech = 0; orbit = 0; regen = 0.0; crit_chance = 0.08
	elapsed = 0; dash_cd = 0; dash_time = 0; shot_cd = 0; settled = false
	build_counts.clear()
	var pool = ["fight","fight","fight","fight","treasure","treasure","shop","event"]
	pool.shuffle()
	rooms = []
	for type in ["fight","fight","shop"]+pool+["boss"]:
		rooms.append({"type":type,"clear":false,"used":false,"barrel":true,"visited":false,"rewarded":false,"drops":[],"layout":rng.randi_range(0,2)})
	rooms[0].layout = 0; rooms[1].layout = 0; rooms[2].layout = 0
	enter_room(0)

func enter_room(index):
	if is_instance_valid(world):
		world.free()
	enemies.clear(); bullets.clear(); loot.clear(); fx.clear(); hazards.clear()
	world = Node3D.new(); add_child(world)
	room_index = index
	var r = rooms[index]
	var first = not r.visited
	r.visited = true
	cube(world,Vector3(0,-0.17,0),Vector3(30,0.3,20),Color("121b30"))
	for x in range(-14,15,2): cube(world,Vector3(x,0.005,0),Vector3(0.025,0.01,18),Color("25354b"))
	for z in range(-8,10,2): cube(world,Vector3(0,0.006,z),Vector3(28,0.01,0.025),Color("25354b"))
	for z in [-7.0,7.0]:
		for i in range(8):
			var pos = Vector3(-11.8+i*3.4,0,z)
			instantiate_model(["stall_ramen","stall_tea","stall_arcade"][i%3],pos)
			solid(pos+Vector3(0,1.2,0),Vector3(2.8,2.4,1.7))
			var light = OmniLight3D.new(); world.add_child(light)
			light.position = pos+Vector3(0,2.5,0)
			light.light_color = [Color("ff458d"),Color("5dffe0"),Color("a87aff")][i%3]
			light.light_energy = 2.0; light.omni_range = 4.0
	for x in [-13.5,13.5]: solid(Vector3(x,1,0),Vector3(0.5,2,14))
	for z in [-5.8,5.8]: solid(Vector3(0,0.6,z),Vector3(27,1.2,0.25))
	var positions = [Vector3(-5,0,-2),Vector3(4,0,2.4)]
	if r.layout == 1: positions = [Vector3(-4,0,-1.5),Vector3(-4,0,-3),Vector3(4,0,1.5),Vector3(4,0,3)]
	if r.type == "boss": positions = [Vector3(-5,0,-3),Vector3(5,0,3)]
	for pos in positions:
		instantiate_model("crate",pos,1.5);solid(pos+Vector3(0,0.75,0),Vector3(1.5,1.5,1.5))
	if r.layout == 2 and index > 2 and r.type != "boss":
		for pos in [Vector3(-1,0.02,-3),Vector3(2,0.02,3)]:
			cube(world,pos,Vector3(3,0.04,1.6),Color("287a55"),true)
			hazards.append({"pos":pos,"size":Vector2(3,1.6)})
	for i in range(13): instantiate_model("lantern",Vector3(-12+i*2,3.7,-5.9),0.75)
	player = actor(Vector3(-10.5,0,0))
	player_model = models.player.instantiate(); player.add_child(player_model)
	invulnerable = 1; attack_gap = 0.9
	if r.type in ["fight","boss"] and not r.clear:
		if r.type == "boss": spawn_enemy("boss",Vector3(9,0,0))
		else:
			var plan = ["chase","chase","chase"] if index == 0 else ["chase","gun","chase","chase"]
			if index > 2: plan = ["tank","chase","chase","gun","dash"] if index%2 else ["gun","chase","gun","chase","dash"]
			for i in range(plan.size()): spawn_enemy(plan[i],Vector3(6+i%3*2,0,-3+i%4*2))
	else: r.clear = true
	if r.type in ["shop","treasure","event"]: instantiate_model("crate",Vector3(0,0,0),1.2)
	exit_marker = cube(world,Vector3(12.75,.08,0),Vector3(.16,.1,3),Color("ff548c"),true)
	if index == 2 and first: hp = min(max_hp,hp+30)
	for drop in r.drops: spawn_loot(Vector3(drop.x,0,drop.z),drop.heal,drop.xp,drop.coins)
	state = "play"; overlay.hide()
	update_hud()

func spawn_enemy(kind, pos):
	var body = actor(pos,0.5 if kind in ["boss","tank"] else 0.32)
	var mesh = models["boss" if kind == "boss" else "enemy_"+kind].instantiate()
	body.add_child(mesh)
	var size = 1.7 if kind == "boss" else 1.12 if kind == "tank" else 1.0
	mesh.scale = Vector3.ONE*size
	var life = 1250.0 if kind == "boss" else 110.0 if kind == "tank" else 38.0+room_index*3
	var e = {"body":body,"mesh":mesh,"kind":kind,"hp":life,"max":life,"cd":1.0+enemies.size()*0.3,"mode":"rest" if kind == "boss" else "seek","timer":1.4,"dir":Vector3.ZERO,"move":0,"slow":0.0,"freeze":0.0,"hits":0,"orbit_cd":0.0}
	enemies.append(e)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: toggle_pause()
		if event.keycode == KEY_SPACE and state == "play": try_dash()
		if event.keycode == KEY_E and state == "play": interact()
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func movement():
	return Vector3(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()

func aim_direction():
	var mouse = get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP,0.9).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	if hit == null: return Vector3.FORWARD
	var dir = hit-player.position; dir.y = 0
	return dir.normalized()

func try_dash():
	if dash_cd > 0: return
	dash_dir = movement()
	if dash_dir.length() < 0.1: dash_dir = aim_direction()
	dash_cd = 1.5; dash_time = 0.2; invulnerable = max(invulnerable,0.25)
	sound("dash")

func _physics_process(dt):
	if state != "play": return
	elapsed += dt; shot_cd -= dt; dash_cd = max(0,dash_cd-dt); dash_time = max(0,dash_time-dt); invulnerable = max(0,invulnerable-dt); attack_gap = max(0,attack_gap-dt)
	hp = min(max_hp,hp+regen*dt)
	player.velocity = dash_dir*speed*3 if dash_time > 0 else movement()*speed
	player.move_and_slide()
	var aim = aim_direction()
	player_model.rotation.y = atan2(aim.x,aim.z)
	player_model.position.y = abs(sin(elapsed*13))*0.055 if player.velocity.length() > 0.1 else 0.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and shot_cd <= 0:
		shoot(aim); shot_cd = fire_rate
	for h in hazards:
		if abs(player.position.x-h.pos.x)<h.size.x/2 and abs(player.position.z-h.pos.z)<h.size.y/2: hurt(6)
	update_enemies(dt)
	if state != "play": return
	update_bullets(dt)
	if state != "play": return
	update_loot(dt)
	update_fx(dt)
	var r = rooms[room_index]
	if enemies.is_empty() and not r.clear:
		r.clear = true; coins += 10
		if room_index < 2 and not r.rewarded:
			r.rewarded = true
			collect_all()
			if room_index == 0 and level == 1: add_xp(xp_need-xp)
			hp = min(max_hp,hp+(12 if room_index == 0 else 18))
	if pending > 0: choose_upgrade(); return
	if r.clear and player.position.x > 12.1 and abs(player.position.z)<1.6 and room_index < 11:
		save_room_drops(); enter_room(room_index+1)
	elif r.clear and player.position.x < -12.1 and abs(player.position.z)<1.6 and room_index > 0:
		save_room_drops(); enter_room(room_index-1);player.position.x = 11.5
	update_hud()

func shoot(dir):
	for i in range(multi):
		var angle = (i-(multi-1)*0.5)*0.14
		spawn_bullet(player.position+Vector3(0,1,0),dir.rotated(Vector3.UP,angle)*22,false,damage_value,pierce)
	sound("shot")

func spawn_bullet(pos, vel, enemy, amount=10.0, penetration=0):
	var node = cube(world,pos,Vector3(0.12,0.12,0.3),Color("ff527f") if enemy else Color("7effdf"),true)
	node.rotation.y = atan2(vel.x,vel.z)
	bullets.append({"node":node,"vel":vel,"enemy":enemy,"damage":amount,"pierce":penetration,"life":3.0,"hit":[]})

func has_sight(a: Vector3,b: Vector3):
	var ray = PhysicsRayQueryParameters3D.create(a+Vector3(0,0.8,0),b+Vector3(0,0.8,0),1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func update_enemies(dt):
	for e in enemies.duplicate():
		if e.hp <= 0: continue
		e.cd -= dt;e.timer -= dt;e.slow = max(0,e.slow-dt);e.freeze = max(0,e.freeze-dt);e.orbit_cd -= dt
		var b = e.body
		var dir = (player.position-b.position).normalized()
		var distance = b.position.distance_to(player.position)
		var velocity = dir*(2.1 if e.kind == "tank" else 2.8)
		if e.freeze > 0: velocity = Vector3.ZERO
		elif e.kind == "boss": velocity = boss_behavior(e,dt)
		elif e.kind == "gun":
			velocity = dir*(-1.5 if distance<5.0 else 1.6 if distance>8 else 0.0)
			if e.cd<=0 and attack_gap<=0 and has_sight(b.position,player.position):
				e.mode="volley";e.timer=0.0;e.burst=3;e.cd=2.4;attack_gap=1.4
			if e.mode=="volley" and e.timer<=0:
				spawn_bullet(b.position+Vector3(0,1,0),dir*8,true)
				e.burst-=1;e.timer=.18
				if e.burst<=0:e.mode="seek"
		elif e.kind in ["tank","dash"]:
			if e.mode=="windup":
				velocity=Vector3.ZERO
				if e.timer<=0:e.mode="charge";e.timer=.55 if e.kind=="tank" else .3
			elif e.mode=="charge":
				velocity=e.dir*13
				if e.timer<=0:e.mode="recover";e.timer=.9;attack_gap=.6
			elif e.mode=="recover":
				velocity=Vector3.ZERO
				if e.timer<=0:e.mode="seek";e.cd=1.7
			elif e.cd<=0 and attack_gap<=0 and distance<12 and has_sight(b.position,player.position):
				e.mode="windup";e.dir=dir;e.timer=.85 if e.kind=="tank" else .4;attack_gap=1.5
				warning_line(b.position,dir,Color("ffad65"))
		if e.slow>0:velocity*=.5
		b.velocity=velocity;b.move_and_slide()
		if b.get_slide_collision_count()>0 and e.mode=="charge":
			e.mode="rest" if e.kind=="boss" else "recover";e.timer=1.7 if e.kind=="boss" else .9
		elif b.get_slide_collision_count()>0 and e.mode=="seek":
			b.velocity=Vector3(-dir.z,0,dir.x)*2.5;b.move_and_slide()
		if dir.length()>.1:e.mesh.rotation.y=atan2(dir.x,dir.z)
		if distance<(1.3 if e.kind=="boss" else .8):hurt(20 if e.kind=="boss" else 12)
		for i in range(orbit):
			var orbit_pos=player.position+Vector3(cos(elapsed*3+i*TAU/orbit),0,sin(elapsed*3+i*TAU/orbit))*1.8
			if e.orbit_cd<=0 and orbit_pos.distance_to(b.position)<.8 and has_sight(player.position,b.position):
				var actual=min(e.hp,damage_value*.7);hit_enemy(e,damage_value*.7);e.orbit_cd=.3
				if leech>0:hp=min(max_hp,hp+actual*.04*leech)
		if state!="play":return
	for e in enemies.duplicate():
		if e.hp<=0:kill_enemy(e)

func boss_behavior(e, _dt):
	var b=e.body
	if e.hp<e.max/2 and not e.has("phase2"):
		e.phase2=true;e.mode="rest";e.timer=1.5
		for bullet in bullets.duplicate():
			if bullet.enemy:bullet.node.queue_free();bullets.erase(bullet)
	if e.mode=="rest" and e.timer<=0:
		e.move=(e.move+1)%3;e.mode="windup";e.timer=1.1;e.dir=(player.position-b.position).normalized()
		if e.move==0:
			e.target=player.position
			for dx in [-3,0,3]:ring_warning(Vector3(clamp(e.target.x+dx,-11,11),0.03,e.target.z),1.5,1.1,true)
		else:warning_line(b.position,e.dir,Color("ff618e"))
	elif e.mode=="windup" and e.timer<=0:
		if e.move==2:e.mode="charge";e.timer=.65
		else:
			if e.move==1:
				var count=11 if e.has("phase2") else 7
				for i in range(count):spawn_bullet(b.position+Vector3(0,1,0),e.dir.rotated(Vector3.UP,(i-(count-1)*.5)*.16)*8.5,true)
			e.mode="rest";e.timer=1.5
	elif e.mode=="charge":
		if e.timer<=0:e.mode="rest";e.timer=1.7
		else:return e.dir*12
	return Vector3.ZERO

func update_bullets(dt):
	for bullet in bullets.duplicate():
		var node=bullet.node
		var start=node.position
		var end=start+bullet.vel*dt
		var query=PhysicsRayQueryParameters3D.create(start,end,1)
		var wall=get_world_3d().direct_space_state.intersect_ray(query)
		if not wall.is_empty():end=wall.position;bullet.life=0
		node.position=end;bullet.life-=dt
		var candidates=[{"body":player}] if bullet.enemy else enemies.duplicate()
		for target in candidates:
			if target in bullet.hit:continue
			if not bullet.enemy and target.hp<=0:continue
			var pos=target.body.position+Vector3(0,1,0)
			var closest=Geometry3D.get_closest_point_to_segment(pos,start,end)
			if closest.distance_to(pos)<(.85 if target.get("kind","")=="boss" else .42):
				bullet.hit.append(target)
				if bullet.enemy:hurt(10)
				else:projectile_hit(target,bullet.damage)
				bullet.pierce-=1
				if bullet.pierce<0:bullet.life=0;break
		if bullet.life<=0 or node.position.length()>40:
			node.queue_free();bullets.erase(bullet)
		if state!="play":return
	for e in enemies.duplicate():
		if e.hp<=0:kill_enemy(e)

func projectile_hit(e, amount):
	var critical=rng.randf()<crit_chance
	var actual=min(e.hp,amount*(2 if critical else 1))
	var frozen=e.freeze>0
	hit_enemy(e,amount*(2 if critical else 1),critical)
	if leech>0:hp=min(max_hp,hp+actual*.04*leech)
	if ice>0:
		e.slow=2;e.hits+=1
		if e.hits>=3:e.hits=0;e.freeze=.3+ice*.2 if e.kind=="boss" else .7+ice*.2
	if explosive>0:
		var radius=1.4+explosive*.3
		if frozen and ice>0:radius+=1;e.freeze=0
		blast(e.body.position,radius,amount*(.8 if frozen else .45),e)
	if chain>0:
		var source=e;var used=[e]
		for i in range(min(chain+1,6)):
			var nearest=null;var best=5.5
			for other in enemies:
				var distance=source.body.position.distance_to(other.body.position)
				if other not in used and other.hp>0 and distance<best and has_sight(source.body.position,other.body.position):nearest=other;best=distance
			if nearest==null:break
			beam(source.body.position+Vector3.UP,nearest.body.position+Vector3.UP,Color("88caff"))
			hit_enemy(nearest,amount*.55)
			if nearest.hp<=0:dash_cd=max(0,dash_cd-.3)
			used.append(nearest);source=nearest

func hit_enemy(e, amount, critical=false):
	if e.hp<=0:return
	e.hp-=amount
	floating(e.body.position+Vector3(0,2.3,0),("暴击 " if critical else "")+str(int(ceil(amount))),Color("ffe08b") if critical else Color("b5ffe8"))
	sound("hit")

func kill_enemy(e):
	if e not in enemies:return
	kills+=1
	var pos=e.body.position
	enemies.erase(e);e.body.queue_free()
	if e.kind=="boss":
		coins+=100;add_xp(150);collect_all();finish(true);return
	spawn_loot(pos,false,12,5 if e.kind!="tank" else 8)
	var r=rooms[room_index]
	r.pity=r.get("pity",0)+1
	if rng.randf()<.18 or r.pity>=5:r.pity=0;spawn_loot(pos+Vector3(.25,0,.25),true,0,0)

func hurt(amount):
	if invulnerable>0 or state!="play":return
	hp=max(0,hp-amount);invulnerable=.7
	floating(player.position+Vector3(0,2.3,0),"−"+str(amount),Color("ff769f"));sound("hurt")
	if hp<=0:finish(false)

func spawn_loot(pos, healing=false, experience=0, money=0):
	var node=cube(world,pos+Vector3(0,.25,0),Vector3(.2,.2,.2),Color("8dff9d") if healing else Color("68f8d8"),true)
	loot.append({"node":node,"heal":healing,"xp":experience,"coins":money})

func collect_drop(drop):
	coins+=drop.coins
	add_xp(drop.xp)
	if drop.heal:hp=min(max_hp,hp+16)
	drop.node.queue_free();loot.erase(drop);sound("pick")

func collect_all():
	for drop in loot.duplicate():collect_drop(drop)

func save_room_drops():
	rooms[room_index].drops=[]
	for drop in loot:rooms[room_index].drops.append({"x":drop.node.position.x,"z":drop.node.position.z,"heal":drop.heal,"xp":drop.xp,"coins":drop.coins})

func update_loot(dt):
	for drop in loot.duplicate():
		drop.node.rotation.y+=dt*2
		var distance=drop.node.position.distance_to(player.position)
		if distance<2.5:drop.node.position=drop.node.position.lerp(player.position+Vector3(0,.3,0),min(1,dt*9))
		if distance<.7:collect_drop(drop)

func add_xp(amount):
	xp+=amount
	while xp>=xp_need:
		xp-=xp_need;xp_need+=20;level+=1;pending+=1

func choose_upgrade():
	menu("霓虹强化 / LV.%d" % level,"选一项强化 · 本局持续生效")
	var pool=range(TITLES.size());pool.shuffle()
	var options=pool.slice(0,3)
	if level<=3 and not options.any(func(i):return i in [8,9,10,12]):options[2]=[8,9,10,12][rng.randi_range(0,3)]
	for i in options:
		button(TITLES[i]+"  [当前 %d 层]  " % build_counts.get(i,0)+DESCS[i],apply_upgrade.bind(i))
	sound("level")

func apply_upgrade(i):
	build_counts[i]=build_counts.get(i,0)+1
	match i:
		0:damage_value*=1.3
		1:fire_rate=max(.08,fire_rate*.8)
		2:multi=min(5,multi+1)
		3:max_hp+=25;hp=min(max_hp,hp+40)
		4:speed=min(9,speed*1.15)
		5:collect_all()
		6:pierce+=1
		7:regen+=.7
		8:chain+=1
		9:ice+=1
		10:explosive+=1
		11:leech+=1
		12:orbit=min(4,orbit+1)
		13:crit_chance=min(.8,crit_chance+.15)
	pending=max(0,pending-1)
	resume_game()
	if pending>0:choose_upgrade()

func interact():
	var r=rooms[room_index]
	if not r.clear or player.position.length()>2.5:return
	if r.type=="shop":show_shop();return
	if r.used:return
	if r.type=="treasure":r.used=true;coins+=30;level+=1;pending+=1;choose_upgrade()
	if r.type=="event":
		menu("雨棚下的交易","付出 20 生命，换取一次强化与 25 代币")
		button("接受交易",trade)
		button("安全离开",resume_game)

func trade():
	if hp<=20:resume_game();return
	hp-=20;coins+=25;rooms[room_index].used=true;level+=1;pending+=1;choose_upgrade()

func show_shop():
	menu("深夜补给 / ¥%d" % coins,"拉面不限量 · 枪管每店限购一件\n生命 %d / %d" % [int(hp),int(max_hp)])
	button("热汤拉面 ¥20 · 恢复 50",buy.bind(0)).disabled=coins<20 or hp>=max_hp
	button("改装枪管 ¥30 · 本局伤害 +35%",buy.bind(1)).disabled=coins<30 or not rooms[room_index].barrel
	button("离开摊位",resume_game)

func buy(i):
	var cost=20 if i==0 else 30
	if coins<cost or i==0 and hp>=max_hp or i==1 and not rooms[room_index].barrel:return
	coins-=cost
	if i==0:hp=min(max_hp,hp+50)
	else:damage_value*=1.35;rooms[room_index].barrel=false
	sound("pick");show_shop();update_hud()

func resume_game():state="play";overlay.hide()

func toggle_pause():
	if state=="play":
		menu("夜市暂停营业","继续你的旅途，或放弃本局重新出发。")
		state="pause"
		button("继续游戏",resume_game);button("重新开始",start_game);button("回到主菜单",show_title)
	elif state=="pause":resume_game()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and state=="play":toggle_pause()

func finish(won):
	if settled:return
	settled=true;pending=0
	var reward=5 if won else max(1,kills/8)
	marks+=int(reward);total_kills+=kills
	if won:wins+=1
	if not test_mode:
		var cfg=ConfigFile.new();cfg.set_value("progress","marks",marks);cfg.set_value("progress","kills",total_kills);cfg.set_value("progress","wins",wins);cfg.save("user://progress.cfg")
	menu("天亮了 · 夜市重获自由" if won else "迷失在霓虹里","%s · %02d:%02d · 街区 %d/12 · 击败 %d\n等级 %d · 代币 ¥%d · 获得 %d 印记\n印记只解锁选择，不线性增加生命。" % ["胜利" if won else "下次再来",int(elapsed)/60,int(elapsed)%60,room_index+1,kills,level,coins,reward])
	state="win" if won else "dead"
	button("再次突围",start_game);button("回到主菜单",show_title)
	sound("level" if won else "hurt")

func update_hud():
	hud.text="  霓虹夜市 2.5D   ♥ %d/%d   LV.%d  XP %d/%d   ¥%d   击败 %d   街区 %02d/12" % [hp,max_hp,level,xp,xp_need,coins,kills,room_index+1]
	dash_bar.value=(1-dash_cd/1.5)*100
	var r=rooms[room_index]
	hint.text="WASD/方向键 移动 · 鼠标左键 射击 · 空格 冲刺 · E 交互 · F11 全屏  |  "+("街区安全，沿右侧霓虹出口前进 →" if r.clear else "清除所有敌人，利用摊车与货箱阻挡弹幕")
	if r.type in ["shop","event","treasure"] and not r.used:hint.text+="  |  中央货箱：E"
	boss_hud.text=""
	boss_bar.hide()
	for e in enemies:
		if e.kind=="boss":
			boss_hud.text="夜市之王 %d / %d  %s" % [max(0,e.hp),e.max,"反击窗口" if e.mode=="rest" else "危险预警" if e.mode=="windup" else "冲锋"]
			boss_bar.show();boss_bar.value=max(0,e.hp/e.max*100)
	if is_instance_valid(exit_marker):
		exit_marker.material_override.albedo_color=Color("67f6d5") if r.clear else Color("ff548c")
		exit_marker.material_override.emission=exit_marker.material_override.albedo_color

func floating(pos, text_value, color):
	var label=Label3D.new();world.add_child(label);label.position=pos;label.text=text_value;label.font_size=44;label.pixel_size=.008;label.modulate=color;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	fx.append({"node":label,"life":.65,"kind":"text"})

func beam(a,b,color):
	var distance=a.distance_to(b)
	var node=cube(world,(a+b)/2,Vector3(.06,.06,distance),color,true)
	if distance>.01:node.look_at(b)
	fx.append({"node":node,"life":.14,"kind":"beam"})

func warning_line(pos,dir,color):
	var node=cube(world,pos+dir*3+Vector3(0,.04,0),Vector3(.65,.04,6),color,true)
	node.rotation.y=atan2(dir.x,dir.z)
	fx.append({"node":node,"life":.85,"kind":"warn"})

func ring_warning(pos,radius,life,damaging=false):
	var node=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=.04;node.mesh=mesh;node.material_override=material(Color("ff557d"),true);world.add_child(node);node.position=pos
	fx.append({"node":node,"life":life,"kind":"strike" if damaging else "ring","radius":radius})

func blast(pos,radius,amount,source):
	ring_warning(pos+Vector3(0,.08,0),radius,.15)
	for e in enemies:
		if e!=source and e.hp>0 and e.body.position.distance_to(pos)<radius and has_sight(pos,e.body.position):hit_enemy(e,amount)

func update_fx(dt):
	for effect in fx.duplicate():
		effect.life-=dt
		if effect.kind=="text":effect.node.position.y+=dt*.8
		if effect.life<=0:
			if effect.kind=="strike" and player.position.distance_to(effect.node.position)<effect.radius: hurt(18)
			effect.node.queue_free();fx.erase(effect)
	# Orbit meshes are rebuilt only when their count changes, then rotated each frame.
	if not player.has_meta("orbits") or player.get_meta("orbits").size()!=orbit:
		if player.has_meta("orbits"):
			for node in player.get_meta("orbits"):node.queue_free()
		var nodes=[]
		for i in range(orbit):nodes.append(cube(world,Vector3.ZERO,Vector3(.18,.3,.55),Color("caa8ff"),true))
		player.set_meta("orbits",nodes)
	for i in range(orbit):player.get_meta("orbits")[i].position=player.position+Vector3(cos(elapsed*3+i*TAU/orbit)*1.8,.85,sin(elapsed*3+i*TAU/orbit)*1.8)

func prepare_audio():
	for key in ["shot","hit","hurt","pick","level","dash"]:
		var sample=AudioStreamWAV.new();sample.format=AudioStreamWAV.FORMAT_16_BITS;sample.mix_rate=22050
		var bytes=PackedByteArray();var count=3307;bytes.resize(count*2)
		var frequency={"shot":520,"hit":160,"hurt":80,"pick":900,"level":660,"dash":300}[key]
		for i in range(count):
			var value=int(sin(TAU*frequency*i/22050.0)*7000*pow(1-float(i)/count,2))
			bytes.encode_s16(i*2,value)
		sample.data=bytes;sound_bank[key]=sample

func sound(key):
	if muted or test_mode:return
	var audio=AudioStreamPlayer.new();add_child(audio);audio.stream=sound_bank[key];audio.volume_db=-13;audio.finished.connect(audio.queue_free);audio.play()

func _process(_dt):
	frame_count+=1
	if capture_path!="" and frame_count==45:
		var image=get_viewport().get_texture().get_image();image.save_png(capture_path);get_tree().quit()

func run_tests():
	start_game()
	assert(rooms.size()==12 and rooms[2].type=="shop")
	assert(models.size()==11 and is_instance_valid(player_model))
	var mark_before=marks;marks=50;start_game();assert(max_hp==100);marks=mark_before
	dash_cd=0;try_dash();assert(dash_cd==1.5);try_dash();assert(dash_cd==1.5)
	rooms[0].type="shop";rooms[0].clear=true;hp=20;coins=100;show_shop();buy(0);assert(hp==70 and coins==80);buy(1);assert(coins==50 and not rooms[0].barrel)
	var base_damage=damage_value;buy(1);assert(damage_value==base_damage)
	pending=1;apply_upgrade(8);assert(chain==1);pending=1;apply_upgrade(9);assert(ice==1);pending=1;apply_upgrade(10);assert(explosive==1)
	enter_room(11);assert(enemies.size()==1 and enemies[0].kind=="boss")
	var boss=enemies[0]
	boss.timer=0;boss_behavior(boss,.016);assert(boss.mode=="windup")
	boss.timer=0;boss_behavior(boss,.016);assert(boss.mode=="rest")
	boss.timer=0;boss_behavior(boss,.016);assert(boss.mode=="windup")
	boss.timer=0;boss_behavior(boss,.016);assert(boss.mode=="charge")
	boss.timer=-1;boss_behavior(boss,.016);assert(boss.mode=="rest")
	var before=coins;enemies[0].hp=0;kill_enemy(enemies[0]);assert(state=="win" and coins>=before+100)
	start_game();invulnerable=0;hurt(9999);assert(state=="dead");start_game();assert(state=="play")
	state="menu"
	player.position=Vector3(-7.5,0,-2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.test_move(player.global_transform,Vector3(6,0,0)),"3D cover collision must block movement")
	var ray=PhysicsRayQueryParameters3D.create(Vector3(-8,1,-2),Vector3(-2,1,-2),1)
	assert(not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Cover must block bullets")
	rooms[0].drops=[];spawn_loot(Vector3.ZERO,false,12,5);save_room_drops();assert(rooms[0].drops.size()==1)
	print("NEON25D_TESTS_OK: 11 Blender models, 12 rooms, loadout, dash, repeat shop, upgrades, boss rewards, restart, 3D actor/cover and bullet collision, persisted drops")
	get_tree().quit()
