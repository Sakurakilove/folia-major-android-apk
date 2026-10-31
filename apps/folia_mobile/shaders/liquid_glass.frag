/*
   Copyright 2025 Kyant

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */

// Kyant0/AndroidLiquidGlass 65ab177e90e5c1d8c62e70cf7755841982da65f6, AGSL -> Flutter GLSL.
// Local backdrop input; original SDF, depth normal, seven-color weights and glint are retained.
#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform float uRadius;
uniform float uScale;
uniform sampler2D uInput;
out vec4 fragColor;
vec4 sampleInput(vec2 p) {
    vec2 uv=clamp(p,vec2(0.0),uSize-vec2(1.0))/uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y=1.0-uv.y;
#endif
    return texture(uInput,uv);
}
float sdf(vec2 p,vec2 halfSize,float r) {
    vec2 corner=abs(p)-(halfSize-vec2(r));
    return length(max(corner,0.0))-r+min(max(corner.x,corner.y),0.0);
}
vec2 normalAt(vec2 p,vec2 halfSize,float r) {
    vec2 corner=abs(p)-(halfSize-vec2(r));
    if(corner.x>=0.0||corner.y>=0.0)return sign(p)*normalize(max(corner,0.0));
    float x=step(corner.y,corner.x);return sign(p)*vec2(x,1.0-x);
}
void main() {
    vec2 coord=FlutterFragCoord().xy;
    vec4 original=sampleInput(coord);
    vec2 halfSize=uSize*.5,centered=coord-halfSize;
    float radius=min(uRadius,min(halfSize.x,halfSize.y));
    float sd=sdf(centered,halfSize,radius);
    float height=min(7.0*uScale,min(halfSize.x,halfSize.y)*.45);
    if(sd>0.0||-sd>=height){fragColor=original;return;}
    float edge=clamp(1.0+sd/height,0.0,1.0);
    float d=(1.0-sqrt(max(0.0,1.0-edge*edge)))*16.0*uScale;
    float gr=min(radius*1.5,min(halfSize.x,halfSize.y));
    vec2 n=normalize(normalAt(centered,halfSize,gr)+.2*normalize(centered));
    vec2 p=coord+(-sd+d)*n;
    vec2 delta=d*n*(centered.x*centered.y)/(halfSize.x*halfSize.y);
    vec4 red=sampleInput(p+delta),orange=sampleInput(p+delta*(2.0/3.0)),yellow=sampleInput(p+delta/3.0);
    vec4 green=sampleInput(p),cyan=sampleInput(p-delta/3.0),blue=sampleInput(p-delta*(2.0/3.0)),purple=sampleInput(p-delta);
    vec4 color=vec4(red.r/3.5+orange.r/3.5+yellow.r/3.5+purple.r/7.0,
        orange.g/7.0+yellow.g/3.5+green.g/3.5+cyan.g/3.5,
        cyan.b/3.0+blue.b/3.0+purple.b/3.0,
        (red.a+orange.a+yellow.a+green.a+cyan.a+blue.a+purple.a)/7.0);
    float light=pow(abs(dot(n,vec2(-.70710678))),1.5);
    float glint=pow(edge,5.0)*light*.22;
    color.rgb=min(color.rgb+glint*color.a,vec3(color.a));
    fragColor=mix(original,color,edge);
}
