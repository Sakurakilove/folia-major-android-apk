import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request

# Compile the pinned original C++ solver, with only export/assert header stubs.
# No reimplemented curve formula is used as the oracle.
revision = '154.0.8037.57'
sources = {
    'ui/gfx/geometry/cubic_bezier.cc': '9eac76cf4ae7d41940bf4e4d4061526aab8e312b39f035eb17d472793cd01b10',
    'ui/gfx/geometry/cubic_bezier.h': '263d2dc134e1911225e7ea9390d1a00c2889478d618338705c3b9aa969bc0eef',
}
curves = [[.25,.1,.25,1],[.42,0,1,1],[0,0,.58,1],[.42,0,.58,1],
          [.55,0,.9,.45],[.2,.7,.25,1],[.4,0,1,1],[.2,.9,.3,1.04],
          [.2,.9,.3,1.08],[.2,.9,.3,1.1],[.3,.7,.3,1.2],[.2,.8,.3,1],
          [.65,0,.25,1],[.6,0,.2,1],[0,0,1,1],[0,0,0,0],[1,1,1,1],
          [0,.5,1,.5],[0,0,.5,.5],[.5,.5,1,1]]
steps = [-.5,-.1,*[i/16 for i in range(17)],1.1,1.5]
with tempfile.TemporaryDirectory(prefix='folia-original-bezier-') as name:
    temporary = Path(name)
    for relative, expected in sources.items():
        content = urllib.request.urlopen(f'https://raw.githubusercontent.com/chromium/chromium/{revision}/{relative}').read()
        if hashlib.sha256(content).hexdigest() != expected:
            raise ValueError(f'Pinned source changed: {relative}')
        target = temporary / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    (temporary/'base').mkdir()
    (temporary/'base/component_export.h').write_text('#define COMPONENT_EXPORT(x)\n')
    (temporary/'base/check_op.h').write_text('#define DCHECK_GE(a,b) ((void)0)\n#define DCHECK_LE(a,b) ((void)0)\n')
    inputs = ','.join('{'+','.join(format(v,'.17g') for v in c)+'}' for c in curves)
    times = ','.join(format(v,'.17g') for v in steps)
    (temporary/'probe.cc').write_text('''#include <iostream>
#include <iomanip>
#include "ui/gfx/geometry/cubic_bezier.h"
int main() {
  const double curves[][4]={'''+inputs+'''},times[]={'''+times+'''};
  std::cout<<std::setprecision(17)<<"[";
  bool first=true;
  for(const auto& c:curves) {
    gfx::CubicBezier curve(c[0],c[1],c[2],c[3]);
    for(double t:times) {
      if(!first) std::cout<<",";
      first=false;std::cout<<curve.Solve(t);
    }
  }
  std::cout<<"]";
}
''')
    program=temporary/'probe'
    subprocess.run([os.environ.get('CXX','g++'),'-std=c++17','-O2','-DNDEBUG','-I',str(temporary),
                    str(temporary/'probe.cc'),str(temporary/'ui/gfx/geometry/cubic_bezier.cc'),'-o',str(program)],check=True)
    values=json.loads(subprocess.check_output([str(program)],text=True))
    rows=[{'curve':c,'samples':[{'at':at,'value':values[i*len(steps)+j]} for j,at in enumerate(steps)]}
          for i,c in enumerate(curves)]
output=Path(__file__).resolve().parents[1]/'test/fixtures/chromium_bezier_reference.json'
output.write_text(json.dumps({'chromium':revision,'sourceHashes':sources,
    'scope':'Original compiled C++ timing outputs; not a whole animation or device acceptance result.',
    'cases':rows},indent=2)+'\n')
print(f'Exported {len(rows)} original C++ curves and {len(values)} samples.')
