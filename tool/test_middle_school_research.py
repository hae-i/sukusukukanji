"""Research provenance and extraction boundaries; no network required."""
import copy
import gzip
import json
import unittest

import collect_middle_school_research as collector


class ResearchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = (collector.OUT / 'wiktionary-snapshot.json.gz').read_bytes()
        cls.snapshot = json.loads(gzip.decompress(cls.raw))
        cls.index = collector.build(cls.snapshot)

    def test_reproducible_index_and_source_hashes(self):
        expected = dict(self.index, snapshotSha256=collector.sha(self.raw))
        self.assertEqual((collector.OUT / 'index.json').read_bytes(), collector.encode(expected))
        for key, source in expected['sources'].items():
            page = self.snapshot['pages'][key]
            self.assertEqual(source['sha256'], collector.sha(page['wikitext'].encode()))
            self.assertTrue(source['url'].endswith(f"oldid={page['revision']}"))

    def test_target_set_and_no_classification(self):
        source = json.loads(collector.SOURCE.read_bytes())
        chars = {r['character'] for r in self.index['kanji']}
        self.assertEqual(len(chars), 1110)
        self.assertEqual(chars, {r['character'] for r in source['kanji']})
        allowed = set(collector.FIELDS) | {'reviewStatus', 'traditionalFormCandidates', 'evidence', 'missingPages'}
        for record in self.index['kanji']:
            self.assertEqual(set(record), allowed)
            self.assertEqual(record['reviewStatus'], 'unreviewed-source-material')
            for evidence in record['evidence']:
                self.assertIn(evidence['sourceKey'], self.index['sources'])

    def test_missing_page_is_distinct_from_uncollected(self):
        snapshot = copy.deepcopy(self.snapshot)
        char = self.index['kanji'][0]['character']
        key = f'ko:{char}'
        snapshot['pages'][key] = {'missing': True}
        index = collector.build(snapshot)
        self.assertIn(key, index['kanji'][0]['missingPages'])
        self.assertNotIn(key, index['sources'])
        del snapshot['pages'][key]
        with self.assertRaisesRegex(ValueError, 'Uncollected page'):
            collector.build(snapshot)

    def test_source_change_requires_review(self):
        snapshot = dict(self.snapshot, dictionaryCatalogSha256='invalid')
        with self.assertRaisesRegex(ValueError, 'Source catalog changed'):
            collector.build(snapshot)

    def test_word_candidates_are_language_scoped_and_preserve_source(self):
        line = '* [[学校]]/[[がっこう]]: 학교'
        text = f'== 일본어 ==\n{line}\n== 중국어 ==\n* [[山]]/[[やま]]\n'
        words = collector.candidates({'wikitext': text})['japaneseWordCandidates']
        self.assertEqual(words, [{'wordSource': '学校', 'readingSource': 'がっこう', 'sourceLine': line}])
        self.assertFalse(collector.candidates({})['japaneseWordCandidates'])

    def test_variant_candidates_do_not_include_new_form_or_parameters(self):
        self.assertEqual(collector.variants('{{ja-kanji forms|学|學|type=shinjitai}}'), ['學'])


if __name__ == '__main__':
    unittest.main()
