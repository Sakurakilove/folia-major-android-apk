import json
import pathlib
import sys
import numpy as np
import onnxruntime as ort

# Execute the desktop's unchanged Beat This model and preserve its two output tensors.
model, request_dir = sys.argv[1:3]
directory = pathlib.Path(request_dir)
spec = json.loads((directory / 'request.json').read_text())
options = ort.SessionOptions()
options.enable_cpu_mem_arena = False
options.intra_op_num_threads = 2
options.add_session_config_entry("session.intra_op.allow_spinning", "0")
session = ort.InferenceSession(model, sess_options=options, providers=['CPUExecutionProvider'])
for index, frames in enumerate(spec['frames']):
    data = np.fromfile(directory / f'{index}.in', dtype=np.float32).reshape(1, frames, 128)
    beat, downbeat = session.run(['beat', 'downbeat'], {'input_spectrogram': data})
    np.asarray(beat, dtype=np.float32).reshape(-1).tofile(directory / f'{index}.beat')
    np.asarray(downbeat, dtype=np.float32).reshape(-1).tofile(directory / f'{index}.downbeat')
