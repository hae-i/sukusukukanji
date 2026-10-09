# Learning content attribution

The grade-one dataset in `assets/data/kanji/grade1.json` incorporates a small selection of readings and grade facts from **KANJIDIC2**, obtained from the original EDRDG XML and through [kanjiapi.dev](https://kanjiapi.dev/).

Copyright: James William BREEN and The Electronic Dictionary Research and Development Group.

- Project and documentation: https://www.edrdg.org/wiki/index.php/KANJIDIC_Project
- Dictionary licence and attribution requirements: https://www.edrdg.org/edrdg/licence.html
- Licence: [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/)

Korean readings, meanings, Japanese examples, and Korean connections were checked against Korean/English Wiktionary articles and the Wikipedia Korean numerals article. Attribution is to the contributors of those respective pages; individual source URLs are included in each record's `references` and their page histories identify contributors.

Changes: selected beginner readings; removed KANJIDIC okurigana separator dots; omitted names; selected representative readings for display and retained sourced alternative readings to exclude valid quiz distractors; added Korean presentation wording, stable IDs, lesson ordering, provenance and application schema.

The combined learning dataset is provided under CC BY-SA 4.0. This notice applies to that dataset, not to the application source code or branding. No endorsement by any source contributor is implied.

An attribution screen is available under 앱 안내, and individual references are visible in each kanji's detail screen. Recheck upstream content before releases and when correcting or extending entries; update `verifiedAt` only after checking the cited fields again.

Grade-one membership was checked against MEXT: https://www.mext.go.jp/a_menu/shotou/cs/1319951.htm. New records cite specific Wiktionary revisions; source snapshot hashes and the KANJIDIC2 header are recorded in docs/content/grade1-audit.json. The 町 Wiktionary page also credits the National Institute of Korean Language dictionaries under CC BY-SA 2.0 KR: https://creativecommons.org/licenses/by-sa/2.0/kr/.

The source-only education catalog in docs/content/education-kanji-source-catalog.json is also derived from KANJIDIC2 under CC BY-SA 4.0. It preserves original reading notation and English senses and groups 1,026 characters by the dictionary education grade. The source header and SHA-256 are retained. It is not bundled as app learning content.
