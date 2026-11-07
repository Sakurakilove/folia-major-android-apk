#include <flutter/runtime_effect.glsl>
precision highp float;
uniform float uKind;
uniform vec2 uFrom;
uniform vec2 uTo;
uniform vec4 uColor;
uniform vec2 uStops;
uniform float uDpr;
uniform float uTile;
out vec4 fragColor;

// Source Skia's 8x8 Bayer order, from the pinned SkRasterPipeline dither stage.
float cssDither(vec2 p) {
    vec2 pixel=floor(p*uDpr);
    vec3 x=mod(floor(vec3(pixel.x)/vec3(1.0,2.0,4.0)),2.0);
    vec3 y=abs(mod(floor(vec3(pixel.y)/vec3(1.0,2.0,4.0)),2.0)-x);
    float m=dot(y,vec3(32.0,8.0,2.0))+dot(x,vec3(16.0,4.0,1.0));
    return (m*(2.0/128.0)-63.0/128.0)/255.0;
}
void main() {
    vec2 p=FlutterFragCoord().xy;
    float alpha=0.0;
    if(uKind<0.5) {
        vec2 axis=uTo-uFrom;
        float t=fract(dot(p-uFrom,axis)/dot(axis,axis));
        alpha=t<uStops.x?uColor.a:0.0;
    } else if(uKind<1.5) {
        vec2 d=p-uFrom;
        d.y/=uTo.y;
        float t=fract(length(d)/uTo.x);
        alpha=t>=uStops.x?uColor.a:0.0;
    } else if(uKind<2.5) {
        float w=uFrom.x;
        if(p.x<1.0||p.x>=max(6.0,w-1.0)) alpha=uColor.a;
        else if((p.x>=5.0&&p.x<6.0)||(p.x>=max(6.0,w-6.0)&&p.x<max(6.0,w-5.0))) alpha=uColor.a*0.55;
    } else {
        alpha=uColor.a*clamp(1.0-p.y/uFrom.y,0.0,1.0);
    }
    // Dither is applied to premultiplied channel arithmetic before the final
    // store, including transparent spans. It is not another visible noise layer.
    vec3 color=uColor.rgb*alpha+vec3(cssDither(p));
    if(uTile>0.5) color=clamp(color,0.0,alpha);
    fragColor=vec4(color,alpha);
}
