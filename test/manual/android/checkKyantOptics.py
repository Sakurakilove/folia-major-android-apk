# Compile and check the real AGSL with skia-python; optional host-only tooling, never an app dependency.
from pathlib import Path
import skia,numpy as np,json
source=(Path(__file__).resolve().parents[3] / 'android/app/src/main/assets/shaders/kyantGlass.agsl').read_text()
width,height=240,160
backdrop=skia.GradientShader.MakeLinear([skia.Point(0,0),skia.Point(width,height)],[skia.ColorRED,skia.ColorGREEN,skia.ColorBLUE])
def render(code,count):
 effect=skia.RuntimeEffect.MakeForShader(code); builder=skia.RuntimeShaderBuilder(effect)
 values=[40.,30.,160.,100.]+[0.]*28+[24.,1.]+[0.]*14+[float(count),1.,float(width),float(height)]+[40.,30.,200.,130.]+[80.,50.,7.,36.]+[0.]*28
 data=builder.uniforms();np.frombuffer(data.writable_data(),dtype=np.float32)[:]=values
 builder.setChild('content',backdrop)
 surface=skia.Surface(width,height);surface.getCanvas().drawPaint(skia.Paint(Shader=builder.makeShader()))
 return np.array(surface.makeImageSnapshot())
plain=render(source,0);optical=render(source,1)
no_dispersion=render(source.replace('float dispersionIntensity = (centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y);','float dispersionIntensity = 0.0;'),1)
assert np.array_equal(plain[50:110,65:175],optical[50:110,65:175])
assert np.array_equal(plain[:20],optical[:20])
changed=np.count_nonzero(np.any(plain!=optical,axis=2)); color_changed=np.count_nonzero(np.any(optical!=no_dispersion,axis=2))
assert changed>0 and color_changed>0
record={'nativeOpticalChangedPixels':int(changed),'dispersionChangedPixels':int(color_changed),'interiorAndOutsideExact':True}
print(record)
