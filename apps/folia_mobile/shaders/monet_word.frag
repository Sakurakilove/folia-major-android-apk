#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform vec2 uText; // padding, advance
uniform vec3 uSweep; // measured fill width, progress, active
uniform vec2 uGlow; // envelope, max alpha
uniform vec4 uBase;
uniform vec4 uWord;
uniform float uSoftness;
uniform sampler2D uGlyph;
uniform sampler2D uNear;
uniform sampler2D uFar;
out vec4 fragColor;
vec4 over(vec4 a, vec4 b) { return a + b * (1.0-a.a); }
void main() {
    vec2 p=FlutterFragCoord().xy;
    vec2 uv=p/uSize;
    float glyph=texture(uGlyph,uv).a;
    float a=texture(uNear,uv).a*uGlow.x*uGlow.y;
    float b=texture(uFar,uv).a*uGlow.x*uGlow.y;
    float shadowAlpha=a+b*(1.0-a);
    vec3 glowColor=floor(mix(uBase.rgb,uWord.rgb,uGlow.x)*255.0+0.5)/255.0;
    vec4 result=vec4(glowColor*shadowAlpha,shadowAlpha);
    vec4 base=uBase;
    base.a*=glyph; base.rgb*=base.a;
    result=over(base,result);
    if (uSweep.z>0.5) {
        float x=p.x-uText.x;
        float end=uSweep.x+uSoftness*clamp(uSweep.x/max(uText.y,0.001),0.0,1.0);
        float solid=max(end-uSoftness,0.0), feather=max(end-uSoftness*.55,0.0);
        float mask=x<=solid?1.0:x<feather?mix(1.0,.92,(x-solid)/max(.001,feather-solid)):x<end?.92*(end-x)/max(.001,end-feather):0.0;
        float nx=clamp(x/max(uText.y,.001),0.0,1.0);
        float fade=nx<.68?mix(1.0,.92,nx/.68):mix(.92,.72,(nx-.68)/.32);
        vec3 color=floor(mix(uBase.rgb,uWord.rgb,uSweep.y)*255.0+.5)/255.0;
        float alpha=glyph*mask*fade;
        result=over(vec4(color*alpha,alpha),result);
    }
    fragColor=result;
}
