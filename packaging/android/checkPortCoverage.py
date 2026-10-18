from pathlib import Path
import json
import re

# The user requires the whole desktop port before any APK build can begin.
root = Path(__file__).resolve().parents[2]
coverage = json.loads((root / 'packaging/android/portCoverage.json').read_text())
preload = (root / 'electron/preload.cjs').read_text()
expected = set(re.findall(r'^    ([A-Za-z0-9_]+):', preload, re.M))
expected.update('mods.' + name for name in re.findall(r'^        ([A-Za-z0-9_]+):', preload[preload.index('    mods: {'):], re.M))
expected.add('webUtils.getPathForFile')
recorded = coverage['desktopContracts']
# Explicit scope changes do not count as implementation. Only the recorded user exclusion applies.
excluded = set(coverage.get('scopeExclusions', {}).get('discordRichPresence', {}).get('contracts', []))
missing = sorted(name for name in expected if recorded.get(name, {}).get('state') != 'implemented'
    and not (name in excluded and recorded.get(name, {}).get('state') == 'excludedByUser'))
requirements = [name for name, item in coverage['platformRequirements'].items() if item['state'] != 'implemented']
if missing or requirements:
    print(f'APK build blocked: {len(missing)} desktop contract entries and {len(requirements)} platform requirements remain incomplete.')
    print('See packaging/android/portCoverage.json and packaging/android/PORTING.md.')
    raise SystemExit(1)
print('Desktop source port coverage complete. Build and device validation may proceed.')
