extends RefCounted
const FIELDS=["hp","max_hp","speed","damage_value","fire_rate","coins","kills","level","xp","xp_need","pending","multi","pierce","chain","ice","explosive","leech","orbit","regen","crit_chance","elapsed","dash_cd","shot_cd","build_counts","storm","crystal","magnet_radius","run_damage","run_crits","run_floor","chosen_runner","chosen_weapon","upgrade_choices"]
var path="user://run_save.cfg"
var active=false
var restoring=false
var clock=0.0
var error=""
func allowed(g):return not g.test_mode and g.capture_path==""
func snapshot(g):
	g.save_room_drops()
	var data={"version":1,"rooms":g.rooms.duplicate(true),"room":g.room_index,"position":g.player.position,"stats":{},"enemies":[],"rng":g.rng.state}
	for key in FIELDS:data.stats[key]=g.get(key)
	for e in g.enemies:
		if e.hp<=0:continue
		data.enemies.append({"kind":e.kind,"pos":e.body.position,"hp":e.hp,"max":e.max,"phase":e.get("phase",1),"move":e.move,"hits":e.hits})
	data.stats=data.stats.duplicate(true)
	return data
func number(value):return (value is int or value is float) and is_finite(float(value))
func valid(data):
	if not data is Dictionary or data.get("version")!=1:return false
	if not data.get("rooms") is Array or data.rooms.size()!=12:return false
	if not data.get("stats") is Dictionary or not data.get("enemies") is Array:return false
	if not data.get("position") is Vector3 or not data.get("room") is int or data.room<0 or data.room>=12:return false
	for key in FIELDS:
		if not data.stats.has(key):return false
		if key not in ["build_counts","upgrade_choices"] and not number(data.stats[key]):return false
	if not data.stats.build_counts is Dictionary or not data.stats.upgrade_choices is Array:return false
	if data.stats.hp<=0 or data.stats.max_hp<=0:return false
	if data.stats.chosen_runner not in range(3) or data.stats.chosen_weapon not in range(3):return false
	for choice in data.stats.upgrade_choices:
		if choice not in range(16):return false
	for key in data.stats.build_counts:
		if key not in range(16) or not number(data.stats.build_counts[key]):return false
	for r in data.rooms:
		if not r is Dictionary:return false
		for key in ["type","clear","used","barrel","visited","rewarded","drops","layout","goal","progress","wave","lit"]:
			if not r.has(key):return false
		if not r.drops is Array or not r.lit is Array or not number(r.progress) or not number(r.wave):return false
		for flag in ["clear","used","barrel","visited","rewarded"]:
			if not r[flag] is bool:return false
		for lit in r.lit:
			if lit not in range(3):return false
		for drop in r.drops:
			if not drop is Dictionary:return false
			for key in ["x","z","xp","coins"]:
				if not number(drop.get(key)):return false
			if not drop.get("heal") is bool:return false
		if r.type not in ["fight","boss","shop","treasure","event"] or r.layout not in range(5) or r.goal not in range(4):return false
	for e in data.enemies:
		if not e is Dictionary:return false
		for key in ["kind","pos","hp","max","phase","move","hits"]:
			if not e.has(key):return false
		if e.kind not in ["chase","gun","tank","dash","boss"] or not e.pos is Vector3:return false
		if not number(e.hp) or not number(e.max) or e.hp<=0 or e.max<=0 or not number(e.hits):return false
		if e.phase not in [1,2,3] or e.move not in range(4):return false
	return true
func read_file(file):
	var cfg=ConfigFile.new()
	if cfg.load(file)!=OK:return {}
	var data=cfg.get_value("run","data",{})
	return data if valid(data) else {}
func read():
	var data=read_file(path)
	if data.is_empty():data=read_file(path+".bak")
	if data.is_empty():data=read_file(path+".tmp")
	return data
func write_data(data):
	var cfg=ConfigFile.new();cfg.set_value("run","data",data)
	if cfg.save(path+".tmp")!=OK:error="无法写入续局存档，请检查磁盘空间与权限。";return false
	if read_file(path+".tmp").is_empty():error="续局存档校验失败。";return false
	if FileAccess.file_exists(path):
		if not read_file(path).is_empty():
			if DirAccess.copy_absolute(path,path+".bak")!=OK:error="无法创建续局备份。";return false
	# Replace on Windows only after a validated temporary file and backup exist.
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:error="无法替换续局存档。";return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:error="无法提交续局存档，旧备份仍保留。";return false
	error="";return true
func save(g):
	if not active or restoring or not allowed(g):return true
	return write_data(snapshot(g))
func discard(g):
	if not allowed(g):return
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
func restore(g,data):
	if not valid(data):return false
	restoring=true
	g.rooms=data.rooms.duplicate(true)
	g.enter_room(data.room)
	for e in g.enemies:e.body.free()
	g.enemies.clear()
	for info in data.enemies:
		g.spawn_enemy(info.kind,info.pos)
		var e=g.enemies[-1];e.hp=info.hp;e.max=info.max;e.phase=info.phase;e.move=info.move;e.hits=info.hits
		e.mode="rest" if e.kind=="boss" else "seek";e.timer=1.5;e.cd=1.5;e.freeze=.8
		if e.kind=="boss":
			for light in g.world.find_children("*","OmniLight3D",true,false):light.light_color=[Color("6cf3e1"),Color("bb80ff"),Color("ff648c")][e.phase-1]
	for key in FIELDS:g.set(key,data.stats[key])
	g.rng.state=data.get("rng",g.rng.state);g.player.position=data.position
	g.dash_time=0;g.invulnerable=1.5;g.attack_gap=1.5;g.settled=false
	active=true;restoring=false;clock=0
	g.resume_game();g.update_hud()
	if g.pending>0:g.choose_upgrade()
	return true
func tick(g,dt):
	if not active or g.state!="play":return
	clock+=dt
	if clock>=15:clock=0;save(g)
