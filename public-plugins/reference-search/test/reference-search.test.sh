#!/usr/bin/env bash
# scripts/reference-search.sh 의 회귀 테스트. 네트워크 없이 curl · gh 스텁으로 돈다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/reference-search.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/reference-search-tc.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export STUB="$TMP/stub" REFERENCE_SEARCH_RETRY_WAIT=0
mkdir -p "$STUB" "$TMP/bin" "$TMP/nogh"

# 스텁: routes 의 "부분 문자열 \037 상태 \037 본문 파일" 첫 일치로 답한다. 상태 timeout 은 응답 없음
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w|-m|-A) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s\n' "$url" >> "$STUB/calls"
while IFS=$'\037' read -r pat code body; do
  case "$url" in
    *"$pat"*)
      if [ "$code" = timeout ]; then printf '000'; exit 28; fi
      if [ "$code" = 429once ]; then
        if [ -f "$STUB/once" ]; then code=200; else : > "$STUB/once"; code=429; fi
      fi
      if [ -n "$out" ]; then cat "$body" > "$out"; else cat "$body"; fi
      printf '%s' "$code"; exit 0 ;;
  esac
done < "$STUB/routes"
printf '404'
EOF
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "gh $*" >> "$STUB/calls"
cat "$STUB/gh.json"
EOF
chmod +x "$TMP/bin/curl" "$TMP/bin/gh"
# gh 가 없는 PATH — jq · xmllint 등 나머지는 그대로 찾되 실제 gh 는 가린다
for t in jq xmllint sed grep tr head cat date mktemp rm paste sleep; do
  p="$(command -v "$t")" && ln -sf "$p" "$TMP/nogh/$t"
