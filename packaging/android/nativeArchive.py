from pathlib import Path
import hashlib
import json
import zipfile

# Retain SONAME aliases as links instead of shipping identical ELF payloads several times.
def pack_runtime(directory: Path, output: Path, audit):
    links, canonical = {}, {}
    count = 0
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        files = sorted(directory.rglob('*'), key=lambda p: (len(p.relative_to(directory).parts), p.as_posix()))
        for source in files:
            if not source.is_file():
                continue
            relative = source.relative_to(directory)
            if relative.parts[0] not in ['lib', 'etc', 'share']:
                continue
            if relative.parts[0] == 'share' and relative.parts[1] not in ['licenses', 'doc', 'icu', 'ffmpeg', 'terminfo']:
                continue
            if '/include/' in '/' + relative.as_posix() or source.suffix == '.a' or '__pycache__' in relative.parts:
                continue
            resolved = source.resolve()
            audit(resolved)
            with resolved.open('rb') as handle:
                elf = handle.read(4) == b'\x7fELF'
            if elf:
                digest = hashlib.file_digest(resolved.open('rb'), 'sha256').hexdigest()
                if digest in canonical:
                    links[relative.as_posix()] = canonical[digest]
                    continue
                canonical[digest] = relative.as_posix()
            archive.write(resolved, relative.as_posix())
            count += 1
        archive.writestr('.folia-runtime-links.json', json.dumps(links))
    return count, len(links)
