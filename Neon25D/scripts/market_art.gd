extends RefCounted
## Scene dressing uses the same navigable interior as the authored collision layout.
func build(g, room):
	var root=g.world
	var floor_mesh=root.get_child(0)
	var wet=ShaderMaterial.new()
	wet.shader=load("res://assets/wet_asphalt.gdshader")
	floor_mesh.material_override=wet
	# Kerbs, gutters, short road markings and drains break up the old uniform grid.
	for z in [-5.55,5.55]:
		g.cube(root,Vector3(0,.035,z),Vector3(26,.07,.16),Color("3b3c50"))
		for x in range(-12,13,2):
			g.cube(root,Vector3(x,.01,z*.88),Vector3(.8,.015,.055),Color("8e7e54"))
		for x in [-8.5,0,8.5]:
			g.cube(root,Vector3(x,.015,z*.93),Vector3(.75,.03,.28),Color("111524"))
			for j in range(6):g.cube(root,Vector3(x-.3+j*.12,.04,z*.93),Vector3(.025,.01,.26),Color("4b5062"))
	# Facades frame the street: silhouettes, windows and wall-mounted light boxes.
	for side in [-1,1]:
		# Near-side facades are cut away so they cannot occlude the playable street.
		if side==1:continue
		for i in range(7):
			var x=-12+i*4
			var height=3.7+float((i+room.layout)%3)*.65
			g.cube(root,Vector3(x,height/2,side*9),Vector3(3.8,height,2),Color("172139") if i%2 else Color("251d35"))
			for wx in [-.9,.9]:
				for y in [2.7,3.65]:
					g.cube(root,Vector3(x+wx,y,side*7.94),Vector3(.48,.65,.04),Color("6a5b4a") if i%3 else Color("428c93"),i%3==0)
	# Props sit at the street's edge, leaving entrance, interaction point and exits open.
	for pos in [Vector3(-9.1,0,-5),Vector3(8.7,0,4.9)]:
		g.instantiate_model("plant",pos,.85)
	for pos in [Vector3(-2,0,-5),Vector3(10,0,-5)]:g.instantiate_model("vending",pos,.85)
	for pos in [Vector3(1.3,0,5),Vector3(-8,0,5)]:g.instantiate_model("bench",pos,.8)
	g.instantiate_model("trash_bin",Vector3(3,0,-5),.8)
	for x in [-12.6,12.6]:
		var gate=g.instantiate_model("market_gate",Vector3(x,0,0),.85)
		gate.rotation.y=PI/2
	# Suspended cables with a visible sag, warm lanterns alternate with cool shop signs.
	for z in [-5.75,5.9]:
		for i in range(24):
			var x=-12+float(i)
			var a=Vector3(x,3.8-.55*sin((x+12)/24*PI),z)
			var b=Vector3(x+1,3.8-.55*sin((x+13)/24*PI),z)
			var cable=g.cube(root,(a+b)/2,Vector3(.018,.018,a.distance_to(b)),Color("181523"))
			cable.look_at(b)
		for i in range(9):
			var x=-11+float(i)*2.7
			g.instantiate_model("lantern",Vector3(x,3.6-.5*sin((x+12)/24*PI),z),.65)
	# Restrained rain streaks and steam above food stalls.
	var rain=GPUParticles3D.new()
	rain.name="Rain";root.add_child(rain)
	rain.position=Vector3(0,7,0);rain.amount=300;rain.lifetime=1.5
	rain.visibility_aabb=AABB(Vector3(-16,-10,-12),Vector3(32,20,24))
	var process=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(14,0,9)
	process.direction=Vector3(-.12,-1,.05);process.spread=2
	process.initial_velocity_min=9;process.initial_velocity_max=14;process.gravity=Vector3(0,-8,0)
	process.color=Color(.43,.64,.78,.22)
	rain.process_material=process
	var mesh=BoxMesh.new();mesh.size=Vector3(.014,.36,.014)
	var mat=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.vertex_color_use_as_albedo=true;mat.albedo_color=Color(.5,.7,.85,.28);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material=mat;rain.draw_pass_1=mesh
	for x in [-11.8,-1.6,8.6]:
		var steam=GPUParticles3D.new();root.add_child(steam);steam.position=Vector3(x,1.6,-6.5);steam.amount=18;steam.lifetime=1.5
		var smoke=ParticleProcessMaterial.new();smoke.direction=Vector3(0,1,0);smoke.spread=15;smoke.gravity=Vector3(.05,.1,0);smoke.initial_velocity_min=.15;smoke.initial_velocity_max=.4;smoke.scale_min=.1;smoke.scale_max=.3;smoke.color=Color(.6,.65,.75,.16);steam.process_material=smoke
		var puff=SphereMesh.new();puff.radius=.15;puff.height=.3;var smat=StandardMaterial3D.new();smat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;smat.albedo_color=Color(.5,.6,.7,.1);smat.vertex_color_use_as_albedo=true;puff.material=smat;steam.draw_pass_1=puff
