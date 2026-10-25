extends RefCounted
const NAMES=["灯笼大街","十字食巷","折返货巷","双环摊市","雨庭广场"]
const GOALS=["清剿","三波突围","守住电台","点亮灯塔"]
var zones=[]
var obstacles=[]
func configure(g):
	var layouts=[1,2,3,4];layouts.shuffle()
	var objectives=[1,2,3,0];objectives.shuffle()
	var fight=0
	for i in range(g.rooms.size()):
		var r=g.rooms[i]
		r.layout=0 if i<3 else layouts[(i-3)%4]
		r.goal=0
		if i>2 and r.type=="fight":r.goal=objectives[fight%4];r.layout=layouts[fight%4];fight+=1
		r.progress=0.0;r.wave=1;r.lit=[]
		if r.type=="boss":r.layout=4
func positions(layout):
	match layout:
		0:return [Vector3(-5,0,-2),Vector3(4,0,2.4)]
		1:return [Vector3(-4,0,-3),Vector3(-4,0,3),Vector3(4,0,-3),Vector3(4,0,3)]
		2:return [Vector3(-5,0,-3),Vector3(-5,0,-1.3),Vector3(0,0,3),Vector3(0,0,1.3),Vector3(5,0,-3),Vector3(5,0,-1.3)]
		3:return [Vector3(-5,0,-2.5),Vector3(-5,0,2.5),Vector3(-2,0,-2.5),Vector3(-2,0,2.5),Vector3(3,0,-2.5),Vector3(3,0,2.5),Vector3(6,0,-2.5),Vector3(6,0,2.5)]
		_:return [Vector3(-6,0,-3.5),Vector3(-6,0,3.5),Vector3(6,0,-3.5),Vector3(6,0,3.5)]
func build(g,r):
	zones.clear();obstacles=positions(r.layout)
	if r.type=="boss":obstacles=positions(4)
	for pos in obstacles:
		g.instantiate_model("grill_cart" if r.layout in [1,2] else "crate",pos,1.0 if r.layout in [1,2] else 1.5)
		g.solid(pos+Vector3(0,.75,0),Vector3(1.5,1.5,1.5))
	if r.layout==4 and r.type=="fight":
		for pos in [Vector3(-3,0,-3.8),Vector3(3,0,3.8)]:
			g.cube(g.world,pos+Vector3(0,.02,0),Vector3(3,.04,1.3),Color("287a55"),true)
			g.hazards.append({"pos":pos,"size":Vector2(3,1.3)})
	if r.goal==2:zone(g,Vector3.ZERO,2.0,"电台 · 圈内充能")
	if r.goal==3:
		for pos in [Vector3(-8,0,0),Vector3(0,0,-4.2),Vector3(8,0,0)]:zone(g,pos,1.0,"灯塔 · 靠近点亮")
		for i in r.lit:zones[i].material_override=g.material(Color("7affb3"),true)
func zone(g,pos,radius,title):
	var node=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=radius-.08;mesh.outer_radius=radius;node.mesh=mesh
	node.material_override=g.material(Color("65cffd"),true);g.world.add_child(node);node.position=pos+Vector3(0,.05,0)
	var label=Label3D.new();node.add_child(label);label.position.y=.5;label.text=title;label.font_size=26;label.pixel_size=.009;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	zones.append(node)
func spawn_wave(g,wave):
	var plan=["chase","gun","dash"] if wave==2 else ["tank","gun","chase","dash"]
	for i in range(plan.size()):
		var pos=Vector3(-10 if i%2==0 else 10,0,-3.5 if i<2 else 3.5)
		g.spawn_enemy(plan[i],pos);g.enemies[-1].freeze=1.0
		g.ring_warning(pos+Vector3(0,.05,0),.7,1.0)
	g.floating(Vector3(0,2,0),"第 %d 波 · 敌人即将行动"%wave,Color("ffd786"))
func tick(g,dt):
	var r=g.rooms[g.room_index]
	if r.clear or r.type!="fight":return
	if r.goal==1 and g.enemies.is_empty() and r.wave<3:
		r.wave+=1;spawn_wave(g,r.wave)
	if r.goal==2:
		if g.player.position.distance_to(Vector3.ZERO)<2:r.progress=min(12.0,r.progress+dt)
		if r.progress>=6 and r.wave==1:r.wave=2;spawn_wave(g,2)
	if r.goal==3:
		for i in range(zones.size()):
			if i not in r.lit and g.player.position.distance_to(zones[i].position)<1:
				r.lit.append(i);g.sound("pick");zones[i].material_override=g.material(Color("7affb3"),true)
	for i in range(zones.size()):
		if r.goal==2:zones[i].get_child(0).text="电台充能 %d / 12 秒"%int(r.progress)
		elif i in r.lit:zones[i].get_child(0).text="已点亮"
func complete(r):
	return (r.goal==0 or (r.goal==1 and r.wave>=3) or (r.goal==2 and r.progress>=12) or (r.goal==3 and r.lit.size()==3))
func description(r):
	if r.type=="boss":return "祭典终场 · 三幕决战 · 青线指向弹雨安全方向"
	var detail=""
	if r.goal==1:detail=" · 第 %d/3 波"%r.wave
	if r.goal==2:detail=" · 圈内充能 %d/12 秒"%int(r.progress)
	if r.goal==3:detail=" · 灯塔 %d/3"%r.lit.size()
	return NAMES[r.layout]+" · "+GOALS[r.goal]+detail+" · 完成目标并清敌开门"
