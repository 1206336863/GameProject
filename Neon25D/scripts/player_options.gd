extends RefCounted
const DEFAULTS={"move_up":KEY_W,"move_down":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"dash":KEY_SPACE,"interact":KEY_E,"fire":KEY_F}
const LABELS={"move_up":"上移","move_down":"下移","move_left":"左移","move_right":"右移","dash":"冲刺","interact":"交互","fire":"射击（鼠标左键始终可用）"}
var bindings=DEFAULTS.duplicate()
var volumes={"Master":.8,"Combat":.8,"Interface":.7,"Ambience":.35}
var quality=2
var waiting=""
var screen=""
var from_pause=false
var pad=-1
var pad_active=false
var last_aim=Vector3.RIGHT
var ambience:AudioStreamPlayer
var settings_path="user://preferences.cfg"
func setup(g):
	for name in ["Combat","Interface","Ambience"]:
		if AudioServer.get_bus_index(name)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	var cfg=ConfigFile.new()
	if not g.test_mode and cfg.load(settings_path)==OK:
		load_config(g,cfg)
	apply_inputs();apply_audio(g);apply_quality(g);create_ambience(g)
func load_config(g,cfg):
	for name in volumes:volumes[name]=clamp(float(cfg.get_value("audio",name,volumes[name])),0,1)
	quality=clamp(int(cfg.get_value("video","quality",2)),0,2)
	g.shake_strength=clamp(float(cfg.get_value("video","shake",1.0)),0,1)
	for action in bindings:bindings[action]=int(cfg.get_value("keys",action,bindings[action]))
func persist(g):
	if g.test_mode or g.capture_path!="":return
	var cfg=ConfigFile.new()
	for name in volumes:cfg.set_value("audio",name,volumes[name])
	for action in bindings:cfg.set_value("keys",action,bindings[action])
	cfg.set_value("video","quality",quality);cfg.set_value("video","shake",g.shake_strength)
	if cfg.save(settings_path)!=OK:g.hint.text="设置保存失败，请检查磁盘权限。"
func apply_inputs():
	for action in bindings:
		if not InputMap.has_action(action):InputMap.add_action(action,.22)
		InputMap.action_erase_events(action)
		var key=InputEventKey.new();key.physical_keycode=bindings[action];InputMap.action_add_event(action,key)
	for action in ["move_left","move_right","move_up","move_down"]:
		var event=InputEventJoypadMotion.new();event.device=-1;event.axis=JOY_AXIS_LEFT_X if action in ["move_left","move_right"] else JOY_AXIS_LEFT_Y;event.axis_value=-1 if action in ["move_left","move_up"] else 1
		InputMap.action_add_event(action,event)
		if bindings[action]==DEFAULTS[action]:
			var key=InputEventKey.new();key.physical_keycode={"move_left":KEY_LEFT,"move_right":KEY_RIGHT,"move_up":KEY_UP,"move_down":KEY_DOWN}[action];InputMap.action_add_event(action,key)
	for action in ["dash","interact","fire"]:
		var event=InputEventJoypadButton.new();event.device=-1;event.button_index={"dash":JOY_BUTTON_LEFT_SHOULDER,"interact":JOY_BUTTON_A,"fire":JOY_BUTTON_RIGHT_SHOULDER}[action];InputMap.action_add_event(action,event)
	var trigger=InputEventJoypadMotion.new();trigger.device=-1;trigger.axis=JOY_AXIS_TRIGGER_RIGHT;trigger.axis_value=1;InputMap.action_add_event("fire",trigger)
	var mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;InputMap.action_add_event("fire",mouse)
	if not InputMap.has_action("pause_game"):InputMap.add_action("pause_game")
	InputMap.action_erase_events("pause_game")
	var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;InputMap.action_add_event("pause_game",escape)
	var start=InputEventJoypadButton.new();start.device=-1;start.button_index=JOY_BUTTON_START;InputMap.action_add_event("pause_game",start)
	for action in ["ui_accept","ui_cancel","ui_left","ui_right","ui_up","ui_down"]:
		if not InputMap.has_action(action):InputMap.add_action(action,.5)
		var event=InputEventJoypadButton.new();event.device=-1
		event.button_index={"ui_accept":JOY_BUTTON_A,"ui_cancel":JOY_BUTTON_B,"ui_left":JOY_BUTTON_DPAD_LEFT,"ui_right":JOY_BUTTON_DPAD_RIGHT,"ui_up":JOY_BUTTON_DPAD_UP,"ui_down":JOY_BUTTON_DPAD_DOWN}[action]
		if not InputMap.action_has_event(action,event):InputMap.action_add_event(action,event)
		if action in ["ui_left","ui_right","ui_up","ui_down"]:
			var stick=InputEventJoypadMotion.new();stick.device=-1;stick.axis=JOY_AXIS_LEFT_X if action in ["ui_left","ui_right"] else JOY_AXIS_LEFT_Y;stick.axis_value=-1 if action in ["ui_left","ui_up"] else 1
			if not InputMap.action_has_event(action,stick):InputMap.action_add_event(action,stick)
func bind_key(action,key):
	if key in [KEY_ESCAPE,KEY_F11,KEY_ENTER,KEY_KP_ENTER,0]:return false
	for other in bindings:
		if other!=action:
			for event in InputMap.action_get_events(other):
				if event is InputEventKey and event.physical_keycode==key:return false
	bindings[action]=key;apply_inputs();return true
