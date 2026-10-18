from pathlib import Path
import shutil
import subprocess
import zipfile

# Assemble only the Android server dependencies and the unchanged desktop implementations.
root = Path(__file__).resolve().parents[2]
runtime = root / 'packaging/android/runtime'
subprocess.run(['python3', str(root / 'packaging/android/generateApiSpec.py')], check=True)
if not (runtime / 'node_modules').exists():
    raise SystemExit('Run npm ci --prefix packaging/android/runtime --ignore-scripts first')
for name in ['electron', 'shared']:
    shutil.copytree(root / name, runtime / name, dirs_exist_ok=True)
subprocess.run(['node', str(root / 'packaging/android/extractDesktop.cjs')], check=True)
if (root / 'dist').exists():
    shutil.rmtree(runtime / 'dist', ignore_errors=True)
    shutil.copytree(root / 'dist', runtime / 'dist', dirs_exist_ok=True)
source = (root / 'electron/main.cjs').read_text()
start = source.index('function getGeminiResponseSchema()')
end = source.index('const fsp = fs.promises;', start)
exports = 'getGeminiResponseSchema, THEME_JSON_SCHEMA, THEME_JSON_SCHEMA_NAME, THEME_MAX_OUTPUT_TOKENS, buildThemeSystemPrompt, buildThemeSourcePrompt'
(runtime / 'shared/themePrompt.cjs').write_text(
    '// Generated from electron/main.cjs by prepareRuntime.py.\n' + source[start:end]
    + '\nmodule.exports = {' + exports + '};\n')
destination = root / 'android/app/src/main/assets/node-runtime.zip'
destination.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for file in sorted(runtime.rglob('*')):
        if not file.is_file() or file.is_symlink():
            continue
        relative = file.relative_to(runtime)
        if ('.bin' in relative.parts or '.cache' in relative.parts
            or file.name.endswith(('.map', '.d.ts'))
            or any(part in ['.github', '__tests__', '__pycache__'] for part in relative.parts)
            or ('@lox-audioserver' in relative.parts and 'prebuilds' in relative.parts)
            or relative.as_posix().startswith('node_modules/@neteasecloudmusicapienhanced/api/public/docs/')):
            continue
        archive.write(file, relative.as_posix())
print(f'Prepared Android Node runtime: {destination.stat().st_size // 1024 // 1024} MiB')
