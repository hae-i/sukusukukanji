# 중등 한자 자료 수집 — 미분류·미검수

2026-10-13 수집. 초등 교육한자 1,026자를 제외한 상용한자 **1,110자**의 사전 원문과 후보 자료입니다. 학년·레슨을 배정하지 않았으며 Flutter assets, 기존 중등 배정, 학습 화면에는 연결하지 않았습니다. Unicode 순서는 검색용일 뿐 학습 순서가 아닙니다.

## 수집 범위

| 항목 | 수량 |
| --- | ---: |
| KANJIDIC2 원문 읽기·영어 뜻을 보관한 한자 | 1,110자 |
| 한국어 한자 풀이/읽기 템플릿 후보가 있는 한자 | 1,098자 |
| 일본어 단어와 읽기 후보가 있는 한자 | 108자 |
| 한국어 한자어 연결 후보가 있는 한자 | 72자 |
| 구자체 후보가 있는 한자 | 184자 |
| 확보한 Wiktionary 문서 | 2,224개 |
| 조회했으나 존재하지 않은 문서 | 163개 |

문서 수는 한국어·영어판 및 구자체 후보 조회를 합산한 값으로 한자 수와 다릅니다. 후보 수는 추출기의 인식 범위이며, 사전에 자료가 존재하는 전체 범위나 정확성이 검증된 수량을 뜻하지 않습니다. 한국어 템플릿에는 뜻 없이 음만 있는 경우도 있습니다. 구자체 대응은 통합 자형·의미 차이를 별도 확인해야 합니다.

## 파일

- `index.json`: 기존 KANJIDIC2 카탈로그의 읽기/영어 뜻, Wiktionary 후보, 문서 판 번호·수정 시각·URL·해시·누락 목록. 모든 항목은 `unreviewed-source-material`입니다.
- `wiktionary-snapshot.json.gz`: 수집한 원본 문서 wikitext와 판 번호. 네트워크 없이 후보를 재생성하고 대조할 수 있습니다.
- `official-references.json`: 공식 자료 URL와 내려받은 학습지도요령 PDF의 해시. 공식 문자별 중1/2/3 분류를 의미하지 않습니다.

일본어 단어·읽기와 한국어 연결은 원문 행 그대로 함께 보관합니다. 한국어 뜻을 자동 번역하거나 대표 읽기·예문을 생성하지 않았습니다. 원문의 오타, 오래된 표현, 언어별 용례 및 라이선스 조건을 검토한 후에만 앱 콘텐츠로 채택해야 합니다. KANJIDIC의 grade 8은 중학교 2학년이라는 뜻이 아닙니다.

## 재현

저장소 루트에서 실행합니다. Python 표준 라이브러리만 필요합니다.

```sh
python tool/collect_middle_school_research.py --check
python -m unittest discover -s tool -p 'test_middle_school_research.py'
# 원본 스냅샷에서 index.json 재생성
python tool/collect_middle_school_research.py
# 명시적인 재수집: 캐시를 재사용하므로 새 수집은 새 캐시 경로 사용
python tool/collect_middle_school_research.py --fetch --cache /tmp/kanji-research
```

통신 실패를 자료 없음으로 처리하지 않습니다. 필수 문서 조회가 끝나야 결과를 저장하며, 기존 카탈로그 해시 변경 시 재검토를 요구합니다.

## 출처와 이용 조건

KANJIDIC2: James William BREEN 및 EDRDG, [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), 원문 https://www.edrdg.org/kanjidic/kanjidic2.xml.gz. 원본 헤더·해시는 index에 보관합니다.

Wiktionary: 각 한국어/영어판 문서 기여자. index의 `sources`에 문서별 고정 판 URL과 저작자 표시를 보관하며 해당 문서의 history에서 기여자를 확인할 수 있습니다. [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) 및 각 원문에 명시된 별도 출처·조건을 확인해야 합니다. 원본 문서는 gzip 안에 보존했습니다. 변경은 수집·필드 추출·정렬이며 문장이나 번역을 새로 작성하지 않았습니다. 이 자료의 라이선스는 앱 코드·브랜드 라이선스와 별개입니다.

다음 단계는 후보 검수와 부족한 단어/한국어 풀이 보강입니다. 학년별 분류는 별도 결정 후 진행합니다.
