extends RefCounted
## Transient presentation never changes collision geometry or the gameplay clock.
var occluders=[]
var debris=[]
var recoil=0.0
var trauma=0.0
var rng=RandomNumberGenerator.new()
var outlined=[]
var outline:ShaderMaterial
var fading_count=0

func reset(g):
	occluders.clear();debris.clear();outlined.clear();recoil=0;trauma=0;fading_count=0
	if is_instance_valid(g.camera):g.camera.h_offset=0;g.camera.v_offset=0
	rng.randomize()
	var shader=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, cull_front, depth_test_disabled, shadows_disabled; void vertex(){VERTEX+=NORMAL*0.045;} void fragment(){ALBEDO=vec3(0.25,1.0,0.85); ALPHA=0.75;}"
	outline=ShaderMaterial.new();outline.shader=shader

func collect_occluders(root):
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("occlusion_registered"):continue
		var box=mesh.get_aabb()
		if box.size.y<.15 or mesh.global_position.y+box.end.y<.6:continue
		var mats=[]
		for i in range(mesh.mesh.get_surface_count()):
			var original=mesh.get_active_material(i)
			if original is StandardMaterial3D:
				var copy=original.duplicate();mesh.set_surface_override_material(i,copy);mats.append([copy,copy.albedo_color,copy.transparency])
		if not mats.is_empty():
			mesh.material_override=null;mesh.set_meta("occlusion_registered",true)
			occluders.append({"mesh":mesh,"inverse":mesh.global_transform.affine_inverse(),"box":box.grow(.08),"materials":mats,"alpha":1.0})

func blocks_view(item, origin, target):
	var inverse=item.inverse
	return item.box.intersects_segment(inverse*origin,inverse*target)!=null

func update(g,dt):
	if not is_instance_valid(g.player):return
	var blocked=false;fading_count=0
	for item in occluders:
		if not is_instance_valid(item.mesh):continue
		var hit=false
		for height in [.45,1.05,1.65]:
			var target=g.player.global_position+Vector3.UP*height
			var origin=g.camera.project_ray_origin(g.camera.unproject_position(target))
			if blocks_view(item,origin,target):hit=true;break
		blocked=blocked or hit
		var previous_alpha=item.alpha
		item.alpha=move_toward(item.alpha,.18 if hit else 1.0,dt*6)
		if item.alpha<.999:fading_count+=1
		if is_equal_approx(previous_alpha,item.alpha):continue
		for data in item.materials:
			data[0].transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if item.alpha<.999 else data[2]
			var color=data[1];color.a*=item.alpha;data[0].albedo_color=color
	if outlined.is_empty() and is_instance_valid(g.player_model):outlined=g.player_model.find_children("*","MeshInstance3D",true,false)
	for mesh in outlined:
		if is_instance_valid(mesh):mesh.material_overlay=outline if blocked else null
	if dt<=0:g.camera.h_offset=0;g.camera.v_offset=0;return
	recoil=move_toward(recoil,0,dt*2.6)
	g.player_model.position.z=-recoil*cos(g.player_model.rotation.y)
	g.player_model.position.x=-recoil*sin(g.player_model.rotation.y)
	trauma=move_toward(trauma,0,dt*.9)
	g.camera.h_offset=rng.randf_range(-1,1)*trauma*g.shake_strength
	g.camera.v_offset=rng.randf_range(-1,1)*trauma*g.shake_strength*.6
	for item in debris.duplicate():
		item.life-=dt
		if not is_instance_valid(item.node):debris.erase(item);continue
		item.velocity.y-=9*dt;item.node.position+=item.velocity*dt
		item.node.rotate_x(dt*8);item.node.rotate_z(dt*5)
		if item.node.position.y<.06:
			item.node.position.y=.06;item.velocity*=.35;item.velocity.y=abs(item.velocity.y)
		if item.life<=0:item.node.queue_free();debris.erase(item)

func kick(amount):trauma=min(.28,trauma+amount)

func fire(g,pos,dir,enemy):
	var flash=g.cube(g.world,pos+Vector3.UP+dir*.65,Vector3(.22,.18,.5),Color("ffb875") if enemy else Color("c8fff0"),true)
	flash.rotation.y=atan2(dir.x,dir.z)
	g.fx.append({"node":flash,"life":.055,"kind":"flash"})
	if not enemy:recoil=min(.15,recoil+.1);kick(.025)
	var casing=g.cube(g.world,pos+Vector3.UP,Vector3(.045,.1,.045),Color("e6b85d"))
	var side=Vector3(dir.z,0,-dir.x)
	add_debris(casing,side*2+Vector3.UP*2,.85)

func add_debris(node,velocity,life):
	if debris.size()>=120:
		var oldest=debris.pop_front()
		if is_instance_valid(oldest.node):oldest.node.queue_free()
	debris.append({"node":node,"velocity":velocity,"life":life})

func impact(g,pos,color,count):
	for i in range(count):
		var spark=g.cube(g.world,pos,Vector3(.035,.035,.15),color,true)
		add_debris(spark,Vector3(rng.randf_range(-3,3),rng.randf_range(.5,3),rng.randf_range(-3,3)),.22+rng.randf()*.15)

func telegraph(g,e):
	if e.kind=="boss":return
	var active=e.mode in ["windup","aim","volley"]
	if not active:
		if e.has("warning") and is_instance_valid(e.warning):e.warning.queue_free();e.erase("warning")
		return
	if not e.has("warning") or not is_instance_valid(e.warning):
		if e.kind=="dash":
			var node=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=1.12;mesh.outer_radius=1.25;node.mesh=mesh;g.world.add_child(node);e.warning=node
		else:e.warning=g.cube(g.world,Vector3.ZERO,Vector3(.85 if e.kind=="tank" else .08,.025,7.15 if e.kind=="tank" else 10),Color("ffb56b"),true)
		var mat=g.material(Color("ffb56b"),true);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color.a=.28 if e.kind=="tank" else .8;mat.no_depth_test=true;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;e.warning.material_override=mat
	if e.kind=="dash":e.warning.position=e.target+Vector3(0,.08,0)
	else:
		var reach=7.15 if e.kind=="tank" else 10.0
		e.warning.position=e.body.position+e.dir*reach*.5+Vector3(0,.06,0);e.warning.rotation.y=atan2(e.dir.x,e.dir.z)
