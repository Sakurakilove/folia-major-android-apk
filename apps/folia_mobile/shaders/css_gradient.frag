#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uFrom;
uniform vec2 uTo;
uniform vec4 uFirst;
uniform vec4 uLast;
uniform float uOpacity;
uniform vec3 uLabLms0;
uniform vec3 uLabLms1;
uniform vec3 uLabLms2;
uniform vec3 uLmsRgb0;
uniform vec3 uLmsRgb1;
uniform vec3 uLmsRgb2;
uniform float uDither;
uniform float uDpr;
out vec4 fragColor;

// Matrices are the same pinned Chromium ICC/D50 conversion facts used by native CSS transitions, not a second approximate Oklab transform.
float encoded(float v) {
    float a=abs(v);
    return a<=0.0031308?v*12.92:sign(v)*(1.055*pow(a,1.0/2.4)-0.055);
}
// Source Skia's 8x8 Bayer order, from the pinned SkRasterPipeline dither stage.
float cssDither(vec2 p) {
    vec2 pixel=floor(p*uDpr);
    vec3 x=mod(floor(vec3(pixel.x)/vec3(1.0,2.0,4.0)),2.0);
    vec3 y=abs(mod(floor(vec3(pixel.y)/vec3(1.0,2.0,4.0)),2.0)-x);
    float m=dot(y,vec3(32.0,8.0,2.0))+dot(x,vec3(16.0,4.0,1.0));
    return (m*(2.0/128.0)-63.0/128.0)/255.0;
}
void main() {
    vec2 axis=uTo-uFrom;
    float span=dot(axis,axis);
    float t=span>0.0?clamp(dot(FlutterFragCoord().xy-uFrom,axis)/span,0.0,1.0):1.0;
    float a=mix(uFirst.a,uLast.a,t);
    vec3 lab=a>0.0?mix(uFirst.rgb*uFirst.a,uLast.rgb*uLast.a,t)/a:vec3(0.0);
    vec3 lms=vec3(dot(uLabLms0,lab),dot(uLabLms1,lab),dot(uLabLms2,lab));
    lms=lms*lms*lms;
    vec3 linearRgb=vec3(dot(uLmsRgb0,lms),dot(uLmsRgb1,lms),dot(uLmsRgb2,lms));
    vec3 rgb=clamp(vec3(encoded(linearRgb.r),encoded(linearRgb.g),encoded(linearRgb.b)),0.0,1.0);
    float alpha=a*uOpacity;
    fragColor=vec4(rgb*alpha+vec3(uDither*cssDither(FlutterFragCoord().xy)),alpha);
}
