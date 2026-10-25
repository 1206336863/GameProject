extends RefCounted
const PHASES=["巡夜","封街","终夜过载"]
const MOVES=["灯阵轰击","霓虹扇幕","破摊冲锋","回旋灯雨"]
func transition(g,e,phase):
	e.phase=phase;e.mode="transition";e.timer=1.8;e.freeze=0
	for bullet in g.bullets.duplicate():
		if bullet.enemy:bullet.node.queue_free();g.bullets.erase(bullet)
	for effect in g.fx.duplicate():
		if effect.get("owner")==e:effect.node.queue_free();g.fx.erase(effect)
	g.floating(Vector3(0,3,0),"第 %d 幕 · %s"%[phase,PHASES[phase-1]],Color("ffe08b"))
	g.ring_warning(e.body.position+Vector3(0,.08,0),2.0,1.8)
	g.sound("level");g.feel.kick(.12)
	for light in g.world.find_children("*","OmniLight3D",true,false):
		light.light_color=[Color("6cf3e1"),Color("bb80ff"),Color("ff648c")][phase-1]
func tick(g,e):
	var phase=e.get("phase",1)
	if e.mode=="intro":
		if e.timer<=0:e.mode="rest";e.timer=.6
		return Vector3.ZERO
	if e.mode=="transition":
		if e.timer<=0:e.mode="rest";e.timer=.8
		return Vector3.ZERO
	if (phase==1 and e.hp<=e.max*.65) or (phase==2 and e.hp<=e.max*.3):
		transition(g,e,phase+1);return Vector3.ZERO
	if e.mode=="rest" and e.timer<=0:
		e.move=(e.move+1)%(4 if phase>=2 else 3);e.mode="windup";e.timer=1.15 if phase<3 else .95
		e.dir=(g.player.position-e.body.position).normalized();e.target=g.player.position
		g.floating(e.body.position+Vector3(0,3,0),MOVES[e.move],Color("ffcb95"))
		if e.move==0:
			for dx in [-3,0,3]:g.ring_warning(Vector3(clamp(e.target.x+dx,-11,11),.03,e.target.z),1.25,e.timer,false,e)
		elif e.move==1:
			for angle in [-.48,0,.48]:g.warning_line(e.body.position,e.dir.rotated(Vector3.UP,angle),Color("ff759c"),e.timer,10,e)
		elif e.move==2:g.warning_line(e.body.position,e.dir,Color("ffad65"),e.timer,7.8,e)
		else:
			g.ring_warning(e.body.position+Vector3(0,.04,0),2,e.timer,false,e)
			g.warning_line(e.body.position,e.dir,Color("66ffd9"),e.timer,12,e)
	elif e.mode=="windup" and e.timer<=0:
		if e.move==2:e.mode="charge";e.timer=.65;g.play_actor(e.mesh,"Dash")
		else:
			g.play_actor(e.mesh,"Shoot");g.feel.kick(.06)
			if e.move==0:
				for dx in [-3,0,3]:
					var pos=Vector3(clamp(e.target.x+dx,-11,11),0,e.target.z)
					g.feel.impact(g,pos+Vector3.UP,Color("ff759c"),12)
					if g.player.position.distance_to(pos)<1.25:g.hurt(18)
			if e.move==1:
				for i in range(7):g.spawn_bullet(e.body.position+Vector3.UP,e.dir.rotated(Vector3.UP,(i-3)*.16)*(7.5+phase*.5),true)
			if e.move==3:
				# Five-ray-wide safe sector points toward the locked player position.
				for i in range(24):
					var angle=i*TAU/24
					if min(angle,TAU-angle)<.55:continue
					g.spawn_bullet(e.body.position+Vector3.UP,e.dir.rotated(Vector3.UP,angle)*6.5,true)
			e.mode="rest";e.timer=1.5 if phase<3 else 1.05
	elif e.mode=="charge":
		if e.timer<=0:e.mode="rest";e.timer=1.7
		else:return e.dir*12
	return Vector3.ZERO
func label(e):
	var mode={"intro":"登场 · 准备战斗","transition":"阶段转场 · 护盾","rest":"反击窗口","windup":"预警："+MOVES[e.move],"charge":"冲锋"}.get(e.mode,e.mode)
	return "第 %d 幕 · %s · %s"%[e.get("phase",1),PHASES[e.get("phase",1)-1],mode]
