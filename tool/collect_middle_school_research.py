"""Collect unclassified source material, never app-ready learning content.

Network collection (resumable, rate limited):
  python tool/collect_middle_school_research.py --fetch --cache /tmp/kanji-research
Offline reproducibility check:
  python tool/collect_middle_school_research.py --check

Only writes docs/content/middle-school-research/; does not change allocations,
assets, lessons, translations, representative readings, or progress IDs.
"""
import argparse
from datetime import date
import gzip
import hashlib
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/content/middle-school-research'
SOURCE = ROOT / 'docs/content/middle-school-source-catalog.json'
FIELDS = ('character', 'onyomiSource', 'kunyomiSource', 'koreanReadingSource', 'meaningsEnSource')


def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def fetch_pages(language, titles, cache):
    """A failed request is not a missing page; never publish partial HTTP results."""
    result = {}
    ordered = sorted(set(titles))
    cache.mkdir(parents=True, exist_ok=True)
    for start in range(0, len(ordered), 40):
        batch = ordered[start:start + 40]
        key = sha(encode([language, batch]))[:20]
        path = cache / f'{language}-{key}.json'
        if not path.exists():
            params = dict(action='query', prop='revisions', rvprop='ids|timestamp|content',
                          rvslots='main', titles='|'.join(batch), format='json', formatversion=2,
                          maxlag=5)
            url = f'https://{language}.wiktionary.org/w/api.php?' + urllib.parse.urlencode(params)
            request = urllib.request.Request(url, headers={
                'User-Agent': 'SukuSukuKanjiSourceCollector/1.0 (https://github.com/hae-i/sukusukukanji)',
            })
            for attempt in range(5):
                try:
                    with urllib.request.urlopen(request, timeout=60) as response:
                        payload = response.read()
                    data = json.loads(payload)
                    if 'error' in data:
                        raise ValueError(f'MediaWiki error: {data["error"].get("code")}')
                    if 'query' not in data or 'pages' not in data['query']:
                        raise ValueError('Missing API result')
                    # Cache only successful validated responses, atomically.
                    tmp = path.with_suffix('.tmp')
                    tmp.write_bytes(payload)
                    tmp.replace(path)
                    break
                except (OSError, ValueError, urllib.error.URLError) as error:
                    if attempt == 4:
                        raise RuntimeError(f'Could not collect {language} batch {start}') from error
                    delay = 10 * (attempt + 1)
                    if isinstance(error, urllib.error.HTTPError):
                        retry = error.headers.get('Retry-After', '')
                        if retry.isdigit():
                            delay = max(delay, int(retry))
                    print(f'{language} batch {start}: retry in {delay}s', flush=True)
                    time.sleep(delay)
            time.sleep(3)
        data = json.loads(path.read_bytes())
        normalized = {v['to']: v['from'] for v in data['query'].get('normalized', [])}
        returned = set()
        for page in data['query']['pages']:
            requested = normalized.get(page['title'], page['title'])
            returned.add(requested)
            revisions = page.get('revisions', [])
            if 'missing' not in page and not revisions:
                raise ValueError(f'No revision for existing page {language}:{requested}')
            record = {'requestedTitle': requested, 'title': page['title'], 'language': language}
            if revisions:
                rev = revisions[0]
                record.update(revision=rev['revid'], timestamp=rev['timestamp'],
                              wikitext=rev['slots']['main']['content'])
            else:
                record['missing'] = True
            result[f'{language}:{requested}'] = record
        if returned != set(batch):
            raise ValueError(f'API title mismatch: {set(batch) ^ returned}')
        print(f'{language}: {min(start + 40, len(ordered))}/{len(ordered)}', flush=True)
    return result


def section(text, name):
    match = re.search(r'^==\s*' + re.escape(name) + r'\s*==\s*$', text, re.M)
    if not match:
        return ''
    return re.split(r'^==[^=].*?==\s*$', text[match.end():], maxsplit=1, flags=re.M)[0]


def variants(text):
    # Source candidates only: merged old forms may not share the same senses.
    results = []
    for fields in re.findall(r'\{\{ja-kanji forms\|([^}\n]+)', text):
        results.extend(f.strip() for f in fields.split('|')[1:] if len(f.strip()) == 1)
    for field in re.findall(r'\bkyu=([^|}\n]+)', text):
        results.extend(c for c in re.split(r'[,、 /]+', field.strip()) if len(c) == 1)
    return sorted(set(c for c in results if '\u3400' <= c <= '\u9fff' or ord(c) >= 0x20000))


def candidates(record):
    text = record.get('wikitext', '')
    # Preserve wikitext, rather than interpreting annotations or guessing senses.
    glosses = re.findall(r'\{\{(?:한자풀이\b|ko-hanja\|).*?\}\}', text, re.S)
    words = []
    for line in section(text, '일본어').splitlines():
        match = re.search(r'\[\[([^\]|]+)\]\]/\[\[([ぁ-ゖァ-ヺー .]+)\]\]', line)
        if match:
            words.append({'wordSource': match[1], 'readingSource': match[2], 'sourceLine': line})
    connections = [line for line in section(text, '한국어').splitlines()
                   if re.search(r'\[\[[\u3400-\u9fff]+\]\]/\[\[[가-힣]+\]\]', line)]
    return {'koreanGlossTemplates': glosses, 'japaneseWordCandidates': words,
            'koreanConnectionLines': connections}


