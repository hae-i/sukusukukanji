"""Extract source facts, never app-ready Korean learning content.

Usage: python tool/collect_education_kanji.py kanjidic2.xml.gz output.json
Source: https://www.edrdg.org/kanjidic/kanjidic2.xml.gz (CC BY-SA 4.0)
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
raw = args.source.read_bytes()
root = ET.fromstring(gzip.decompress(raw))
groups = {grade: [] for grade in range(1, 7)}
for entry in root.findall('character'):
    grade = entry.findtext('misc/grade')
    if grade is None or int(grade) not in groups:
        continue
    def readings(kind):
        return [r.text for r in entry.findall('.//reading') if r.get('r_type') == kind]
    groups[int(grade)].append({
        'character': entry.findtext('literal'),
        'onyomiSource': readings('ja_on'),
        'kunyomiSource': readings('ja_kun'),
        'koreanReadingSource': readings('korean_h'),
        'meaningsEnSource': [m.text for m in entry.findall('.//meaning') if m.get('m_lang') is None],
    })
counts = {g: len(items) for g, items in groups.items()}
if counts != {1: 80, 2: 160, 3: 200, 4: 202, 5: 193, 6: 191}:
    raise ValueError(f'Unexpected education-grade counts; recheck official curriculum: {counts}')
characters = [k['character'] for items in groups.values() for k in items]
if len(set(characters)) != 1026:
    raise ValueError('Duplicate characters in source')
output = {
    'kind': 'source-catalog-not-app-learning-content',
    'reference': 'https://www.edrdg.org/kanjidic/kanjidic2.xml.gz',
    'sourceSha256': hashlib.sha256(raw).hexdigest(),
    'sourceHeader': {n.tag: n.text for n in root.find('header')},
    'license': 'CC BY-SA 4.0',
    'attribution': 'James William BREEN and The Electronic Dictionary Research and Development Group',
    'grades': [{'grade': g, 'count': len(groups[g]), 'kanji': sorted(groups[g], key=lambda k: k['character'])} for g in groups],
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Collected 1,026 characters: {counts}')
