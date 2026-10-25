"""Rebuild original low-poly game assets in Blender 4.5+; export meter-scale GLB."""
import bpy, math, pathlib, json
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'assets';OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.5,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if p is None:p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
 p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 m.use_backface_culling=True
 return m
dark=mat('Midnight enamel',(.025,.035,.075),.45,.3);steel=mat('Brushed metal',(.16,.2,.28),.7,.28)
wood=mat('Warm wood',(.19,.09,.08),0,.65);pink=mat('Neon sakura',(.95,.025,.23),.1,.3,3)
cyan=mat('Neon jade',(.03,.9,.7),.2,.25,3);amber=mat('Neon amber',(1,.4,.04),.1,.35,2)
purple=mat('Neon violet',(.5,.09,.95),.2,.3,2);skin=mat('Porcelain',(.78,.8,.72));red=mat('Crimson jacket',(.5,.02,.1));coat=mat('Teal raincoat',(.025,.3,.28),.15)
fontpath=pathlib.Path('C:/Windows/Fonts/msyh.ttc');font=bpy.data.fonts.load(str(fontpath)) if fontpath.exists() else None
current=[];models={}
def box(name,pos,size,material,bevel=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 if bevel:
  mod=o.modifiers.new('Soft chamfer','BEVEL');mod.width=bevel;mod.segments=2
  o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 current.append(o);return o
def sphere(name,pos,radius,material,scale=(1,1,1)):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=radius,location=pos);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material);current.append(o);return o
def cylinder(name,pos,radius,depth,material):
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=depth,location=pos);o=bpy.context.object;o.name=name;o.data.materials.append(material);current.append(o);return o
def label(text,pos,color,size=.25):
 bpy.ops.object.text_add(location=pos,rotation=(math.pi/2,0,0));o=bpy.context.object;o.name='Sign_'+text;o.data.body=text;o.data.align_x='CENTER';o.data.size=size;o.data.extrude=.004
 if font:o.data.font=font
 o.data.materials.append(color);bpy.ops.object.convert(target='MESH');current.append(o)
def save_asset(name):
 if name.startswith('stall_') or any(o.type=='ARMATURE' for o in current):
  groups={}
  rigs=[o for o in current if o.type=='ARMATURE']
  for o in current:
   if o.type!='MESH':continue
   bpy.context.view_layer.objects.active=o
   for modifier in list(o.modifiers):
    if modifier.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=modifier.name)
   groups.setdefault(o.data.materials[0].name,[]).append(o)
  joined=[]
  for material_name,objects in groups.items():
   bpy.ops.object.select_all(action='DESELECT')
   for o in objects:o.select_set(True)
   bpy.context.view_layer.objects.active=objects[0]
   if len(objects)>1:bpy.ops.object.join()
   o=bpy.context.object;o.name=name+'_'+material_name;joined.append(o)
  current[:]=joined+rigs
 bpy.ops.object.select_all(action='DESELECT')
 for o in current:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=False,export_force_sampling=True)
 models[name]=list(current);current.clear()
 for o in models[name]:o.hide_set(True)
