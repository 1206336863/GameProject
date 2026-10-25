extends RefCounted
func run(g):
	g.start_game();g.state="menu";g.coins=87;g.hp=43;g.chain=2;g.build_counts={8:2}
	g.rooms[0].goal=3;g.rooms[0].lit=[0,2];g.rooms[0].barrel=false
	g.player.position=Vector3(-7,0,1);g.enemies[0].hp=17
	g.pending=1;g.upgrade_choices=[8,9,10]
	g.spawn_loot(Vector3(1,0,0),true,0,0)
	var data=g.session.snapshot(g)
	var cfg=ConfigFile.new();cfg.set_value("run","data",data)
	var decoded=ConfigFile.new();assert(decoded.parse(cfg.encode_to_text())==OK)
	data=decoded.get_value("run","data")
	assert(g.session.valid(data) and not g.session.valid({"version":99}))
	var original_path=g.session.path
	g.session.path="user://comfort-test-"+str(Time.get_ticks_usec())+".cfg"
	assert(g.session.write_data(data));assert(g.session.write_data(data))
	var broken=FileAccess.open(g.session.path,FileAccess.WRITE);broken.store_string("not a config file");broken.close()
	assert(not g.session.read().is_empty(),"Corrupt primary must fall back to validated backup")
	assert(g.session.restore(g,g.session.read()))
	assert(g.coins==87 and g.hp==43 and g.chain==2 and g.enemies[0].hp==17)
	assert(g.rooms[0].lit==[0,2] and not g.rooms[0].barrel)
	assert(g.pending==1 and g.upgrade_choices==[8,9,10],"Upgrade choices cannot reroll by reloading")
	assert(g.player.position==Vector3(-7,0,1) and g.invulnerable>=1.5 and g.bullets.is_empty())
	assert(g.loot.size()>0 and g.state=="menu")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(g.session.path+suffix):DirAccess.remove_absolute(g.session.path+suffix)
	g.session.path=original_path
	# Boss phase and alive-health persist while in-progress attacks safely reset.
	g.enter_room(11);g.state="menu";g.enemies[0].phase=3;g.enemies[0].hp=201;g.enemies[0].mode="charge"
	data=g.session.snapshot(g);assert(g.session.restore(g,data))
	assert(g.enemies[0].phase==3 and g.enemies[0].hp==201 and g.enemies[0].mode=="rest")
	# Actions are exercised through Godot's input map/event matching.
	assert(not g.options.bind_key("dash",KEY_W));assert(not g.options.bind_key("dash",KEY_ESCAPE))
	assert(g.options.bind_key("dash",KEY_Q))
	var key=InputEventKey.new();key.physical_keycode=KEY_Q;key.pressed=true
	assert(InputMap.event_is_action(key,"dash"))
	var pad=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_LEFT_SHOULDER;pad.pressed=true
	assert(InputMap.event_is_action(pad,"dash"))
	var trigger=InputEventJoypadMotion.new();trigger.axis=JOY_AXIS_TRIGGER_RIGHT;trigger.axis_value=1
	assert(InputMap.event_is_action(trigger,"fire"))
	Input.action_press("move_right");assert(g.keyboard_movement().x>.9);Input.action_release("move_right")
	g.state="play";g.options.pad=3;g.options.pad_active=true;g.joy_connection(3,false)
	assert(g.state=="pause" and not g.options.pad_active)
	# Write/reload preferences only in a unique test file, never the user's profile.
	var Settings=load("res://scripts/player_options.gd")
	var original_settings=g.options.settings_path;g.options.settings_path="user://comfort-settings-"+str(Time.get_ticks_usec())+".cfg"
	g.options.volumes.Combat=.25;g.options.volumes.Interface=0;g.options.quality=0
	g.options.apply_audio(g);g.options.apply_quality(g)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Interface")))
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Combat"))),.25))
	assert(is_equal_approx(g.get_viewport().scaling_3d_scale,.7))
	for particles in g.world.find_children("*","GPUParticles3D",true,false):assert(not particles.emitting)
	g.test_mode=false;g.options.persist(g);g.test_mode=true
	var saved=ConfigFile.new();assert(saved.load(g.options.settings_path)==OK)
	assert(saved.get_value("audio","Combat")==.25 and saved.get_value("keys","dash")==KEY_Q and saved.get_value("video","quality")==0)
	var reloaded=Settings.new();reloaded.load_config(g,saved)
	assert(reloaded.bindings.dash==KEY_Q and reloaded.quality==0 and reloaded.volumes.Combat==.25)
	g.options.show(g,true);await g.get_tree().process_frame
	assert(g.get_viewport().gui_get_focus_owner()!=null,"Menus need initial controller/keyboard focus")
	var confirm=InputEventJoypadButton.new();confirm.button_index=JOY_BUTTON_A;confirm.pressed=true
	assert(InputMap.event_is_action(confirm,"ui_accept"))
	DirAccess.remove_absolute(g.options.settings_path);g.options.settings_path=original_settings
	g.options.bindings=Settings.DEFAULTS.duplicate();g.options.apply_inputs();g.options.quality=2;g.options.volumes={"Master":.8,"Combat":.8,"Interface":.7,"Ambience":.35};g.options.apply_audio(g);g.options.apply_quality(g)
	g.options.screen="";g.session.active=false
	print("NEON25D_COMFORT_TESTS_OK: serialized run/loot/objectives/boss/upgrade resume, backup recovery, key conflicts, joy bindings/disconnect pause, audio buses, quality and durable preferences")
	return true