func handle(g,event):
	if event is InputEventJoypadMotion and abs(event.axis_value)>.22:pad=event.device;pad_active=true
	if event is InputEventJoypadButton:pad=event.device;pad_active=true
	if event is InputEventMouseMotion or event is InputEventKey:pad_active=false
	if waiting!="" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:waiting="";show_bindings(g)
		elif bind_key(waiting,event.physical_keycode):waiting="";persist(g);show_bindings(g)
		else:g.menu_box.get_child(1).text="该按键已占用或保留，请换一个键；Esc 取消。"
		g.get_viewport().set_input_as_handled()
func aim():
	if not pad_active or pad<0:return Vector3.ZERO
	var v=Vector2(Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X),Input.get_joy_axis(pad,JOY_AXIS_RIGHT_Y))
	if v.length()>.22:last_aim=Vector3(v.x,0,v.y).normalized()
	return last_aim
func apply_audio(g):
	for name in volumes:
		var index=AudioServer.get_bus_index(name)
		AudioServer.set_bus_volume_db(index,linear_to_db(max(.0001,volumes[name])))
		AudioServer.set_bus_mute(index,volumes[name]<=0 or (name=="Master" and g.muted))
func create_ambience(g):
	if g.test_mode:return
	var sample=AudioStreamWAV.new();sample.format=AudioStreamWAV.FORMAT_16_BITS;sample.mix_rate=22050
	var bytes=PackedByteArray();bytes.resize(44100);var random=RandomNumberGenerator.new();random.seed=42;var filtered=0.0
	for i in range(22050):
		filtered=lerp(filtered,random.randf_range(-1,1),.12);bytes.encode_s16(i*2,int(filtered*1500))
	sample.data=bytes;sample.loop_mode=AudioStreamWAV.LOOP_FORWARD;sample.loop_end=22050
	ambience=AudioStreamPlayer.new();g.add_child(ambience);ambience.bus="Ambience";ambience.stream=sample;ambience.play()
func apply_quality(g):
	var compatibility=RenderingServer.get_current_rendering_method()=="gl_compatibility"
	for env in g.get_children():
		if env is WorldEnvironment:
			env.environment.glow_enabled=quality>0 and not compatibility
			env.environment.ssao_enabled=quality==2 and not compatibility
	g.get_viewport().scaling_3d_scale=[.7,.85,1.0][quality]
	g.get_viewport().msaa_3d=Viewport.MSAA_2X if quality==2 else Viewport.MSAA_DISABLED
	for light in g.find_children("*","Light3D",true,false):light.shadow_enabled=quality==2 and light is DirectionalLight3D
	if is_instance_valid(g.world):
		for particles in g.world.find_children("*","GPUParticles3D",true,false):
			particles.emitting=quality>0;particles.amount_ratio=[.2,.6,1.0][quality]
func show(g,paused=false):
	from_pause=paused;screen="settings";waiting=""
	g.menu("设置 / 长途夜行","即时生效并保存 · 手柄：左摇杆移动 / 右摇杆瞄准\nRT 或 RB 射击 · LB 冲刺 · A 交互/确认 · Start 暂停")
	for name in volumes:
		var row=HBoxContainer.new();g.menu_box.add_child(row)
		var label=Label.new();label.custom_minimum_size.x=180;label.text={"Master":"总音量","Combat":"战斗音效","Interface":"拾取与升级","Ambience":"夜雨环境"}[name];row.add_child(label)
		var slider=HSlider.new();slider.custom_minimum_size=Vector2(350,32);slider.min_value=0;slider.max_value=100;slider.step=5;slider.value=volumes[name]*100;row.add_child(slider)
		var percent=Label.new();percent.text=str(int(slider.value))+"%";row.add_child(percent)
		slider.value_changed.connect(func(value):volumes[name]=value/100;percent.text=str(int(value))+"%";apply_audio(g);persist(g))
	g.button("画质："+["流畅 · 70% 分辨率 / 关闭粒子","均衡 · 85% / 精简特效","精致 · 100% / 阴影与抗锯齿"][quality],func():quality=(quality+1)%3;apply_quality(g);persist(g);show(g,from_pause))
	g.button("震动："+str(g.shake_strength),func():g.shake_strength=0.0 if g.shake_strength==1 else .35 if g.shake_strength==0 else 1.0;persist(g);show(g,from_pause))
	g.button("按键重绑定",func():show_bindings(g))
	g.button("返回",func():back(g))
func show_bindings(g):
	screen="bindings"
	g.menu("按键重绑定","选择动作后按新键 · 重复键拒绝绑定 · Esc 取消\nEsc / F11 / Enter 保留；重绑移动会替换对应默认方向键。")
	for action in bindings:
		g.button(LABELS[action]+"："+OS.get_keycode_string(bindings[action]),func():waiting=action;g.menu_box.get_child(1).text="正在绑定「"+LABELS[action]+"」：请按新键，Esc 取消。")
	g.button("恢复默认按键",func():bindings=DEFAULTS.duplicate();apply_inputs();persist(g);show_bindings(g))
	g.button("返回设置",func():show(g,from_pause))
func back(g):
	if screen=="bindings":waiting="";show(g,from_pause);return
	screen="";waiting=""
	if from_pause:g.state="play";g.toggle_pause()
	else:g.show_title()

func control_hint():
	if pad_active:return "手柄 · 左摇杆移动 / 右摇杆瞄准 · RT/RB 射击 · LB 冲刺 · A 交互 · Start 暂停"
	var keys=""
	for action in ["move_up","move_left","move_down","move_right"]:keys+=OS.get_keycode_string(bindings[action])+" "
	return keys+"移动 · 鼠标左键/"+OS.get_keycode_string(bindings.fire)+" 射击 · "+OS.get_keycode_string(bindings.dash)+" 冲刺 · "+OS.get_keycode_string(bindings.interact)+" 交互 · Esc 暂停"
