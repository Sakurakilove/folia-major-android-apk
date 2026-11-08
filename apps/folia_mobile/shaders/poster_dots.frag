#include <flutter/runtime_effect.glsl>
precision highp float;
uniform float uTile;
uniform float uInner;
uniform float uOuter;
uniform vec4 uInk;
uniform float uDpr;
out vec4 fragColor;
void main() {
    vec2 p=FlutterFragCoord().xy;
    float distance=length(p-vec2(uTile*0.5));
    float alpha=uInk.a*(1.0-clamp((distance-uInner)/(uOuter-uInner),0.0,1.0));
    vec2 pixel=floor(p*uDpr);
    vec3 x=mod(floor(vec3(pixel.x)/vec3(1.0,2.0,4.0)),2.0);
    vec3 y=abs(mod(floor(vec3(pixel.y)/vec3(1.0,2.0,4.0)),2.0)-x);
    float m=dot(y,vec3(32.0,8.0,2.0))+dot(x,vec3(16.0,4.0,1.0));
    float dither=(m*(2.0/128.0)-63.0/128.0)/255.0;
    fragColor=vec4(clamp(uInk.rgb*alpha+vec3(dither),0.0,alpha),alpha);
}
