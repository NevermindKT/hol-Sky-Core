"""Check coverage and formatting without loading the game's large assets."""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
catalog = {}
for path in (ROOT / 'localization/catalogs').glob('*.csv'):
    for row in csv.DictReader(path.open(encoding='utf-8', newline='')):
        catalog[row['source']] = row

required = set()
dialogues = json.loads((ROOT / 'jsons/dialogues.json').read_text(encoding='utf-8'))
for line in dialogues.values():
    for field in ['segments', 'choices', 'interrupt_choices']:
        required.update(entry['text'] for entry in line.get(field, []))
for speaker in json.loads((ROOT / 'jsons/speakers.json').read_text(encoding='utf-8')).values():
    if speaker['name'].strip():
        required.add(speaker['name'])
for table in json.loads((ROOT / 'objects.json').read_text(encoding='utf-8')).values():
    for row in table:
        required.update(v for k, v in row.items() if k in {
            'Name', 'BaseName', 'Monsters', 'Description', 'Descriprion', 'Hardness'
        } and isinstance(v, str) and v)
placeholders = {'WeaponName', 'Ammo/Ammo', 'A', 'UI', 'TIME', 'DAMAGE', 'KILLS', 'Abshxd'}
for folder in ['scenes/menu', 'scenes/general', 'scenes/ui', 'addons/dialogue_system']:
    for path in (ROOT / folder).rglob('*.tscn'):
        for raw in re.findall(r'^text = "((?:[^"\\]|\\.)*)"', path.read_text(encoding='utf-8'), re.M):
            value = raw.replace('\\n', '\n').replace('\\"', '"')
            if value not in placeholders and any(c.isalpha() for c in value):
                required.add(value)
missing = sorted(required - catalog.keys())
assert not missing, 'Missing translations:\n' + '\n'.join(repr(s) for s in missing)
for source, row in catalog.items():
    for locale in ['uk', 'en', 'ru']:
        value = row[locale]
        assert value.strip(), (source, locale, 'empty')
        assert re.findall(r'%[dsf]', source) == re.findall(r'%[dsf]', value), (source, locale, 'format')
print(f'Catalog coverage OK: {len(dialogues)} dialogue lines, {len(required)} unique visible strings; {len(catalog)} translations per language')