done
ln -sf "$TMP/bin/curl" "$TMP/nogh/curl"
export PATH="$TMP/bin:$PATH"

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
  : > "$STUB/routes"; : > "$STUB/calls"; N=0
}
section() { flush_tc; echo "$1"; }
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
# route <부분 문자열> <상태> — 본문은 stdin
route() { N=$((N+1)); cat > "$STUB/body.$N"; printf '%s\037%s\037%s\n' "$1" "$2" "$STUB/body.$N" >> "$STUB/routes"; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_called() { [ "$TC_ON" = 1 ] || return 0; grep -qF -- "$1" "$STUB/calls" || fail_tc "'$1' 를 조회하지 않음: $(cat "$STUB/calls")"; }
expect_not_called() { [ "$TC_ON" = 1 ] || return 0; grep -qF -- "$1" "$STUB/calls" && fail_tc "'$1' 를 조회하면 안 됩니다"; return 0; }
# 첫 줄 JSON 의 칸 값 — expect_field <jq 경로> <기대값(JSON 문자열 표현)>
expect_field() {
  [ "$TC_ON" = 1 ] || return 0
  local got; got="$(printf '%s' "$OUT" | head -1 | jq -c "$1" 2>/dev/null)"
  [ "$got" = "$2" ] || fail_tc "$1 = $got (기대 $2)"
}
expect_lines() { [ "$TC_ON" = 1 ] || return 0; local n; n="$(printf '%s' "$OUT" | grep -c .)"; [ "$n" = "$1" ] || fail_tc "줄 수 $n (기대 $1)"; }

section "== A. 출처별 정규화"

tc TC-S01 "openalex — 칸 정규화, DOI 접두 URL 제거, arXiv 위치에서 ID"
route "api.openalex.org/works?search=" 200 <<'EOF'
{"results":[{"display_name":"A <i>Study</i>","authorships":[{"author":{"display_name":"Kim A"}}],"publication_year":2025,"publication_date":"2025-03-01",
"primary_location":{"source":{"display_name":"Nature"},"landing_page_url":"https://nature.com/x"},"doi":"https://doi.org/10.1038/ABC",
"locations":[{"landing_page_url":"https://arxiv.org/abs/2501.00001"}],"cited_by_count":3,"is_retracted":false,"type":"article","open_access":{"oa_url":null}}]}
EOF
run openalex "agent memory" --from 2024-01-01 --sort date
expect_code 0; expect_field .source '"openalex"'; expect_field .title '"A Study"'; expect_field .doi '"10.1038/abc"'
expect_field .arxiv '"2501.00001"'; expect_field .venue '"Nature"'; expect_field .cited_by 3
expect_called "search=agent%20memory"; expect_called "filter=from_publication_date:2024-01-01"; expect_called "sort=publication_date:desc"

tc TC-S02 "semantic-scholar — externalIds 에서 DOI · arXiv, 기간 필터"
route "paper/search" 200 <<'EOF'
{"data":[{"title":"P","authors":[{"name":"Lee"}],"year":2024,"publicationDate":"2024-05-01","venue":"","externalIds":{"DOI":"10.1/X","ArXiv":"2405.1"},"citationCount":9,"url":"https://s2/p","openAccessPdf":{"url":"https://pdf"},"publicationTypes":["JournalArticle"]}]}
EOF
run semantic-scholar "rag eval" --from 2024-01-01
expect_field .doi '"10.1/x"'; expect_field .arxiv '"2405.1"'; expect_field .venue 'null'; expect_field .open_access_url '"https://pdf"'
expect_called "publicationDateOrYear=2024-01-01:"

tc TC-S03 "crossref — 날짜 0 채움, 저자 이름 합치기"
route "api.crossref.org/works" 200 <<'EOF'
{"message":{"items":[{"DOI":"10.5/Y","title":["T"],"author":[{"given":"Ana","family":"Park"},{"family":"Solo"}],"issued":{"date-parts":[[2026,6,3]]},"container-title":["J"],"is-referenced-by-count":1,"URL":"https://doi.org/10.5/Y","type":"journal-article"}]}}
EOF
run crossref "x" --from 2025-01-01 --sort date
expect_field .date '"2026-06-03"'; expect_field .authors '["Ana Park","Solo"]'; expect_field .doi '"10.5/y"'
expect_called "filter=from-pub-date:2025-01-01"; expect_called "sort=published"

tc TC-S04 "arxiv — Atom 파싱, 단어마다 all: AND, 기간은 submittedDate"
route "export.arxiv.org/api/query" 200 <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:arxiv="http://arxiv.org/schemas/atom">
  <entry>
    <id>http://arxiv.org/abs/2501.12345v2</id>
    <published>2025-01-20T18:00:00Z</published>
    <title>Agent
      Memory</title>
    <author><name>Jane Doe</name></author>
    <author><name>John Roe</name></author>
    <arxiv:doi>10.9/AX</arxiv:doi>
  </entry>
  <entry>
    <id>http://arxiv.org/abs/2502.00002v1</id>
    <published>2025-02-01T00:00:00Z</published>
    <title>Second</title>
    <author><name>Solo</name></author>
  </entry>
</feed>
EOF
run arxiv "agent memory" --from 2025-01-01
expect_code 0; expect_lines 2; expect_field .title '"Agent Memory"'; expect_field .authors '["Jane Doe","John Roe"]'
expect_field .arxiv '"2501.12345v2"'; expect_field .doi '"10.9/ax"'; expect_field .date '"2025-01-20"'; expect_field .venue '"arXiv"'
expect_field .url '"https://arxiv.org/abs/2501.12345v2"'; expect_field .open_access_url '"https://arxiv.org/pdf/2501.12345v2"'
expect_called "all%3Aagent%20AND%20all%3Amemory"; expect_called "submittedDate%3A%5B202501010000"

tc TC-S05 "pubmed — esearch 뒤 esummary, 철회 표시"
route "esearch.fcgi" 200 <<'EOF'
{"esearchresult":{"idlist":["111"]}}
EOF
route "esummary.fcgi" 200 <<'EOF'
{"result":{"uids":["111"],"111":{"uid":"111","title":"Trial.","authors":[{"name":"Roe J"}],"pubdate":"2024 Jan","fulljournalname":"Lancet","articleids":[{"idtype":"doi","value":"10.7/Z"}],"pubtype":["Journal Article","Retracted Publication"]}}}
EOF
run pubmed "crispr" --from 2024-01-01
expect_field .doi '"10.7/z"'; expect_field .is_retracted 'true'; expect_field .year 2024; expect_field .url '"https://pubmed.ncbi.nlm.nih.gov/111/"'
expect_called "mindate=2024/01/01"; expect_called "esummary.fcgi?db=pubmed&id=111"

tc TC-S06 "pubmed — 결과 0건이면 esummary 를 부르지 않는다"
route "esearch.fcgi" 200 <<'EOF'
{"esearchresult":{"idlist":[]}}
EOF
run pubmed "nothing"
expect_code 0; expect_lines 0; expect_not_called "esummary"

tc TC-S07 "biorxiv — Europe PMC 프리프린트 필터, kind preprint"
route "europepmc/webservices/rest/search" 200 <<'EOF'
{"resultList":{"result":[{"id":"PPR1","source":"PPR","title":"Pre <sup>+</sup> print","authorString":"A B, C D.","pubYear":"2026","firstPublicationDate":"2026-10-01","bookOrReportDetails":{"publisher":"bioRxiv"},"doi":"10.1101/1","citedByCount":0}]}}
EOF
run biorxiv "crispr" --sort date
expect_field .source '"biorxiv"'; expect_field .kind '"preprint"'; expect_field .venue '"bioRxiv"'; expect_field .title '"Pre + print"'; expect_field .authors '["A B","C D"]'
expect_called "SRC%3APPR%20AND%20PUBLISHER%3A%22bioRxiv%22"; expect_called "FIRST_PDATE_D"

tc TC-S08 "openreview — content.*.value, forum URL"
route "notes/search" 200 <<'EOF'
{"notes":[{"forum":"abc","pdate":1735689600000,"content":{"title":{"value":"OR Paper"},"authors":{"value":["X"]},"venue":{"value":"ICLR 2025"}}}]}
EOF
run openreview "diffusion"
expect_field .url '"https://openreview.net/forum?id=abc"'; expect_field .venue '"ICLR 2025"'; expect_field .year 2025

tc TC-S09 "huggingface — 검색 결과 상한을 스크립트가 자른다"
route "papers/search" 200 <<'EOF'
[{"paper":{"id":"2512.1","title":"One","authors":[{"name":"A"}],"publishedAt":"2025-12-14T00:00:00Z","upvotes":5}},{"paper":{"id":"2512.2","title":"Two","authors":[],"publishedAt":"2025-12-15T00:00:00Z"}}]
EOF
run huggingface "agent" --limit 1
expect_lines 1; expect_field .arxiv '"2512.1"'; expect_field .upvotes 5

tc TC-S10 "huggingface-daily — 검색어 없이 동작"
route "daily_papers" 200 <<'EOF'
[{"paper":{"id":"2610.1","title":"Daily","authors":[],"publishedAt":"2026-10-25T00:00:00Z"}}]
EOF
run huggingface-daily
expect_code 0; expect_field .title '"Daily"'

tc TC-S11 "hackernews — 날짜 정렬은 search_by_date, 기간은 created_at_i"
route "hn.algolia.com" 200 <<'EOF'
{"hits":[{"title":"Outage post mortem","url":"https://blog/x","author":"u","created_at":"2025-11-18T00:00:00Z","objectID":"9","points":10,"num_comments":2}]}
EOF
run hackernews "postmortem" --from 2025-01-01 --sort date
expect_field .url '"https://blog/x"'; expect_field .discussion_url '"https://news.ycombinator.com/item?id=9"'
expect_called "search_by_date"; expect_called "created_at_i%3E1735689600"

tc TC-S12 "rfc — RFC DOI 와 rfc-editor URL"
route "datatracker" 200 <<'EOF'
{"objects":[{"name":"rfc9312","title":"Manageability of QUIC","rfc_number":9312,"std_level":"/api/v1/name/stdlevelname/inf/"}]}
EOF
run rfc "quic"
expect_field .doi '"10.17487/RFC9312"'; expect_field .url '"https://www.rfc-editor.org/rfc/rfc9312"'; expect_field .std_level '"inf"'

tc TC-S13 "github-repository — gh 결과 정규화"
echo '[{"fullName":"o/r","description":"d","stargazersCount":7,"updatedAt":"2026-10-01T00:00:00Z","url":"https://github.com/o/r"}]' > "$STUB/gh.json"
run github-repository "rag"
expect_field .title '"o/r"'; expect_field .stars 7; expect_called "gh search repos rag"

tc TC-S14 "openalex-citing — DOI 로 작품 ID 를 찾고 cites 필터"
route "works/doi:10.1/seed" 200 <<'EOF'
{"id":"https://openalex.org/W123","referenced_works":[]}
EOF
route "filter=cites:W123" 200 <<'EOF'
{"results":[{"display_name":"Citer","authorships":[],"publication_year":2026,"doi":null,"locations":[],"primary_location":{},"id":"https://openalex.org/W9"}]}
EOF
run openalex-citing "https://doi.org/10.1/SEED"
expect_code 0; expect_field .title '"Citer"'; expect_called "works/doi:10.1/seed"

tc TC-S15 "openalex-references — 참고문헌이 없으면 0건으로 끝난다"
route "works/doi:10.1/seed" 200 <<'EOF'
{"id":"https://openalex.org/W123","referenced_works":[]}
EOF
run openalex-references "10.1/seed"
expect_code 0; expect_lines 0

section "== B. 실패와 사용법"

tc TC-S20 "429 가 두 번이면 종료 6 과 대체 출처 안내"
route "paper/search" 429 <<'EOF'
{"message":"Too Many Requests"}
EOF
run semantic-scholar "x"
expect_code 6; expect_out "openalex"
[ "$TC_ON" = 1 ] && [ "$(grep -c . "$STUB/calls")" = 2 ] || fail_tc "재시도 1회가 아니다"

tc TC-S21 "429 뒤 성공하면 결과를 낸다 — 재시도"
rm -f "$STUB/once"
route "api.crossref.org" 429once <<'EOF'
{"message":{"items":[{"DOI":"10.5/r","title":["Retried"]}]}}
EOF
run crossref "x"
expect_code 0; expect_field .title '"Retried"'

tc TC-S22 "응답 없음 → 종료 5"
route "api.openalex.org" timeout </dev/null
run openalex "x"
expect_code 5; expect_out "응답 없음"

tc TC-S23 "HTTP 500 → 종료 5"
route "api.openalex.org" 500 <<'EOF'
oops
EOF
run openalex "x"
expect_code 5; expect_out "HTTP 500"

tc TC-S24 "키가 필요한 출처 → 종료 3, 조회하지 않음"
run kci "논문"
expect_code 3; expect_out "TODO"
[ "$TC_ON" = 1 ] && [ ! -s "$STUB/calls" ] || fail_tc "조회하면 안 된다"

tc TC-S25 "모르는 출처 → 종료 2"
run banana "x"
expect_code 2

tc TC-S26 "검색어가 없으면 종료 2"
run openalex
expect_code 2

tc TC-S27 "--limit · --from 형식 오류 → 종료 2"
run openalex "x" --limit abc
expect_code 2
run openalex "x" --from 2025/01/01
expect_code 2

tc TC-S28 "gh 가 없으면 github-* 만 종료 4"
if [ -x /usr/bin/gh ] || [ -x /bin/gh ]; then TC_ON=0; fi
[ "$TC_ON" = 1 ] && { OUT="$(PATH="$TMP/nogh:/usr/bin:/bin" "$SCRIPT" github-code "x" 2>&1)"; CODE=$?; }
expect_code 4; expect_out "gh"

tc TC-S29 "값 없는 마지막 옵션 → 바로 종료 2 (무한 루프 없음)"
run openalex "x" --limit
expect_code 2; expect_out "값이 없다"
run openalex "x" --sort newest
expect_code 2

tc TC-S30 "arxiv — 불용어를 빼고 질의한다"
route "export.arxiv.org/api/query" 200 <<'EOF'
<?xml version="1.0" encoding="UTF-8"?><feed xmlns="http://www.w3.org/2005/Atom"></feed>
EOF
run arxiv "Attention is all you need"
expect_code 0; expect_called "all%3Aattention%20AND%20all%3Aall%20AND%20all%3Ayou%20AND%20all%3Aneed"; expect_not_called "all%3Ais"

tc TC-S31 "huggingface · openreview — --from 이전 결과를 거른다"
route "papers/search" 200 <<'EOF'
[{"paper":{"id":"2005.1","title":"Old","authors":[],"publishedAt":"2020-05-22T00:00:00Z"}},{"paper":{"id":"2501.1","title":"New","authors":[],"publishedAt":"2025-01-02T00:00:00Z"}}]
EOF
route "notes/search" 200 <<'EOF'
{"notes":[{"forum":"o","pdate":1577836800000,"content":{"title":{"value":"Old OR"}}},{"forum":"n","pdate":1735689600000,"content":{"title":{"value":"New OR"}}}]}
EOF
run huggingface "x" --from 2024-01-01
expect_lines 1; expect_field .title '"New"'
run openreview "x" --from 2024-01-01
expect_lines 1; expect_field .title '"New OR"'

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
