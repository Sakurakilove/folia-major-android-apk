from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import tarfile
import urllib.request

# Rebuild libraries whose upstream archives do not satisfy Android's 16 KiB LOAD alignment.
def prepare_webp(root, cache, architecture, abi, directory):
    archive = cache / 'libwebp-1.6.0.tar.gz'
    if not archive.exists():
        urllib.request.urlretrieve('https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz', archive)
    expected = '93a852c2b3efafee3723efd4636de855b46f9fe1efddd607e1f42f60fc8f2136'
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
        raise RuntimeError('WebP source checksum mismatch')
    source = cache / 'libwebp-1.6.0'
    if not source.exists():
        with tarfile.open(archive) as package:
            package.extractall(cache, filter='data')
    ndk = Path(os.environ['ANDROID_NDK_HOME'])
    cmake = os.environ.get('CMAKE', 'cmake')
    build = cache / ('webp-build-' + abi)
    options = [cmake, '-S', str(source), '-B', str(build), '-DCMAKE_TOOLCHAIN_FILE=' + str(ndk / 'build/cmake/android.toolchain.cmake'),
               '-DANDROID_ABI=' + abi, '-DANDROID_PLATFORM=android-24', '-DCMAKE_BUILD_TYPE=Release', '-DBUILD_SHARED_LIBS=ON',
               '-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384']
    for tool in ['ANIM_UTILS', 'CWEBP', 'DWEBP', 'GIF2WEBP', 'IMG2WEBP', 'VWEBP', 'WEBPINFO', 'WEBPMUX']:
        options.append('-DWEBP_BUILD_' + tool + '=OFF')
    subprocess.run(options, check=True)
    subprocess.run([cmake, '--build', str(build), '-j2'], check=True)
    for name in ['libwebp', 'libwebpmux', 'libwebpdemux', 'libwebpdecoder', 'libsharpyuv']:
        library = next(build.rglob(name + '.so'))
        destination = directory / 'lib' / library.name
        if destination.is_symlink():
            destination = destination.resolve()
        shutil.copy2(library, destination)


def prepare_spotify(root, cache, architecture, abi, native):
    # The npm lock pins the wrapper, Rust source and Cargo.lock to the desktop dependency version.
    original = root / 'packaging/android/runtime/node_modules/@lox-audioserver/node-librespot'
    source = cache / 'librespot'
    source.mkdir(exist_ok=True)
    for name in ['Cargo.toml', 'Cargo.lock', 'build.rs']:
        shutil.copy2(original / name, source / name)
    shutil.copytree(original / 'src', source / 'src', dirs_exist_ok=True)
    target = 'aarch64-linux-android' if architecture == 'aarch64' else 'x86_64-linux-android'
    triple = target.replace('-', '_')
    toolchain = Path(os.environ['ANDROID_NDK_HOME']) / 'toolchains/llvm/prebuilt/linux-x86_64/bin'
    env = os.environ.copy()
    env.update({ 'CARGO_BUILD_JOBS': '2', 'CC_' + triple: str(toolchain / (target + '24-clang')),
                 'AR_' + triple: str(toolchain / 'llvm-ar'), 'CARGO_TARGET_' + triple.upper() + '_LINKER': str(toolchain / (target + '24-clang')),
                 'RUSTFLAGS': '-C link-arg=-Wl,-z,max-page-size=16384' })
    subprocess.run([os.environ.get('CARGO', 'cargo'), 'build', '--release', '--locked', '--target', target, '--manifest-path', str(source / 'Cargo.toml')], env=env, check=True)
    shutil.copy2(source / 'target' / target / 'release/liblibrespot_addon.so', native / 'liblibrespot-addon.so')


def assert_16k(file):
    if file.open('rb').read(4) != b'\x7fELF':
        return
    output = subprocess.check_output(['readelf', '-lW', str(file)], text=True)
    for line in output.splitlines():
        if line.strip().startswith('LOAD') and int(line.split()[-1], 16) < 16384:
            raise RuntimeError('ELF does not support 16 KiB pages: ' + str(file))
