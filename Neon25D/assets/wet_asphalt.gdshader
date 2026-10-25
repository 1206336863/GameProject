shader_type spatial;
render_mode diffuse_burley;
uniform vec4 asphalt : source_color = vec4(0.035,0.047,0.075,1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float puddle=smoothstep(0.46,0.68,noise(p*0.5)+noise(p*0.13)*0.23);
 float grain=noise(p*85.0);
 float seams=smoothstep(0.97,0.99,abs(sin(p.x*1.7)*sin(p.y*1.8)));
 ALBEDO=asphalt.rgb*(0.75+grain*0.32)*(1.0-seams*0.35);
 ROUGHNESS=mix(0.72,0.22,puddle);
 METALLIC=mix(0.03,0.12,puddle);
 float ripple=sin(length(fract(p*0.8)-0.5)*45.0-TIME*3.0)*0.006*puddle;
 NORMAL_MAP=vec3(0.5+ripple,0.5+noise(p*32.0)*0.008,1.0);
 NORMAL_MAP_DEPTH=0.08;
}