canvas_red=mat('Ramen canvas',(.6,.065,.055),rough=.85)
canvas_green=mat('Tea canvas',(.035,.35,.22),rough=.85)
cream=mat('Cream lettering',(.95,.84,.58),rough=.7)
soup=mat('Golden broth',(.8,.3,.035),rough=.25)
def stall(name,sign,neon):
 cloth=canvas_red if name=='stall_ramen' else canvas_green if name=='stall_tea' else purple
 # Rear-half awning keeps the counter and wares visible from the steep game camera.
 for x in [-1.25,1.25]:box('Timber post',(x,.48,1.25),(.11,.11,2.5),wood)
 box('Rear canopy',(0,.48,2.55),(2.85,.72,.13),cloth)
 for i in range(7):box('Canvas stripe',(-1.2+i*.4,.48,2.63),(.17,.73,.025),cream,.005)
 box('Marquee',(0,.35,2.92),(2.65,.13,.5),dark)
 box('Marquee neon',(0,.27,3.19),(2.68,.04,.035),neon,.005)
 label(sign,(0,.27,2.76),cream,.34)
 if name=='stall_arcade':
  for x in [-.62,.62]:
   box('Arcade cabinet',(x,-.15,.85),(.95,.9,1.7),dark)
   box('Screen bezel',(x,-.62,1.36),(.81,.08,.65),steel)
   box('Game screen',(x,-.67,1.38),(.68,.025,.48),cyan,.01)
   for j in range(3):box('Pixel alien',(x-.21+j*.21,-.69,1.42),(.095,.015,.11),purple,.002)
   box('Control deck',(x,-.66,.92),(.85,.36,.1),cloth)
   cylinder('Joystick stick',(x-.2,-.71,1.04),.025,.16,steel);sphere('Joystick ball',(x-.2,-.71,1.13),.06,red)
   for dx in [.1,.27]:sphere('Button',(x+dx,-.73,1),.055,amber,scale=(1,1,.35))
   label('PLAY',(x,-.64,1.82),cream,.16)
 else:
  box('Counter',(0,-.25,.52),(2.5,1.05,1.04),wood)
  box('Countertop',(0,-.3,1.08),(2.75,1.2,.12),steel)
  for x in [-.75,.75]:
   cylinder('Stool cushion',(x,-.98,.5),.22,.12,cloth)
   box('Stool leg',(x,-.98,.25),(.12,.12,.5),wood)
  if name=='stall_tea':
   box('Drink display',(-.72,.0,1.48),(.8,.45,.68),canvas_green)
   for i in range(3):
    cylinder('Tea dispenser',(-.98+i*.27,-.05,1.65),.095,.5,amber if i%2 else skin)
    cylinder('Dispenser lid',(-.98+i*.27,-.05,1.92),.105,.04,steel)
   for i in range(3):
    cylinder('Takeaway cup',(.08+i*.36,-.62,1.31),.13,.33,cream)
    cylinder('Cup lid',(.08+i*.36,-.62,1.49),.14,.035,skin)
    cylinder('Straw',(.08+i*.36,-.62,1.65),.018,.32,red)
   cylinder('Large cup icon',(.83,.44,2.97),.24,.55,cream)
   cylinder('Icon straw',(.9,.44,3.39),.025,.4,red)
  else:
   cylinder('Stock pot',(-.8,.03,1.37),.32,.48,steel)
   cylinder('Pot broth',(-.8,.03,1.62),.28,.025,soup)
   for x in [-1.16,-.44]:box('Pot handle',(x,.03,1.5),(.14,.12,.06),dark)
   for i in range(3):
    x=-.25+i*.48
    cylinder('Ramen bowl',(x,-.65,1.25),.2,.18,cream)
    cylinder('Ramen soup',(x,-.65,1.35),.17,.025,soup)
    sphere('Egg',(x-.05,-.65,1.38),.06,skin,scale=(1,.75,.3))
    box('Chopsticks',(x+.12,-.65,1.4),(.025,.45,.025),wood,.003)
   label('RAMEN',(0,-.8,.63),cream,.24)
  sphere('Vendor head',(.1,.48,1.94),.17,skin)
  box('Vendor apron',(.1,.48,1.55),(.4,.3,.5),cloth)
 box('Kick neon',(0,-.79,.1),(2.35,.025,.04),neon,.005)
 save_asset(name)
