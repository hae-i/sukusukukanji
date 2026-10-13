"""Build static elementary assets from the committed source-review snapshot.

Run: python tool/build_elementary_content.py [--check]
No network, translation, reading inference, or runtime content generation.
To change learning content, review sources and edit elementary-audit.json first.
Existing grade-one IDs/order/content are deliberately not rewritten.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COUNTS = {1: 80, 2: 160, 3: 200, 4: 202, 5: 193, 6: 191}


def build():
    audit = json.loads((ROOT / 'docs/content/elementary-audit.json').read_text())
    source = json.loads((ROOT / 'docs/content/education-kanji-source-catalog.json').read_text())
    if audit['dictionarySourceSha256'] != source['sourceSha256']:
        raise ValueError('Dictionary snapshot changed; review before rebuilding')
    chars = set()
    output = {}
    for grade, count in COUNTS.items():
        official = audit['officialGrades'][str(grade)]
        dictionary_rows = {k['character']: k for k in source['grades'][grade - 1]['kanji']}
        dictionary = set(dictionary_rows)
        if len(official) != count or set(official) != dictionary or chars.intersection(official):
            raise ValueError(f'Official/dictionary allocation mismatch: grade {grade}')
        chars.update(official)
        if grade == 1:
            old = json.loads((ROOT / 'assets/data/kanji/grade1.json').read_text())
            if {k['character'] for k in old['kanji']} != dictionary:
                raise ValueError('Grade one must retain its official membership')
            continue
        reviewed = [k for k in audit['kanji'] if k['grade'] == grade]
        if len(reviewed) != count or {k['character'] for k in reviewed} != dictionary:
            raise ValueError(f'Incomplete review: grade {grade}')
        items = []
        for i, k in enumerate(reviewed):
            raw = dictionary_rows[k['character']]
            if (k['meaningTags'] != raw['meaningsEnSource'] or
                    k['sourceKoreanReadings'] != raw['koreanReadingSource']):
                raise ValueError('Dictionary evidence changed; recheck the source')
            if (k['lessonId'], k['lessonOrder']) != (i // 5 + 1, i % 5 + 1):
                raise ValueError('Lesson order changed; review progress compatibility')
            for name, complete in [('onyomi', 'allOnyomi'), ('kunyomi', 'allKunyomi')]:
                official_readings = {r['reading'] for r in k['officialReadings']}
                if not set(k[name]) <= official_readings.intersection(k[complete]):
                    raise ValueError(f'Unsourced reading: {k["character"]}')
            if not k['koreanMeanings'] or not k['koreanReading'] or not k['sourceKeys']:
                raise ValueError('Missing reviewed learning fields')
            if len(k['examples']) != len(k['exampleEvidence']):
                raise ValueError('Missing example provenance')
            refs = [
                {'label': '문부과학성 학년 배당·학교급별 음훈표', 'url': audit['officialReference']},
                {'label': 'KANJIDIC2 · EDRDG (CC BY-SA 4.0)', 'url': 'https://www.edrdg.org/wiki/index.php/KANJIDIC_Project'},
            ]
            for key in k['sourceKeys']:
                s = audit['sources'][key]
                refs.append({'label': f'Wiktionary 기여자 · {s["title"]} ({s["language"]})', 'url': s['url']})
            fields = ['character', 'grade', 'koreanReading', 'koreanMeanings', 'onyomi',
                      'kunyomi', 'allOnyomi', 'allKunyomi', 'meaningTags', 'examples',
                      'koreanConnections', 'lessonId', 'lessonOrder']
            item = {'id': f'g{grade}-{ord(k["character"]):x}', **{f: k[f] for f in fields}}
            for field in ['traditionalCharacter', 'koreanHanja']:
                if k.get(field):
                    item[field] = k[field]
            if k.get('traditionalCharacter'):
                item['japaneseCharacter'] = k['character']
            item.update(references=refs, verifiedAt=audit['verifiedAt'])
            items.append(item)
        output[ROOT / f'assets/data/kanji/grade{grade}.json'] = json.dumps(
            {'schemaVersion': 1, 'grade': grade, 'kanji': items}, ensure_ascii=False, indent=2
        ) + '\n'
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for path, text in build().items():
        if args.check:
            if not path.exists() or path.read_text() != text:
                raise SystemExit(f'Stale asset: {path.relative_to(ROOT)}')
        else:
            path.write_text(text)
        print(f'{"Checked" if args.check else "Built"}: {path.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
