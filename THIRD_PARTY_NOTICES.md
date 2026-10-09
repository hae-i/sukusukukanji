# Learning content attribution

The grade-one dataset in `assets/data/kanji/grade1.json` incorporates a small selection of readings and grade facts from **KANJIDIC2**, obtained from the original EDRDG XML and through [kanjiapi.dev](https://kanjiapi.dev/).

Copyright: James William BREEN and The Electronic Dictionary Research and Development Group.

- Project and documentation: https://www.edrdg.org/wiki/index.php/KANJIDIC_Project
- Dictionary licence and attribution requirements: https://www.edrdg.org/edrdg/licence.html
- Licence: [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/)

Korean readings, meanings, Japanese examples, and Korean connections were checked against Korean/English Wiktionary articles and the Wikipedia Korean numerals article. Attribution is to the contributors of those respective pages; individual source URLs are included in each record's `references` and their page histories identify contributors.

Changes: selected beginner readings; removed KANJIDIC okurigana separator dots; omitted names; selected representative readings for display and retained sourced alternative readings to exclude valid quiz distractors; added Korean presentation wording, stable IDs, lesson ordering, provenance and application schema.

The kanji dictionary fields are provided under CC BY-SA 4.0; the separately attributed sentence fields use CC BY 2.0 FR as described below. This notice applies to that dataset, not to the application source code or branding. No endorsement by any source contributor is implied.

An attribution screen is available under 앱 안내, and individual references are visible in each kanji's detail screen. Recheck upstream content before releases and when correcting or extending entries; update `verifiedAt` only after checking the cited fields again.

Grade-one membership was checked against MEXT: https://www.mext.go.jp/a_menu/shotou/cs/1319951.htm. New records cite specific Wiktionary revisions; source snapshot hashes and the KANJIDIC2 header are recorded in docs/content/grade1-audit.json. The 町 Wiktionary page also credits the National Institute of Korean Language dictionaries under CC BY-SA 2.0 KR: https://creativecommons.org/licenses/by-sa/2.0/kr/.

The source-only education catalog in docs/content/education-kanji-source-catalog.json is also derived from KANJIDIC2 under CC BY-SA 4.0. It preserves original reading notation and English senses and groups 1,026 characters by the dictionary education grade. The source header and SHA-256 are retained. It is not bundled as app learning content.

## Bundled fonts

- **Noto Sans JP**, obtained from https://github.com/google/fonts/tree/main/ofl/notosansjp. Copyright 2014–2021 Adobe, Reserved Font Name Source; SIL Open Font License 1.1. The variable source SHA-256 is `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`. Bundled regular (wght=400) and bold (wght=700) files are static instances made using fontTools without changing glyph designs. Original licence: assets/fonts/NotoSansJP-OFL.txt.
- **Pretendard v1.3.9**, copyright 2021 Kil Hyung-jin, Reserved Font Name Pretendard; SIL Open Font License 1.1. Regular/Medium/SemiBold/Bold OTF files are unmodified files from https://github.com/orioncactus/pretendard/releases/tag/v1.3.9. Original licence: assets/fonts/Pretendard-OFL.txt.

Both licences are bundled as Flutter assets and registered in LicenseRegistry, accessible through the settings licence screen. No font is downloaded at runtime.


## Grade-one example sentences

The `sentences` fields in `assets/data/kanji/grade1.json` reproduce existing Japanese and Korean text contributed to [Tatoeba](https://tatoeba.org/). Each pair includes URLs to both sentence pages and their contributing users, displayed together with dictionary attribution in the 학습 자료 출처 dialog, opened using the app bar information icon. The texts are unchanged. Readings, when included, come only from contributor-reviewed transcriptions, with ruby markup converted to plain text. Attribution to transcription contributors is retained alongside the sentence authors.

Licence: [Creative Commons Attribution 2.0 France](https://creativecommons.org/licenses/by/2.0/fr/). Both Japanese and Korean licences were checked individually against the sentence API. Selection, sentence IDs, authors, direct/indirect translation linkage and text SHA-256 hashes are recorded in `docs/content/grade1-sentences-audit.json`. These sentence fields retain their separate licence and are not covered by the kanji dictionary field licence above. No audio is used and no Tatoeba endorsement is implied.