stall('stall_ramen','深夜拉面',pink);stall('stall_tea','夜茶',cyan);stall('stall_arcade','電玩街',purple)
def rig_character(name):
 """Articulated rigid-weight skinning, in-place clips baked into glTF skeleton channels."""
 pieces=list(current)
 bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0))
 rig=bpy.context.object;rig.name=name+'_Rig';rig.data.name=name+'_Skeleton'
 bones=rig.data.edit_bones;bones.remove(bones[0])
 definitions=[('root',(0,0,0),(0,0,.4),None),('hips',(0,0,.65),(0,0,.95),'root'),('spine',(0,0,.95),(0,0,1.35),'hips'),('head',(0,0,1.35),(0,0,1.8),'spine')]
 for side,x in [('L',-.17),('R',.17)]:
  definitions += [('thigh.'+side,(x,0,.7),(x,0,.36),'hips'),('shin.'+side,(x,0,.36),(x,0,.08),'thigh.'+side),('foot.'+side,(x,0,.08),(x,-.24,.08),'shin.'+side)]
 for side,x in [('L',-.43),('R',.43)]:
  definitions += [('upper_arm.'+side,(x,0,1.3),(x,0,1.0),'spine'),('forearm.'+side,(x,0,1.0),(x,-.27,1.0),'upper_arm.'+side),('hand.'+side,(x,-.27,1),(x,-.6,1),'forearm.'+side)]
 for bn,head,tail,parent in definitions:
  b=bones.new(bn);b.head=head;b.tail=tail
  if parent:b.parent=bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT')
 for obj in pieces:
  # Finalize bevel geometry before skinning; all generated vertices receive a rigid group.
  bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
  bpy.ops.object.convert(target='MESH')
  n=obj.name
  target='spine'
  if n.startswith(('Head','Visor','Eye','Crown')):target='head'
  elif n.startswith('UpperLeg'):target='thigh.'+('L' if n.split('.')[0].endswith('L') else 'R')
  elif n.startswith('LowerLeg'):target='shin.'+('L' if n.split('.')[0].endswith('L') else 'R')
  elif n.startswith('Boot'):target='foot.'+('L' if n.split('.')[0].endswith('L') else 'R')
  elif n.startswith('Arm'):target='upper_arm.'+('L' if n.split('.')[0].endswith('L') else 'R')
  elif n.startswith('Forearm'):target='forearm.'+('L' if n.split('.')[0].endswith('L') else 'R')
  elif n.startswith(('Blaster','Muzzle')):target='hand.R'
  obj.vertex_groups.new(name=target).add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
  modifier=obj.modifiers.new('Skeleton deformation','ARMATURE');modifier.object=rig
  obj.parent=rig
 current.append(rig)
 bpy.context.view_layer.objects.active=rig
 rig.animation_data_create();bpy.context.scene.render.fps=30
 for clip,length in [('Idle',1.2),('Walk',.8),('Shoot',.24),('Dash',.28),('Hurt',.36),('Death',.9)]:
  action=bpy.data.actions.new(name+'_'+clip);rig.animation_data.action=action
  frames=max(2,round(length*30))
  for f in range(frames+1):
   t=f/frames;phase=t*math.tau
   for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
   pose=rig.pose.bones
   if clip=='Idle':
    pose['spine'].rotation_euler.x=.025*math.sin(phase);pose['head'].rotation_euler.z=.035*math.sin(phase)
   elif clip=='Walk':
    wave=math.sin(phase)
    pose['thigh.L'].rotation_euler.x=.6*wave;pose['thigh.R'].rotation_euler.x=-.6*wave
    pose['shin.L'].rotation_euler.x=-.5*max(0,-wave);pose['shin.R'].rotation_euler.x=-.5*max(0,wave)
    pose['upper_arm.L'].rotation_euler.x=-.3*wave;pose['upper_arm.R'].rotation_euler.x=.2*wave
    pose['spine'].rotation_euler.z=.045*wave;pose['root'].location.y=.035*abs(math.sin(phase*2))
   elif clip=='Shoot':
    recoil=math.sin(math.pi*t)*math.exp(-2*t)
    pose['forearm.R'].rotation_euler.x=-.4*recoil;pose['upper_arm.R'].rotation_euler.x=-.2*recoil;pose['spine'].rotation_euler.x=-.11*recoil
   elif clip=='Dash':
    pose['root'].rotation_euler.x=.6*math.sin(math.pi*t*.8)
    pose['thigh.L'].rotation_euler.x=.5;pose['thigh.R'].rotation_euler.x=-.5
    pose['upper_arm.L'].rotation_euler.x=.65;pose['upper_arm.R'].rotation_euler.x=.5
   elif clip=='Hurt':
    pose['spine'].rotation_euler.x=-.32*math.sin(math.pi*t);pose['head'].rotation_euler.z=.22*math.sin(math.pi*t)
   elif clip=='Death':
    ease=1-(1-t)**3;pose['root'].rotation_euler.x=-1.5*ease;pose['root'].location.y=-.12*ease
    pose['upper_arm.L'].rotation_euler.z=.8*ease;pose['upper_arm.R'].rotation_euler.z=-.8*ease
   for pb in rig.pose.bones:
    pb.keyframe_insert('rotation_euler',frame=f+1,group=pb.name);pb.keyframe_insert('location',frame=f+1,group=pb.name)
  track=rig.animation_data.nla_tracks.new();track.name=clip
  strip=track.strips.new(clip,1,action);strip.action_frame_start=1;strip.action_frame_end=frames+1;strip.blend_type='REPLACE'
 rig.animation_data.action=None
 for track in rig.animation_data.nla_tracks:track.mute=False
 bpy.context.scene.frame_set(1)

def humanoid(name,material,eye,kind='normal'):
 for x,side in [(-.17,'L'),(.17,'R')]:
  box('UpperLeg'+side,(x,0,.53),(.22,.29,.32),dark);box('LowerLeg'+side,(x,0,.22),(.19,.26,.27),dark);box('Boot'+side,(x,-.07,.065),(.25,.42,.13),steel)
 box('Body',(0,0,.93),(.68,.42,.8),material,.09);sphere('Head',(0,0,1.53),.29,skin)
 box('Visor',(0,-.24,1.57),(.53,.12,.15),dark);box('Eye strip',(0,-.31,1.57),(.4,.03,.055),eye,.01)
 box('ArmL',(-.43,0,1.15),(.18,.22,.3),material);box('ArmR',(.43,0,1.15),(.18,.22,.3),material)
 box('ForearmL',(-.43,-.14,1.0),(.17,.32,.17),material);box('ForearmR',(.43,-.14,1.0),(.17,.32,.17),material)
 box('Blaster',(.45,-.43,1.05),(.15,.6,.15),steel);box('Muzzle',(.45,-.75,1.05),(.14,.06,.13),eye,.01)
 if kind=='tank':
  for x in [-.5,.5]:box('Shoulder armor',(x,0,1.28),(.38,.6,.35),steel)
  box('Chest shield',(0,-.29,1.05),(.65,.15,.5),steel)
 if kind=='boss':
  box('Crown band',(0,0,1.83),(.65,.45,.13),amber)
  for x in [-.25,0,.25]:box('Crown spike',(x,0,2),(.12,.23,.35),amber)
 if kind=='dash':box('Scarf',(0,.3,1.2),(.32,.7,.08),amber)
 rig_character(name)
 save_asset(name)
