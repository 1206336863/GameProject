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
 bpy.ops.object.select_all(action='DESELECT')
 for o in current:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
 models[name]=list(current);current.clear()
 for o in models[name]:o.hide_set(True)
def stall(name,sign,neon):
 box('Counter',(0,0,.65),(2.5,1.25,1.3),wood);box('Countertop',(0,-.04,1.35),(2.75,1.45,.14),steel)
 for x in [-1.22,1.22]:box('Post',(x,.5,1.5),(.12,.12,3),steel)
 box('Roof',(0,.1,2.85),(2.9,1.9,.2),dark)
 for i in range(12):box('Awning stripe',(-1.32+i*.24,-.8,2.68),(.23,.15,.36),neon if i%2==0 else dark,.015)
 box('Sign backing',(0,-.98,3.12),(2.3,.13,.62),dark);label(sign,(0,-1.06,2.94),neon,.35)
 for i in range(3):cylinder('Bowl',(-.65+i*.65,-.35,1.49),.18,.13,skin);sphere('Soup',(-.65+i*.65,-.35,1.56),.14,amber,scale=(1,1,.15))
 box('Kick neon',(0,-.65,.13),(2.4,.04,.055),neon,.01)
 save_asset(name)
stall('stall_ramen','深夜拉面',pink);stall('stall_tea','夜茶',cyan);stall('stall_arcade','電玩街',purple)
def humanoid(name,material,eye,kind='normal'):
 for x,side in [(-.17,'L'),(.17,'R')]:box('Leg'+side,(x,0,.3),(.22,.3,.6),dark)
 box('Body',(0,0,.93),(.68,.42,.8),material,.09);sphere('Head',(0,0,1.53),.29,skin)
 box('Visor',(0,-.24,1.57),(.53,.12,.15),dark);box('Eye strip',(0,-.31,1.57),(.4,.03,.055),eye,.01)
 box('ArmL',(-.43,0,.98),(.18,.22,.58),material);box('ArmR',(.43,-.1,.98),(.18,.22,.58),material)
 box('Blaster',(.45,-.43,1.05),(.15,.6,.15),steel);box('Muzzle',(.45,-.75,1.05),(.14,.06,.13),eye,.01)
 if kind=='tank':
  for x in [-.5,.5]:box('Shoulder armor',(x,0,1.28),(.38,.6,.35),steel)
  box('Chest shield',(0,-.29,1.05),(.65,.15,.5),steel)
 if kind=='boss':
  box('Crown band',(0,0,1.83),(.65,.45,.13),amber)
  for x in [-.25,0,.25]:box('Crown spike',(x,0,2),(.12,.23,.35),amber)
 if kind=='dash':box('Scarf',(0,.3,1.2),(.32,.7,.08),amber)
 save_asset(name)
humanoid('player',coat,cyan);humanoid('enemy_chase',red,pink);humanoid('enemy_gun',dark,purple);humanoid('enemy_dash',wood,amber,'dash');humanoid('enemy_tank',red,pink,'tank');humanoid('boss',dark,pink,'boss')
box('Crate',(0,0,.5),(1,1,1),wood)
for z in [.12,.88]:box('Metal band',(0,0,z),(1.06,1.06,.09),steel)
box('Crate neon',(0,-.51,.5),(.65,.025,.06),cyan,.01);save_asset('crate')
sphere('Lantern',(0,0,0),.22,pink,scale=(1,1,1.3));cylinder('Lantern cap',(0,0,.28),.16,.06,steel);save_asset('lantern')
# Original source library: one collection per model, laid out for easy inspection.
for index,(name,objects) in enumerate(models.items()):
 c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
 for o in objects:
  for existing in list(o.users_collection):existing.objects.unlink(o)
  c.objects.link(o);o.hide_set(False);o.location.x+=(index%4)*4;o.location.y+=(index//4)*4
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/NeonMarket_Assets.blend'))
(OUT/'manifest.json').write_text(json.dumps({'generator':'Blender '+bpy.app.version_string,'units':'meters','models':list(models),'colliders':'Created in Godot from the same placement dimensions'},indent=2),encoding='utf-8')
print('NEON_ASSETS_OK',len(models))
