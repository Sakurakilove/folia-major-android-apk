#include <flutter/runtime_effect.glsl>
precision highp float;
uniform float uWidth;
uniform vec4 uColor;
uniform float uDpr;
out vec4 fragColor;

// Original 9px square tile, 50% 0 position, circle stops 1px / 1.6px.
void main() {
    vec2 p=FlutterFragCoord().xy;
    vec2 d=vec2(mod(p.x-uWidth*0.5+4.5,9.0)-4.5,mod(p.y,9.0)-4.5);
    float alpha=uColor.a*clamp((1.6-length(d))/0.6,0.0,1.0);
    vec2 pixel=floor(p*uDpr);
    vec3 x=mod(floor(vec3(pixel.x)/vec3(1.0,2.0,4.0)),2.0);
    vec3 y=abs(mod(floor(vec3(pixel.y)/vec3(1.0,2.0,4.0)),2.0)-x);
    float m=dot(y,vec3(32.0,8.0,2.0))+dot(x,vec3(16.0,4.0,1.0));
    float noise=(m*(2.0/128.0)-63.0/128.0)/255.0;
    fragColor=vec4(clamp(uColor.rgb*alpha+vec3(noise),0.0,alpha),alpha);
}
