"""Build an app-authored 350/400/360 allocation, not reviewed learning cards.

Usage: python tool/collect_middle_school_kanji.py kanjidic2.xml.gz joyo.json
KANJIDIC2 grade=8 means all remaining Joyo, NOT Japanese school grade 8.
The independent Joyo list must be downloaded from kanjiapi.dev/v1/kanji/joyo.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

CURRICULUM = 'https://www.mext.go.jp/content/1413522_002.pdf'
DICTIONARY = 'https://www.edrdg.org/kanjidic/kanjidic2.xml.gz'
JOYO = 'https://kanjiapi.dev/v1/kanji/joyo'
SIZES = (350, 400, 360)


def collect(raw, joyo_raw):
    root = ET.fromstring(gzip.decompress(raw))
    entries = root.findall('character')
    elementary = [e for e in entries if e.findtext('misc/grade') in {'1', '2', '3', '4', '5', '6'}]
    secondary = [e for e in entries if e.findtext('misc/grade') == '8']
    elementary_chars = {e.findtext('literal') for e in elementary}
    secondary_chars = {e.findtext('literal') for e in secondary}
    joyo_list = json.loads(joyo_raw)
    aliases = {'剥': '剝', '叱': '𠮟', '填': '塡', '頬': '頰'}
    joyo_chars = {aliases.get(c, c) for c in joyo_list}
    if len(joyo_list) not in (2136, 2140) or len(joyo_chars) != 2136:
        raise ValueError('Independent Joyo list must normalize to 2,136 unique characters')
    if len(elementary) != 1026 or len(elementary_chars) != 1026:
        raise ValueError('Expected 1,026 unique elementary characters')
    if len(secondary) != 1110 or len(secondary_chars) != 1110:
        raise ValueError('Expected 1,110 unique secondary characters')
    if elementary_chars & secondary_chars or elementary_chars | secondary_chars != joyo_chars:
        raise ValueError('Dictionary membership differs from independent Joyo list')

    # Frequency is newspaper usage from KANJIDIC2, not an official difficulty grade.
    secondary.sort(key=lambda e: (int(e.findtext('misc/freq') or '99999'), int(e.findtext('misc/stroke_count')), e.findtext('literal')))
    courses = []
    facts = []
    offset = 0
    for year, count in enumerate(SIZES, 1):
        group = secondary[offset:offset + count]
        courses.append({'grade': 6 + year, 'schoolYear': year, 'count': count, 'characters': [e.findtext('literal') for e in group]})
        for position, e in enumerate(group):
            def readings(kind):
                return [r.text for r in e.findall('.//reading') if r.get('r_type') == kind]
            facts.append({'character': e.findtext('literal'), 'courseGrade': 6 + year, 'lessonId': position // 5 + 1, 'lessonOrder': position % 5 + 1, 'dictionaryGrade': 8, 'frequencyRank': int(e.findtext('misc/freq')) if e.findtext('misc/freq') else None, 'strokeCount': int(e.findtext('misc/stroke_count')), 'onyomiSource': readings('ja_on'), 'kunyomiSource': readings('ja_kun'), 'koreanReadingSource': readings('korean_h'), 'meaningsEnSource': [m.text for m in e.findall('.//meaning') if m.get('m_lang') is None]})
        offset += count
    allocation = {'schemaVersion': 1, 'allocationVersion': 1, 'kind': 'app-authored-course-allocation', 'noteKo': '문부과학성의 학년별 읽기 목표를 참고한 앱 자체 배정입니다. 공식 학년별 한자 배당표가 아닙니다.', 'orderingKo': 'KANJIDIC2의 신문 사용 빈도순으로 배정하고, 빈도 정보가 없는 한자는 획수와 문자순으로 배정했습니다. 학습 난이도를 보증하는 순서는 아닙니다.', 'references': [{'label': '문부과학성 중학교 학습지도요령 (2017)', 'url': CURRICULUM}, {'label': 'KANJIDIC2 · EDRDG / James William BREEN · CC BY-SA 4.0', 'url': DICTIONARY}, {'label': '상용한자 목록 교차 확인 · kanjiapi.dev', 'url': JOYO}, {'label': '사전 데이터 이용 조건 · CC BY-SA 4.0', 'url': 'https://creativecommons.org/licenses/by-sa/4.0/'}], 'courses': courses}
    audit = {'kind': 'source-catalog-not-app-learning-content', 'allocationVersion': 1, 'dictionaryReference': DICTIONARY, 'dictionarySha256': hashlib.sha256(raw).hexdigest(), 'sourceHeader': {e.tag: e.text for e in root.find('header')}, 'joyoReference': JOYO, 'joyoSha256': hashlib.sha256(joyo_raw).hexdigest(), 'joyoRawCount': len(joyo_list), 'joyoVariantAliases': aliases, 'joyoVariantReference': 'https://github.com/onlyskin/kanjiapi.dev#list-of-joyo-kanji', 'curriculumReference': CURRICULUM, 'license': 'CC BY-SA 4.0', 'attribution': 'James William BREEN and The Electronic Dictionary Research and Development Group', 'readingTargets': {'1': {'additionalMin': 300, 'additionalMax': 400}, '2': {'additionalMin': 350, 'additionalMax': 450}, '3': 'Read most of the remaining Joyo kanji'}, 'reviewStatus': 'Korean meanings, representative readings and examples require separate review before learning cards are enabled.', 'kanji': facts}
    return allocation, audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dictionary', type=Path)
    parser.add_argument('joyo', type=Path)
    parser.add_argument('--allocation', type=Path, default=Path('assets/data/middle-school-allocation.json'))
    parser.add_argument('--audit', type=Path, default=Path('docs/content/middle-school-source-catalog.json'))
    args = parser.parse_args()
    allocation, audit = collect(args.dictionary.read_bytes(), args.joyo.read_bytes())
    if args.allocation.exists() and json.loads(args.allocation.read_text())['courses'] != allocation['courses']:
        raise ValueError('Published assignments changed; explicitly version and migrate the allocation before replacing it')
    for path, document in ((args.allocation, allocation), (args.audit, audit)):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
    print('Verified 2,136 Joyo = 1,026 elementary + 1,110 secondary; allocated 350 / 400 / 360')


if __name__ == '__main__':
    main()
