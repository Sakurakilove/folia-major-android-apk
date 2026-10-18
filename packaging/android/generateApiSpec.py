from pathlib import Path
import json
import re

# Keep Android's channel names derived from the original preload contract.
root = Path(__file__).resolve().parents[2]
source = (root / 'electron/preload.cjs').read_text()
result = {}
for prefix, text, indentation in [('', source, 4), ('mods.', source[source.index('    mods: {'):], 8)]:
    members = list(re.finditer(r'^' + ' ' * indentation + r'([A-Za-z0-9_]+):', text, re.M))
    for index, member in enumerate(members):
        name = prefix + member.group(1)
        if name in ['mods', 'webUtils']:
            continue
        body = text[member.end():members[index + 1].start() if index + 1 < len(members) else len(text)]
        item = {}
        for key, pattern in [('channel', r"ipcRenderer\.invoke\('([^']+)'"),
                             ('event', r"ipcRenderer\.on\('([^']+)'"),
                             ('send', r"ipcRenderer\.send\('([^']+)'")]:
            match = re.search(pattern, body)
            if match:
                item[key] = match.group(1)
        if item:
            result[name] = item
(root / 'shared/androidApiSpec.json').write_text(json.dumps(result, indent=2) + '\n')
print('Generated Android desktop channel mappings:', len(result))
