extends RefCounted
## Imported skin/skeleton clips; separate upper-body player preserves walking while firing.
var model: Node3D
var base: AnimationPlayer
var upper: AnimationPlayer
var skeleton: Skeleton3D
var clips = {}
var lock_time = 0.0
var priority = 0
var dying = false
var enabled_state=true

func _init(root):
	model = root
	var players = root.find_children("*","AnimationPlayer",true,false)
	var bones = root.find_children("*","Skeleton3D",true,false)
	assert(not players.is_empty() and not bones.is_empty(),"Skinned actor must contain imported skeleton and animations")
	base = players[0];skeleton = bones[0]
	for name in base.get_animation_list():
		var short_name = str(name).get_slice("/",str(name).get_slice_count("/")-1)
		clips[short_name] = name
		base.get_animation(name).loop_mode = Animation.LOOP_LINEAR if short_name in ["Idle","Walk"] else Animation.LOOP_NONE
	upper = AnimationPlayer.new()
	upper.name = "UpperBodyRecoil"
	base.get_parent().add_child(upper)
	upper.root_node = base.root_node
	upper.process_priority = base.process_priority+1
	var shoot = base.get_animation(clips.Shoot).duplicate(true)
	for i in range(shoot.get_track_count()-1,-1,-1):
		var path = str(shoot.track_get_path(i))
		if not ("spine" in path or "upper_arm" in path or "forearm" in path or "hand" in path):shoot.remove_track(i)
	var library = AnimationLibrary.new();library.add_animation("Shoot",shoot)
	upper.add_animation_library("",library)
	base.play(clips.Idle)

func tick(moving,dt,frozen=false):
	if not is_instance_valid(model):return
	base.speed_scale = 0 if frozen else 1
	upper.speed_scale = 0 if frozen else 1
	if frozen or dying:return
	lock_time = max(0,lock_time-dt)
	if lock_time>0:return
	priority = 0
	var desired = "Walk" if moving else "Idle"
	if base.current_animation!=clips[desired] or not base.is_playing():base.play(clips[desired],.12)

func trigger(clip):
	if dying:return
	if clip=="Dash" and lock_time>0 and base.current_animation==clips.Dash:return
	if clip=="Shoot":
		if lock_time<=0:
			upper.stop();upper.play("Shoot",.035)
		return
	var requested = {"Hurt":1,"Dash":2,"Death":3}.get(clip,0)
	if requested<priority and lock_time>0:return
	upper.stop()
	base.play(clips[clip],.055)
	lock_time = base.get_animation(clips[clip]).length
	priority = requested
	if clip=="Death":dying=true

func set_active(enabled):
	if enabled==enabled_state:return
	enabled_state=enabled
	if is_instance_valid(base):base.active=enabled
	if is_instance_valid(upper):upper.active=enabled
