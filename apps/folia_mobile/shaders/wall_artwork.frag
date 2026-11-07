#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform vec4 uImageRect;
uniform vec4 uBase;
uniform vec4 uLight;
uniform vec4 uDark;
uniform vec4 uFilter; // grayscale, contrast, brightness, layer opacity
uniform vec4 uLayers; // image mode, multiply, dark opacity, dot opacity
uniform vec4 uFallbackA;
uniform vec4 uFallbackB;
uniform vec2 uImageSize;
uniform float uMode; // 0 mosaic, 1 artist, 2 shard
uniform sampler2D uImage;
out vec4 fragColor;

// Isolated CSS background/filter/multiply/lighten composition at source DPR, without multiple offscreen filter passes per poster.
vec4 premul(vec4 c) { return vec4(c.rgb*c.a,c.a); }
vec4 over(vec4 a,vec4 b) { return a+b*(1.0-a.a); }
vec4 blend(vec4 s,vec4 b,bool lighten) {
    vec3 sc=s.a>0.0?s.rgb/s.a:vec3(0.0), bc=b.a>0.0?b.rgb/b.a:vec3(0.0);
    vec3 mixed=lighten?max(sc,bc):sc*bc;
    return vec4((1.0-b.a)*s.rgb+(1.0-s.a)*b.rgb+s.a*b.a*mixed,s.a+b.a-s.a*b.a);
}
vec4 sourceImage(vec2 p) {
    if(uLayers.x>1.5) {
        vec2 uv=fract((p-uImageRect.xy)/max(uImageRect.zw,vec2(.00001)));
        vec2 halfTexel=.5/uImageSize;
        if(all(greaterThanEqual(uv,halfTexel))&&all(lessThanEqual(uv,1.0-halfTexel))) return texture(uImage,uv);
        // FragmentShader's sampler clamps at its image edge. A CSS repeated background filters across adjacent copies instead.
        vec2 coordinate=uv*uImageSize-.5, low=floor(coordinate), weight=fract(coordinate);
        vec2 a=(mod(low,uImageSize)+.5)/uImageSize, b=(mod(low+1.0,uImageSize)+.5)/uImageSize;
        return mix(mix(texture(uImage,a),texture(uImage,vec2(b.x,a.y)),weight.x),
                   mix(texture(uImage,vec2(a.x,b.y)),texture(uImage,b),weight.x),weight.y);
    }
    if(uLayers.x>.5) {
        vec2 direction=vec2(.573576436351046,.819152044288992); // CSS 145deg: sin(theta), -cos(theta)
        float length=dot(uSize,abs(direction));
        float t=clamp(.5+dot(p-uSize*.5,direction)/max(length,.00001),0.0,1.0);
        return mix(premul(uFallbackA),premul(uFallbackB),t);
    }
    return vec4(0.0);
}
vec4 filtered(vec4 c) {
    vec3 rgb=c.a>0.0?c.rgb/c.a:vec3(0.0);
    float gray=dot(rgb,vec3(.2126,.7152,.0722));
    rgb=mix(rgb,vec3(gray),uFilter.x);
    rgb=clamp((rgb-.5)*uFilter.y+.5,0.0,1.0);
    rgb=clamp(rgb*uFilter.z,0.0,1.0);
    return vec4(rgb*c.a,c.a);
}
void main() {
    vec2 p=FlutterFragCoord().xy;
    vec4 image=sourceImage(p);
    if(uMode>.5&&uMode<1.5) image=over(image,premul(uBase));
    image=filtered(image);
    vec4 layer=uLayers.y>.5?blend(image,premul(uLight),false):over(image,premul(uLight));
    if(uLayers.z>0.0) layer=blend(premul(vec4(uDark.rgb,uDark.a*uLayers.z)),layer,true);
    if(uLayers.w>0.0) {
        float distance=length(mod(p,6.0)-vec2(3.0));
        float alpha=.24*clamp((1.5-distance)/.4,0.0,1.0)*uLayers.w;
        layer=blend(vec4(0.0,0.0,0.0,alpha),layer,false);
    }
    fragColor=layer*uFilter.w;
}