humanoid('player',coat,cyan);humanoid('enemy_chase',red,pink);humanoid('enemy_gun',dark,purple);humanoid('enemy_dash',wood,amber,'dash');humanoid('enemy_tank',red,pink,'tank');humanoid('boss',dark,pink,'boss')
box('Crate',(0,0,.5),(1,1,1),wood)
for z in [.12,.88]:box('Metal band',(0,0,z),(1.06,1.06,.09),steel)
box('Crate neon',(0,-.51,.5),(.65,.025,.06),cyan,.01);save_asset('crate')
sphere('Lantern',(0,0,0),.22,pink,scale=(1,1,1.3));cylinder('Lantern cap',(0,0,.28),.16,.06,steel);save_asset('lantern')
# More modular props, kept outside navigation lanes unless a matching collider is authored.
green=mat('Bamboo leaves',(.025,.19,.11),0,.7)
for i in range(3):
 cylinder('Bamboo stem',(-.16+i*.16,0,.75),.035,1.4,green)
 for j in range(3):
  o=box('Bamboo leaf',(-.16+i*.16+(-1 if j%2 else 1)*.16,0,.6+j*.25),(.42,.045,.11),green,.025);o.rotation_euler.y=(-1 if j%2 else 1)*.45
cylinder('Planter',(0,0,.2),.38,.4,wood);save_asset('plant')
box('Vending shell',(0,0,1.1),(1.15,.8,2.2),dark,.1);box('Glass front',(-.12,-.42,1.25),(.78,.04,1.2),steel)
for x in [-.32,.02]:
 for z in [.9,1.25,1.6]:cylinder('Drink bottle',(x,-.47,z),.07,.22,cyan if z>1.4 else pink)
box('Vending pickup',(0,-.43,.3),(.7,.04,.23),dark);box('Vending rim',(0,-.45,2.07),(1.02,.04,.1),cyan,.01);label('汽水',(0,-.47,1.92),cyan,.16);save_asset('vending')
for x in [-.65,.65]:
 for y in [-.32,.32]:
  o=cylinder('Cart wheel',(x,y,.2),.18,.1,steel);o.rotation_euler.x=math.pi/2
box('Grill cart',(0,0,.7),(1.5,.8,.8),wood);box('Grill',(0,0,1.13),(1.55,.84,.08),steel)
for i in range(7):box('Skewer',(-.55+i*.18,-.05,1.23),(.07,.52,.08),amber,.02)
box('Cart accent',(0,-.42,.75),(1.35,.03,.07),amber,.01);save_asset('grill_cart')
for x in [-.8,.8]:box('Bench leg',(x,0,.3),(.09,.6,.6),steel)
for i in range(4):box('Bench slat',(0,-.22+i*.15,.62),(2,.11,.09),wood)
save_asset('bench')
cylinder('Bin',(0,0,.48),.3,.96,steel);cylinder('Bin lid',(0,0,1),.34,.09,dark)
box('Bin sticker',(0,-.31,.6),(.2,.03,.23),cyan,.01);save_asset('trash_bin')
for x in [-1.5,1.5]:
 box('Gate post',(x,0,1.8),(.2,.28,3.6),wood);box('Gate vertical neon',(x,-.16,1.8),(.045,.03,3.2),pink,.01)
box('Gate beam',(0,0,3.65),(3.5,.4,.24),dark);label('午夜夜市',(0,-.25,3.57),amber,.32);save_asset('market_gate')

# Original source library: one collection per model, laid out for easy inspection.
for index,(name,objects) in enumerate(models.items()):
 c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
 for o in objects:
  for existing in list(o.users_collection):existing.objects.unlink(o)
  c.objects.link(o);o.hide_set(False)
  if o.parent is None:o.location.x+=(index%4)*4;o.location.y+=(index//4)*4
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/NeonMarket_Assets.blend'))
(OUT/'manifest.json').write_text(json.dumps({'generator':'Blender '+bpy.app.version_string,'units':'meters','models':list(models),'animation_clips':['Idle','Walk','Shoot','Dash','Hurt','Death'],'rigged_characters':6,'colliders':'Created in Godot from the same placement dimensions'},indent=2),encoding='utf-8')
print('NEON_ASSETS_OK',len(models))
