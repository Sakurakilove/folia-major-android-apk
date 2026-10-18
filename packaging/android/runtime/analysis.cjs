const fs = require('node:fs');
const fsp = fs.promises;
const path = require('node:path');
const { spawn } = require('node:child_process');
const { resolveModelFile } = require('./electron/analysis/modelPaths.cjs');
const { createModelStore } = require('./electron/analysis/modelStore.cjs');
const { separate, RUNNER_SCRIPT } = require('./electron/analysis/sidecar.cjs');

// Android runs the same ONNX files and Demucs DSP through its native Python/ORT distribution.
module.exports = ({ dataDir, store, events }) => {
    const defaultDirectory = path.join(dataDir, 'models');
    const directory = () => store.get('MODELS_DIRECTORY') || defaultDirectory;
    const dirs = () => [directory(), defaultDirectory];
    const python = process.env.FOLIA_ANDROID_PYTHON;
    let queue = Promise.resolve();
    const enqueue = job => { const result = queue.then(job); queue = result.catch(() => {}); return result; };
    const runPython = args => new Promise((resolve, reject) => {
        const child = spawn(python, args, { stdio: ['ignore', 'pipe', 'pipe'] });
        let errors = '';
        child.stderr.on('data', data => { errors = (errors + data.toString()).slice(-4000); });
        child.stdout.on('data', data => console.log('[AndroidAnalysis]', data.toString().trim()));
        const timer = setTimeout(() => { child.kill(); reject(new Error('Android model inference timed out')); }, 180000);
        child.on('error', error => { clearTimeout(timer); reject(error); });
        child.on('close', code => { clearTimeout(timer); if (code) reject(new Error(errors || 'Model process failed')); else resolve(); });
    });
    const models = createModelStore({ getModelsDirs: dirs, getDownloadDir: directory, builtinRuntime: python,
        onProgress: progress => events.emit('automix-model-progress', progress), onChanged: () => {} });
    const ready = name => Boolean(python && fs.existsSync(python) && resolveModelFile(dirs(), name));
    const readFloats = async file => {
        const bytes = await fsp.readFile(file);
        return new Float32Array(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
    };
    return {
        getAutomixModelsPresent: () => ({ beat_this: ready('beat_this'), htdemucs: ready('htdemucs') }),
        getAutomixModelStatus: () => models.status(),
        downloadAutomixModel: name => models.download(name),
        cancelAutomixModelDownload: name => models.cancel(name),
        installAutomixModel: (name, source) => models.installLocal(name, source),
        scanForAutomixModels: () => models.scan(dirs()),
        removeAllAutomixModels: () => models.removeAll(),
        chooseModelsDirectory: async selected => {
            if (!selected) {
                const selection = await events.native('openDialog', { properties: ['openDirectory', 'createDirectory'] });
                if (selection.canceled) return { canceled: true };
                selected = selection.filePaths[0];
            }
            await fsp.mkdir(selected, { recursive: true });
            store.set('MODELS_DIRECTORY', selected);
            return models.status();
        },
        resetModelsDirectory: () => { store.delete('MODELS_DIRECTORY'); return models.status(); },
        diagMark: text => { console.log('[Automix]', String(text)); },
        runBeatThis: chunks => enqueue(async () => {
            if (!ready('beat_this')) return null;
            if (!Array.isArray(chunks) || !chunks.length) throw new Error('No spectrogram chunks');
            for (const chunk of chunks) if (!Number.isInteger(chunk.frames) || chunk.frames < 1 || chunk.frames > 1500
                || chunk.data?.length !== chunk.frames * 128) throw new Error('Invalid Beat This spectrogram shape');
            const temporary = await fsp.mkdtemp(path.join(process.env.TMPDIR, 'beat-this-'));
            try {
                await fsp.writeFile(path.join(temporary, 'request.json'), JSON.stringify({ frames: chunks.map(chunk => chunk.frames) }));
                for (let index = 0; index < chunks.length; index++) {
                    const floats = Float32Array.from(chunks[index].data);
                    await fsp.writeFile(path.join(temporary, index + '.in'), Buffer.from(floats.buffer));
                }
                await runPython([path.join(__dirname, 'beat_this_android.py'), resolveModelFile(dirs(), 'beat_this'), temporary]);
                const beat = [], downbeat = [];
                for (let index = 0; index < chunks.length; index++) {
                    beat.push(await readFloats(path.join(temporary, index + '.beat')));
                    downbeat.push(await readFloats(path.join(temporary, index + '.downbeat')));
                }
                return { beat, downbeat };
            } finally { await fsp.rm(temporary, { recursive: true, force: true }); }
        }),
        separateStems: request => enqueue(async () => {
            if (!ready('htdemucs')) return null;
            if (!request?.left || !request?.right || request.left.length !== request.right.length
                || request.left.length === 0 || request.left.length > 40 * 44100) throw new Error('Invalid Demucs stereo input');
            return separate({ pythonExe: python, script: RUNNER_SCRIPT, modelPath: resolveModelFile(dirs(), 'htdemucs'),
                left: Float32Array.from(request.left), right: Float32Array.from(request.right) });
        }),
    };
};
