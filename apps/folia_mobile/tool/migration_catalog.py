#!/usr/bin/env python3
"""Inventory actual baseline entry points and refuse delivery while parity evidence is incomplete."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
APP = ROOT / 'apps/folia_mobile'
BASELINE = '45d7d8a27afc7efb7a33308824def68329a86651'
CATALOG = APP / 'migration/catalog.json'
STATUS = APP / 'migration/status.json'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode()


def expected_features():
    paths = git('ls-tree', '-r', '--name-only', BASELINE).splitlines()
    features = {}
    patterns = {
        'visualizer': r'src/components/visualizer/([^/]+)/entry\.tsx',
        'background': r'src/components/visualizer/backgrounds/([^/]+)/entry\.tsx',
        'library': r'src/library/suites/([^/]+)/entry\.ts',
        'provider': r'src/services/onlineMusic/([^/]+)/\1Provider\.ts',
        'settings': r'src/components/modal/settings/pages/([A-Z][A-Za-z]+)Page\.tsx',
        'commands': r'src/components/command-palette/commands/([^/]+Commands?)\.ts',
    }
    for category, pattern in patterns.items():
        for path in paths:
            match = re.fullmatch(pattern, path)
            if match:
                features[f'{category}:{match[1]}'] = [path]
    features.update({
        'app:shell-navigation-transitions': ['src/App.tsx', 'src/components/app/AppShell.tsx', 'src/index.css'],
        'app:branding-fonts-accessibility': ['src/utils/fontStacks.ts', 'src/components/AppSplashGate.tsx', 'public/icon.svg'],
        'app:all-lyric-formats-and-editing': ['src/utils/lyrics'],
        'app:queue-playback-media': ['src/components/app/playback', 'src/services/playbackAdapters.ts'],
        'app:all-audio-effects': ['src/services/audioEffects', 'src/utils/audioEffects.ts'],
        'app:automix': ['src/services/automix'],
        'app:navidrome': ['src/services/navidromeService.ts'],
        'app:storage-data-credentials': ['src/services/db.ts', 'src/stores', 'android/app/src/main/java'],
        'app:sync-backup-import-export': ['src/services/sync'],
        'app:mods-and-custom-content': ['src/mods', 'mods'],
        'app:ai-themes-segmentation': ['src/services', 'src/components/modal/ThemePark.tsx'],
        'app:system-integrations': ['shared/androidApiSpec.json', 'packaging/android/runtime'],
        'app:obs-remote-stage-export-wallpaper': ['src/components/app', 'electron'],
        'app:liquid-glass-all-surfaces': ['src/platform/android/installAndroidGlass.ts', 'android/app/src/main/java'],
        'app:equal-workload-power': ['docs/android/POWER_REWRITE.md'],
    })
    # A wrong source path must not silently shrink the task inventory.
    for feature, sources in features.items():
        for source in sources:
            if not any(path == source or path.startswith(source + '/') for path in paths):
                raise ValueError(f'{feature}: baseline source does not exist: {source}')
    return paths, dict(sorted(features.items()))


def generate():
    paths, features = expected_features()
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(json.dumps({'baseline': BASELINE,
        'note': 'Entry-point coverage inventory, not proof of complete feature/visual equivalence.',
        'sourceTrees': {name: git('rev-parse', f'{BASELINE}:{name}').strip()
                        for name in ['src', 'public', 'electron', 'shared', 'android', 'packaging/android']},
        'features': features}, ensure_ascii=False, indent=2) + '\n')
    current = json.loads(STATUS.read_text()) if STATUS.exists() else {'baseline': BASELINE, 'features': {}}
    for feature in features:
        current['features'].setdefault(feature, {'state': 'pending', 'nativeSources': [], 'evidence': None})
    STATUS.write_text(json.dumps(current, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(features)} baseline feature groups inventoried; new groups default to pending.')


def check():
    _, expected = expected_features()
    catalog, status = json.loads(CATALOG.read_text()), json.loads(STATUS.read_text())
    failures = []
    if catalog['baseline'] != BASELINE or status['baseline'] != BASELINE or catalog['features'] != expected:
        failures.append('Baseline/catalog mismatch; regenerate without changing the baseline.')
    if set(status['features']) != set(expected):
        failures.append('Feature status entries must cover every baseline entry point.')
    for name in expected:
        record = status['features'].get(name, {})
        if record.get('state') != 'verified' or not record.get('nativeSources') or not record.get('evidence'):
            failures.append(f'{name}: not verified')
            continue
        evidence_path = (ROOT / record['evidence']).resolve()
        if not evidence_path.is_relative_to(ROOT) or not evidence_path.is_file():
            failures.append(f'{name}: missing local evidence')
            continue
        evidence = json.loads(evidence_path.read_text())
        if evidence.get('baseline') != BASELINE:
            failures.append(f'{name}: evidence baseline mismatch')
        for kind in ['functional', 'visual', 'animation']:
            result = evidence.get(kind, {})
            if result.get('passed') is not True or not result.get('observations') or not result.get('comparisonInputs'):
                failures.append(f'{name}: missing {kind} comparison record')
        if name == 'app:equal-workload-power':
            power = evidence.get('power', {})
            if not all(power.get(key) for key in ['device', 'conditions', 'baselineMeasurement', 'nativeMeasurement']):
                failures.append(f'{name}: missing same-device/workload measurements')
        for source in record['nativeSources']:
            file = (ROOT / source).resolve()
            if not file.is_relative_to(APP) or not file.is_file():
                failures.append(f'{name}: missing native source {source}')
            elif evidence.get('sourceHashes', {}).get(source) != hashlib.sha256(file.read_bytes()).hexdigest():
                failures.append(f'{name}: source changed since comparison: {source}')
    if failures:
        print('DELIVERY BLOCKED: full migration and strict original frontend parity are not verified.')
        print('\n'.join(failures[:16]))
        if len(failures) > 16:
            print(f'... {len(failures) - 16} further incomplete checks')
        return 1
    print('Recorded parity evidence is complete and current; this gate validates records, not the truth of visual observations.')
    return 0


if __name__ == '__main__':
    if sys.argv[1:] == ['generate']:
        generate()
    elif sys.argv[1:] == ['check']:
        raise SystemExit(check())
    else:
        raise SystemExit('Usage: migration_catalog.py generate|check')