def build(snapshot):
    raw = SOURCE.read_bytes()
    if sha(raw) != snapshot['dictionaryCatalogSha256']:
        raise ValueError('Source catalog changed; create a separately reviewed snapshot')
    old = json.loads(raw)
    original = {k['character']: k for k in old['kanji']}
    elementary = json.loads((ROOT / 'docs/content/education-kanji-source-catalog.json').read_bytes())
    elementary_chars = {k['character'] for g in elementary['grades'] for k in g['kanji']}
    if len(original) != 1110 or original.keys() & elementary_chars:
        raise ValueError('Expected 1,110 unique non-elementary Joyo characters')
    pages = snapshot['pages']
    records = []
    sources = {}
    for key, page in sorted(pages.items()):
        if not page.get('missing'):
            sources[key] = {k: page[k] for k in ('title', 'language', 'revision', 'timestamp')}
            sources[key].update(
                sha256=sha(page['wikitext'].encode()),
                isRedirect=bool(re.match(r'^\s*#(?:redirect|넘겨주기)', page['wikitext'], re.I)),
                url=f'https://{page["language"]}.wiktionary.org/w/index.php?oldid={page["revision"]}',
                attribution='Wiktionary page contributors; see linked revision history',
            )
    for character, k in sorted(original.items()):
        record = {f: k[f] for f in FIELDS}
        record.update(reviewStatus='unreviewed-source-material',
                      traditionalFormCandidates=[], evidence=[], missingPages=[])
        for lang in ('ko', 'en'):
            key = f'{lang}:{character}'
            if key not in pages:
                raise ValueError(f'Uncollected page: {key}')
            page = pages[key]
            if page.get('missing'):
                record['missingPages'].append(key)
                continue
            record['evidence'].append({'sourceKey': key, **candidates(page)})
            if lang == 'en':
                record['traditionalFormCandidates'] = variants(page['wikitext'])
        for title in record['traditionalFormCandidates']:
            if title == character:
                continue
            key = f'ko:{title}'
            if key not in pages:
                raise ValueError(f'Uncollected traditional form: {key}')
            if pages[key].get('missing'):
                record['missingPages'].append(key)
            else:
                record['evidence'].append({'sourceKey': key, **candidates(pages[key])})
        records.append(record)
    coverage = {
        'characters': len(records), 'foundPages': len(sources),
        'missingPages': sum(bool(p.get('missing')) for p in pages.values()),
        'withKoreanHanjaTemplates': sum(any(e['koreanGlossTemplates'] for e in r['evidence']) for r in records),
        'withJapaneseWordCandidates': sum(any(e['japaneseWordCandidates'] for e in r['evidence']) for r in records),
        'withKoreanConnectionCandidates': sum(any(e['koreanConnectionLines'] for e in r['evidence']) for r in records),
        'withTraditionalFormCandidates': sum(bool(r['traditionalFormCandidates']) for r in records),
    }
    return {'schemaVersion': 1, 'kind': 'unclassified-source-research-not-learning-content',
            'collectedAt': snapshot['collectedAt'], 'reviewStatus': 'unreviewed',
            'ordering': 'Unicode codepoint for lookup only; not a teaching order',
            'dictionaryReference': old['dictionaryReference'], 'dictionarySha256': old['dictionarySha256'],
            'dictionaryHeader': old['sourceHeader'], 'dictionaryCatalogSha256': sha(raw),
            'license': 'CC BY-SA 4.0; upstream page-specific notices also apply',
            'dictionaryAttribution': old['attribution'], 'coverage': coverage,
            'sources': sources, 'kanji': records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--cache', type=Path)
    args = parser.parse_args()
    if args.fetch and (args.check or args.cache is None):
        parser.error('--fetch requires --cache and cannot be combined with --check')
    path = OUT / 'wiktionary-snapshot.json.gz'
    if args.fetch:
        original = json.loads(SOURCE.read_bytes())
        titles = [k['character'] for k in original['kanji']]
        pages = {}
        for lang in ('ko', 'en'):
            pages.update(fetch_pages(lang, titles, args.cache))
        extra = {c for k, v in pages.items() if k.startswith('en:')
                 for c in variants(v.get('wikitext', ''))} - set(titles)
        pages.update(fetch_pages('ko', extra, args.cache))
        snapshot = {'schemaVersion': 1, 'collectedAt': date.today().isoformat(),
                    'dictionaryCatalogSha256': sha(SOURCE.read_bytes()), 'pages': dict(sorted(pages.items()))}
        index = build(snapshot)  # Validate completeness before publishing either file.
        OUT.mkdir(parents=True, exist_ok=True)
        path.write_bytes(gzip.compress(encode(snapshot), mtime=0))
    else:
        snapshot = json.loads(gzip.decompress(path.read_bytes()))
        index = build(snapshot)
    index['snapshotSha256'] = sha(path.read_bytes())
    target = OUT / 'index.json'
    expected = encode(index)
    if args.check:
        if target.read_bytes() != expected:
            raise SystemExit('Research index does not match the source snapshot')
    else:
        target.write_bytes(expected)
    print(json.dumps(index['coverage'], ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
