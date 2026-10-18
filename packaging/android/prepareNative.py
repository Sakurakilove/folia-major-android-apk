from pathlib import Path
import concurrent.futures
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile
import sys
from nativeLibraries import prepare_webp, prepare_spotify, assert_16k
from nativeArchive import pack_runtime

# Package Android/bionic Node 24, FFmpeg and the actual NumPy/ORT Python runtime.
root = Path(__file__).resolve().parents[2]
cache = root / 'packaging/android/.cache/termux'
cache.mkdir(parents=True, exist_ok=True)
repository = 'https://packages.termux.dev/apt/termux-main/'
prefix = 'data/data/com.termux/files/usr/'
targets = [('aarch64', 'arm64-v8a'), ('x86_64', 'x86_64')]
requested_abis = os.environ.get('FOLIA_ANDROID_ABIS', 'arm64-v8a').split(',')
targets = [(architecture, abi) for architecture, abi in targets if abi in requested_abis]
if not targets:
    raise SystemExit('No supported Android ABIs requested')
package_roots = ['nodejs-lts', 'ffmpeg', 'python', 'python-numpy', 'python-onnxruntime']

def read_index(architecture):
    index = cache / ('Packages-' + architecture)
    if not index.exists():
        data = urllib.request.urlopen(repository + 'dists/stable/main/binary-' + architecture + '/Packages.gz', timeout=60).read()
        index.write_bytes(gzip.decompress(data))
    packages = {}
    for block in index.read_text().split('\n\n'):
        fields = {}
        key = None
        for line in block.splitlines():
            if line.startswith(' ') and key:
                fields[key] += ' ' + line.strip()
            elif ': ' in line:
                key, value = line.split(': ', 1)
                fields[key] = value
        if 'Package' in fields:
            packages[fields['Package']] = fields
    return packages

def resolve(packages):
    selected = {}
    def visit(name):
        if name in selected:
            return
        package = packages[name]
        selected[name] = package
        for group in package.get('Depends', '').split(','):
            candidates = [re.split(r'[ (]', item.strip())[0] for item in group.split('|')]
            dependency = next((item for item in candidates if item in packages), None)
            if dependency:
                visit(dependency)
    for name in package_roots:
        visit(name)
    return selected

def download(package):
    destination = cache / Path(package['Filename']).name
    if not destination.exists() or hashlib.sha256(destination.read_bytes()).hexdigest() != package['SHA256']:
        urllib.request.urlretrieve(repository + package['Filename'], destination)
    if hashlib.sha256(destination.read_bytes()).hexdigest() != package['SHA256']:
        raise RuntimeError('Package checksum mismatch: ' + package['Package'])
    return destination

def extract(package_file, directory):
    names = subprocess.check_output(['ar', 't', str(package_file)], text=True).splitlines()
    member = next(name for name in names if name.startswith('data.tar'))
    data = subprocess.check_output(['ar', 'p', str(package_file), member])
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as archive:
        for entry in archive:
            name = entry.name.lstrip('./')
            if not name.startswith(prefix):
                continue
            relative = name[len(prefix):]
            if not relative or '..' in Path(relative).parts:
                continue
            destination = directory / relative
            if entry.isdir():
                destination.mkdir(parents=True, exist_ok=True)
            elif entry.isfile():
                destination.parent.mkdir(parents=True, exist_ok=True)
                if destination.is_symlink():
                    destination.unlink()
                with destination.open('wb') as output:
                    shutil.copyfileobj(archive.extractfile(entry), output)
                destination.chmod(entry.mode)
            elif entry.issym():
                target = entry.linkname
                if target.startswith('/data/data/com.termux/files/usr/'):
                    target = os.path.relpath(directory / target[len('/data/data/com.termux/files/usr/'):], destination.parent)
                destination.parent.mkdir(parents=True, exist_ok=True)
                if destination.is_symlink() or destination.exists():
                    destination.unlink()
                destination.symlink_to(target)

for architecture, abi in targets:
    packages = resolve(read_index(architecture))
    print(abi + ': fetching ' + str(len(packages)) + ' verified packages', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        downloaded = list(pool.map(download, packages.values()))
    directory = cache / abi / 'usr'
    directory.mkdir(parents=True, exist_ok=True)
    if '--repack' not in sys.argv:
        for package_file in downloaded:
            extract(package_file, directory)
        prepare_webp(root, cache, architecture, abi, directory)
    native = root / 'android/app/src/main/jniLibs' / abi
    native.mkdir(parents=True, exist_ok=True)
    if '--repack' not in sys.argv:
        prepare_spotify(root, cache, architecture, abi, native)
    if not (native / 'liblibrespot-addon.so').is_file():
        raise RuntimeError('Build the Spotify native addon before repacking')
    for stale in ['libnode.so', 'libfolia-node.so', 'libc++_shared.so']:
        (native / stale).unlink(missing_ok=True)
    runners = {'node': 'libnode-runner.so', 'python3': 'libpython-runner.so', 'ffmpeg': 'libffmpeg-runner.so'}
    for executable, output in runners.items():
        source = directory / 'bin' / executable
        shutil.copy2(source.resolve(), native / output)
        (native / output).chmod(0o755)
        program_headers = subprocess.check_output(['readelf', '-lW', str(native / output)], text=True)
        for line in program_headers.splitlines():
            if line.strip().startswith('LOAD') and int(line.split()[-1], 16) < 16384:
                raise RuntimeError(output + ' is not aligned to 16 KiB')
    for library in native.glob('*.so'):
        assert_16k(library)
    assets = root / 'android/app/src/main/assets'
    assets.mkdir(parents=True, exist_ok=True)
    output = assets / ('native-runtime-' + abi + '.zip')
    count, link_count = pack_runtime(directory, output, assert_16k)
    print(f'{abi}: {count} files, {link_count} deduplicated ELF aliases', flush=True)
    manifest = {name: {'version': item['Version'], 'sha256': item['SHA256'], 'url': repository + item['Filename']}
                for name, item in packages.items()}
    (assets / ('native-runtime-' + abi + '.json')).write_text(json.dumps(manifest, indent=2) + '\n')
    print(abi + ': ' + str(count) + ' runtime files, ' + str(output.stat().st_size // 1048576) + ' MiB', flush=True)
