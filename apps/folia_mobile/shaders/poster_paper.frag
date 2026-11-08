#include <flutter/runtime_effect.glsl>
precision highp float;
uniform float uKind;
uniform vec2 uSize;
uniform float uHeight;
uniform float uDpr;
uniform vec4 uFirst;
uniform vec4 uSecond;
uniform vec4 uThird;
uniform vec4 uFade;
out vec4 fragColor;

float sourceDither(vec2 p) {
    vec2 pixel=floor(p*uDpr);
    vec3 x=mod(floor(vec3(pixel.x)/vec3(1.0,2.0,4.0)),2.0);
    vec3 y=abs(mod(floor(vec3(pixel.y)/vec3(1.0,2.0,4.0)),2.0)-x);
    float m=dot(y,vec3(32.0,8.0,2.0))+dot(x,vec3(16.0,4.0,1.0));
    return (m*(2.0/128.0)-63.0/128.0)/255.0;
}
vec4 premul(vec4 c) {return vec4(c.rgb*c.a,c.a);}
void main() {
    vec2 p=FlutterFragCoord().xy;
    vec4 result;
    if(uKind<0.5) {
        // Original artist stops are legacy hex/rgba palette values, interpolated
        // in premultiplied sRGB; the radius uses viewport vh, not paper height.
        vec2 d=(p-vec2(uSize.x*0.42,uHeight*0.82))/vec2(uSize.x*1.2,uHeight*0.9);
        float t=clamp(length(d),0.0,1.0);
        result=t<0.58?mix(premul(uFirst),premul(uSecond),t/0.58)
            :mix(premul(uSecond),premul(uThird),(t-0.58)/0.42);
    } else if(uKind<1.5) {
        float x=p.x/uSize.x;
        float a=x<0.9?0.45*clamp((x-0.78)/0.12,0.0,1.0)
            :0.45+0.55*clamp((x-0.9)/0.1,0.0,1.0);
        result=premul(vec4(uFade.rgb,uFade.a*a));
    } else {
        // Album :has(...) replaces both artist backgrounds with this hard edge.
        result=premul(p.y<uHeight*0.84?uFirst:uSecond);
    }
    fragColor=vec4(result.rgb+vec3(sourceDither(p)),result.a);
}
