#!/usr/bin/env bash
# 키 없이 쓰는 학술 · 기술 API 를 조회해 한 줄에 결과 하나씩 정규화 JSON 으로 낸다.
#   reference-search.sh <출처> <검색어> [--from YYYY-MM-DD] [--limit N] [--sort relevance|date]
#   reference-search.sh openalex-citing <DOI>      이 논문을 인용한 논문 (forward 스노볼링)
#   reference-search.sh openalex-references <DOI>  이 논문의 참고문헌 (backward 스노볼링)
#   reference-search.sh huggingface-daily          오늘의 Hugging Face Papers
# 칸: source title authors year date venue doi arxiv url cited_by is_retracted kind
# 종료 코드: 0 성공(결과 0건 포함) · 2 사용법 · 3 키 필요(미구현) · 4 도구 없음 · 5 네트워크 · HTTP 오류 · 6 요청 한도
set -uo pipefail

UA="reference-search (Claude Code plugin)"
OPENALEX="${REFERENCE_SEARCH_OPENALEX_API:-https://api.openalex.org}"
S2="${REFERENCE_SEARCH_S2_API:-https://api.semanticscholar.org/graph/v1}"
CROSSREF="${REFERENCE_SEARCH_CROSSREF_API:-https://api.crossref.org}"
ARXIV="${REFERENCE_SEARCH_ARXIV_API:-https://export.arxiv.org/api/query}"
EUTILS="${REFERENCE_SEARCH_EUTILS_API:-https://eutils.ncbi.nlm.nih.gov/entrez/eutils}"
EUROPEPMC="${REFERENCE_SEARCH_EUROPEPMC_API:-https://www.ebi.ac.uk/europepmc/webservices/rest}"
OPENREVIEW="${REFERENCE_SEARCH_OPENREVIEW_API:-https://api2.openreview.net}"
HF="${REFERENCE_SEARCH_HF_API:-https://huggingface.co/api}"
HN="${REFERENCE_SEARCH_HN_API:-https://hn.algolia.com/api/v1}"
DATATRACKER="${REFERENCE_SEARCH_DATATRACKER_API:-https://datatracker.ietf.org/api/v1}"

# TODO(키 필요 — 키 발급 뒤 출처로 추가):
#   kci        한국학술지인용색인 Open API (공공데이터포털 인증키)
#   riss       RISS Open API (인증키)
#   scienceon  KISTI ScienceON API (인증키)
#   ntis       국가R&D 보고서 API (인증키)
#   core       CORE API v3 (API 키)
#   unpaywall  오픈액세스 원문 위치 (요청마다 이메일)
#   ieee       IEEE Xplore API (API 키)
#   springer   Springer Nature API (API 키)
#   scopus     Elsevier Scopus API (API 키 + 기관 구독)
#   semantic-scholar 키 — 지금은 키 없이 공유 한도로 부른다. x-api-key 헤더를 붙이면 한도가 늘어난다
#   openalex 키 · mailto — 지금은 키 없이 부른다. 사용 조건이 바뀌면 여기서 붙인다

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
die() { echo "reference-search: $2" >&2; exit "$1"; }
need() { command -v "$1" >/dev/null 2>&1 || die 4 "$1 이 없다 — $SOURCE 출처를 쓸 수 없다"; }
uri() { jq -rn --arg v "$1" '$v|@uri'; }

BODY="$(mktemp "${TMPDIR:-/tmp}/reference-search.XXXXXX")" || exit 5
trap 'rm -f "$BODY"' EXIT

# GET 하고 상태 코드로 판정한다. 429 는 한 번 쉬고 다시 부른다
fetch() {
  local url="$1" code try=0
  while :; do
    code="$(curl -s -L -m "${TIMEOUT:-20}" -A "$UA" -o "$BODY" -w '%{http_code}' "$url" 2>/dev/null)"
    case "$code" in
      200) return 0 ;;
      429) try=$((try+1)); [ "$try" -le 1 ] || die 6 "$SOURCE 요청 한도 (429). 잠시 뒤 다시 하거나 다른 출처를 쓴다${FALLBACK:+ — $FALLBACK}"
           sleep "${REFERENCE_SEARCH_RETRY_WAIT:-3}" ;;
      000) die 5 "$SOURCE 응답 없음 (네트워크 · 시간 초과)${FALLBACK:+ — $FALLBACK}" ;;
      *)   die 5 "$SOURCE HTTP $code" ;;
    esac
  done
}

# 공통 칸을 채우는 jq 정의
NORM='def clean: if . == null then null else (tostring | gsub("<[^>]+>"; "") | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ")) end;
      def nodoi: if . == null then null else (ascii_downcase | sub("^https?://(dx\\.)?doi\\.org/"; "")) end;'

SOURCE="${1:-}"; [ -n "$SOURCE" ] || usage; shift
QUERY=""; FROM=""; LIMIT=8; SORT=relevance
while [ $# -gt 0 ]; do
  case "$1" in
    --from|--limit|--sort)
      [ $# -ge 2 ] || die 2 "$1 에 값이 없다"
      case "$1" in --from) FROM="$2" ;; --limit) LIMIT="$2" ;; --sort) SORT="$2" ;; esac
      shift 2 ;;
    -h|--help) usage ;;
    *) QUERY="${QUERY:+$QUERY }$1"; shift ;;
  esac
done
case "$LIMIT" in ''|*[!0-9]*) die 2 "--limit 은 숫자다" ;; esac
case "$SORT" in relevance|date) ;; *) die 2 "--sort 는 relevance · date 다" ;; esac
[ -z "$FROM" ] || printf '%s' "$FROM" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || die 2 "--from 은 YYYY-MM-DD 다"
case "$SOURCE" in huggingface-daily) ;; *) [ -n "$QUERY" ] || usage ;; esac
need curl; need jq
Q="$(uri "$QUERY")"

openalex_out() {
  jq -c "$NORM"' .results[]? | {source: "openalex", title: (.display_name | clean), authors: [.authorships[]?.author.display_name][0:5],
    year: .publication_year, date: .publication_date, venue: (.primary_location.source.display_name // null),
    doi: (.doi | nodoi), arxiv: ([.locations[]?.landing_page_url // empty | select(test("arxiv\\.org/abs/")) | sub(".*arxiv\\.org/abs/"; "")][0] // null),
    url: (.primary_location.landing_page_url // .doi // .id), cited_by: .cited_by_count, is_retracted: .is_retracted,
    kind: .type, open_access_url: .open_access.oa_url}' "$BODY"
}

case "$SOURCE" in
  openalex)
    url="$OPENALEX/works?search=$Q&per-page=$LIMIT"
    [ -n "$FROM" ] && url="$url&filter=from_publication_date:$FROM"
    [ "$SORT" = date ] && url="$url&sort=publication_date:desc"
    fetch "$url"; openalex_out ;;

  openalex-citing|openalex-references)
    doi="$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://(dx\.)?doi\.org/##')"
    fetch "$OPENALEX/works/doi:$doi"
    wid="$(jq -r '.id // empty | sub(".*/"; "")' "$BODY")"; [ -n "$wid" ] || die 5 "$SOURCE OpenAlex 에 없는 DOI — $doi"
    if [ "$SOURCE" = openalex-citing ]; then
      fetch "$OPENALEX/works?filter=cites:$wid&per-page=$LIMIT&sort=cited_by_count:desc"
    else
      refs="$(jq -r --argjson n "$LIMIT" '[.referenced_works[]? | sub(".*/"; "")][0:$n] | join("|")' "$BODY")"
      [ -n "$refs" ] || exit 0
      fetch "$OPENALEX/works?filter=openalex:$refs&per-page=$LIMIT&sort=cited_by_count:desc"
    fi
    openalex_out ;;

  semantic-scholar)
    FALLBACK="openalex 로 같은 검색어를 찾는다"
    url="$S2/paper/search?query=$Q&limit=$LIMIT&fields=title,authors,year,publicationDate,venue,externalIds,citationCount,url,openAccessPdf,publicationTypes"
    [ -n "$FROM" ] && url="$url&publicationDateOrYear=$FROM:"
    fetch "$url"
    jq -c "$NORM"' .data[]? | {source: "semantic-scholar", title: (.title | clean), authors: [.authors[]?.name][0:5], year, date: .publicationDate,
      venue: (if .venue == "" then null else .venue end), doi: (.externalIds.DOI // null | nodoi), arxiv: (.externalIds.ArXiv // null),
      url, cited_by: .citationCount, is_retracted: null, kind: ((.publicationTypes // [])[0] // null), open_access_url: (.openAccessPdf.url // null)}' "$BODY" ;;

  crossref)
    url="$CROSSREF/works?query=$Q&rows=$LIMIT&select=DOI,title,author,issued,container-title,is-referenced-by-count,URL,type"
    [ -n "$FROM" ] && url="$url&filter=from-pub-date:$FROM"
    [ "$SORT" = date ] && url="$url&sort=published&order=desc"
    fetch "$url"
    jq -c "$NORM"' .message.items[]? | {source: "crossref", title: ((.title // [null])[0] | clean),
      authors: [.author[]? | ([.given, .family] | map(select(. != null)) | join(" "))][0:5],
      year: (.issued["date-parts"][0][0] // null), date: ((.issued["date-parts"][0] // []) | map(tostring | if length == 1 then "0" + . else . end) | join("-") | if . == "" then null else . end),
      venue: ((.["container-title"] // [null])[0]), doi: (.DOI | nodoi), arxiv: null, url: .URL,
      cited_by: .["is-referenced-by-count"], is_retracted: null, kind: .type, open_access_url: null}' "$BODY" ;;

  arxiv)
    need xmllint
    # arXiv 는 한도에 걸리면 429 를 30초 가까이 늦게 돌려준다
    TIMEOUT=45; FALLBACK="openalex 로 같은 검색어를 찾는다 (arXiv 논문도 색인돼 있다)"
    # arXiv 는 단어마다 all: 을 AND 로 잇는데, 불용어가 하나라도 끼면 0건이 된다
    words="$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' '\n' \
      | grep -vxE 'a|an|and|are|as|at|be|by|for|from|in|into|is|it|its|of|on|or|that|the|this|to|was|were|will|with' | paste -sd ' ' -)"
    [ -n "$words" ] || words="$QUERY"
    sq="all:$(printf '%s' "$words" | sed 's/[[:space:]]\{1,\}/ AND all:/g')"
    [ -n "$FROM" ] && sq="$sq AND submittedDate:[$(printf '%s' "$FROM" | tr -d '-')0000 TO 299912312359]"
    by=relevance; [ "$SORT" = date ] && by=submittedDate
    fetch "$ARXIV?search_query=$(uri "$sq")&start=0&max_results=$LIMIT&sortBy=$by&sortOrder=descending"
    n="$(xmllint --xpath "count(//*[local-name()='entry'])" "$BODY" 2>/dev/null || echo 0)"
    i=1
    while [ "$i" -le "${n%.*}" ]; do
      e="(//*[local-name()='entry'])[$i]"
      x() { xmllint --xpath "string($e/$1)" "$BODY" 2>/dev/null; }
      authors="$(xmllint --xpath "$e/*[local-name()='author']/*[local-name()='name']/text()" "$BODY" 2>/dev/null | head -5)"
      jq -nc --arg t "$(x "*[local-name()='title']")" --arg d "$(x "*[local-name()='published']")" \
        --arg id "$(x "*[local-name()='id']")" --arg doi "$(x "*[local-name()='doi']")" --arg j "$(x "*[local-name()='journal_ref']")" \
        --arg a "$authors" "$NORM"' {source: "arxiv", title: ($t | clean), authors: ($a | split("\n") | map(select(. != ""))),
          year: ($d[0:4] | tonumber? // null), date: $d[0:10], venue: (if $j == "" then "arXiv" else ($j | clean) end),
          doi: (if $doi == "" then null else ($doi | nodoi) end), arxiv: ($id | sub(".*/abs/"; "")),
          url: ($id | sub("^http://"; "https://")), cited_by: null, is_retracted: null, kind: "preprint",
          open_access_url: ($id | sub("^http://"; "https://") | sub("/abs/"; "/pdf/"))}'
      i=$((i+1))
    done ;;

  pubmed)
    url="$EUTILS/esearch.fcgi?db=pubmed&term=$Q&retmode=json&retmax=$LIMIT"
    [ "$SORT" = date ] && url="$url&sort=pub_date"
    [ -n "$FROM" ] && url="$url&datetype=pdat&mindate=$(printf '%s' "$FROM" | tr '-' '/')&maxdate=3000"
    fetch "$url"
    ids="$(jq -r '.esearchresult.idlist // [] | join(",")' "$BODY")"
    [ -n "$ids" ] || exit 0
    fetch "$EUTILS/esummary.fcgi?db=pubmed&id=$ids&retmode=json"
    jq -c "$NORM"' .result as $r | $r.uids[]? | $r[.] | {source: "pubmed", title: (.title | clean), authors: [.authors[]?.name][0:5],
      year: (.pubdate[0:4] | tonumber? // null), date: .pubdate, venue: .fulljournalname,
      doi: ([.articleids[]? | select(.idtype == "doi") | .value][0] // null | nodoi), arxiv: null,
      url: ("https://pubmed.ncbi.nlm.nih.gov/" + .uid + "/"), cited_by: null,
      is_retracted: ((.pubtype // []) | index("Retracted Publication") != null), kind: ((.pubtype // [])[0] // null), open_access_url: null}' "$BODY" ;;

  europepmc|biorxiv|medrxiv)
    q="$QUERY"
    case "$SOURCE" in
      biorxiv) q="($q) AND SRC:PPR AND PUBLISHER:\"bioRxiv\"" ;;
      medrxiv) q="($q) AND SRC:PPR AND PUBLISHER:\"medRxiv\"" ;;
    esac
    [ -n "$FROM" ] && q="$q AND FIRST_PDATE:[$FROM TO 3000-01-01]"
    url="$EUROPEPMC/search?query=$(uri "$q")&format=json&pageSize=$LIMIT"
    [ "$SORT" = date ] && url="$url&sort=$(uri 'FIRST_PDATE_D desc')"
    fetch "$url"
    jq -c --arg s "$SOURCE" "$NORM"' .resultList.result[]? | {source: $s, title: (.title | clean),
      authors: ((.authorString // "") | rtrimstr(".") | split(", ") | map(select(. != "")))[0:5],
      year: (.pubYear | tonumber? // null), date: .firstPublicationDate,
      venue: (.journalTitle // .bookOrReportDetails.publisher // null), doi: (.doi // null | nodoi), arxiv: null,
      url: (if .doi then "https://doi.org/" + .doi elif .pmid then "https://europepmc.org/article/MED/" + .pmid else "https://europepmc.org/article/" + .source + "/" + .id end),
      cited_by: .citedByCount, is_retracted: null, kind: (if .source == "PPR" then "preprint" else "article" end), open_access_url: null}' "$BODY" ;;

  openreview)
    fetch "$OPENREVIEW/notes/search?term=$Q&limit=$LIMIT&source=forum"
    # OpenReview 검색은 날짜 조건을 받지 않아 받은 뒤 거른다
    jq -c --arg from "$FROM" "$NORM"' .notes[]? | select($from == "" or (((.pdate // .cdate // 0) / 1000 | floor | todate[0:10]) >= $from)) | {source: "openreview", title: (.content.title.value | clean), authors: (.content.authors.value // [])[0:5],
      year: ((.pdate // .cdate // 0) / 1000 | floor | todate[0:4] | tonumber), date: ((.pdate // .cdate // 0) / 1000 | floor | todate[0:10]),
      venue: (.content.venue.value // null), doi: null, arxiv: null, url: ("https://openreview.net/forum?id=" + .forum),
      cited_by: null, is_retracted: null, kind: "conference-submission", open_access_url: null}' "$BODY" ;;

  huggingface|huggingface-daily)
    if [ "$SOURCE" = huggingface ]; then fetch "$HF/papers/search?q=$Q"; else fetch "$HF/daily_papers?limit=$LIMIT"; fi
    # Hugging Face 검색은 날짜 조건을 받지 않아 받은 뒤 거른다
    jq -c --argjson n "$LIMIT" --arg from "$FROM" "$NORM"' [(if type == "array" then . else [] end)[] | select($from == "" or (((.paper // .).publishedAt // "")[0:10] >= $from))][0:$n][]
      | (.paper // .) as $p | {source: "huggingface",
      title: ($p.title | clean), authors: [$p.authors[]?.name][0:5], year: ($p.publishedAt[0:4] | tonumber? // null), date: $p.publishedAt[0:10],
      venue: "Hugging Face Papers", doi: null, arxiv: $p.id, url: ("https://huggingface.co/papers/" + $p.id),
      cited_by: null, upvotes: ($p.upvotes // null), is_retracted: null, kind: "preprint", open_access_url: ("https://arxiv.org/pdf/" + $p.id)}' "$BODY" ;;

  hackernews)
    ep=search; [ "$SORT" = date ] && ep=search_by_date
    url="$HN/$ep?query=$Q&tags=story&hitsPerPage=$LIMIT"
    if [ -n "$FROM" ]; then
      ts="$(jq -rn --arg d "$FROM" '$d + "T00:00:00Z" | fromdateiso8601')"
      url="$url&numericFilters=$(uri "created_at_i>$ts")"
    fi
    fetch "$url"
    jq -c "$NORM"' .hits[]? | {source: "hackernews", title: (.title | clean), authors: [.author], year: (.created_at[0:4] | tonumber? // null),
      date: .created_at[0:10], venue: "Hacker News", doi: null, arxiv: null, url: (.url // ("https://news.ycombinator.com/item?id=" + .objectID)),
      discussion_url: ("https://news.ycombinator.com/item?id=" + .objectID), points, comments: .num_comments,
      cited_by: null, is_retracted: null, kind: "discussion", open_access_url: null}' "$BODY" ;;

  rfc)
    fetch "$DATATRACKER/doc/document/?title__icontains=$Q&type=rfc&limit=$LIMIT&format=json"
    jq -c "$NORM"' .objects[]? | {source: "rfc", title: (.title | clean), authors: [], year: null, date: null, venue: "IETF RFC",
      doi: ("10.17487/" + (.name | ascii_upcase)), arxiv: null, url: ("https://www.rfc-editor.org/rfc/" + .name),
      rfc: .rfc_number, std_level: (.std_level // "" | sub("/$"; "") | sub(".*/"; "")), cited_by: null, is_retracted: null,
      kind: "standard", open_access_url: ("https://www.rfc-editor.org/rfc/" + .name + ".txt")}' "$BODY" ;;

  github-repository|github-code|github-issue)
    need gh
    case "$SOURCE" in
      github-repository) out="$(gh search repos "$QUERY" --limit "$LIMIT" --sort stars --json fullName,description,stargazersCount,updatedAt,url 2>&1)" || die 5 "$SOURCE $out"
        printf '%s' "$out" | jq -c '.[] | {source: "github-repository", title: .fullName, authors: [], year: (.updatedAt[0:4] | tonumber? // null),
          date: .updatedAt[0:10], venue: "GitHub", doi: null, arxiv: null, url, summary: .description, stars: .stargazersCount,
          cited_by: null, is_retracted: null, kind: "repository"}' ;;
      github-code) out="$(gh search code "$QUERY" --limit "$LIMIT" --json path,repository,url 2>&1)" || die 5 "$SOURCE $out"
        printf '%s' "$out" | jq -c '.[] | {source: "github-code", title: (.repository.nameWithOwner + ":" + .path), authors: [], year: null, date: null,
          venue: "GitHub", doi: null, arxiv: null, url, cited_by: null, is_retracted: null, kind: "code"}' ;;
      github-issue) out="$(gh search issues "$QUERY" --limit "$LIMIT" --json title,url,repository,state,createdAt,commentsCount 2>&1)" || die 5 "$SOURCE $out"
        printf '%s' "$out" | jq -c '.[] | {source: "github-issue", title, authors: [], year: (.createdAt[0:4] | tonumber? // null), date: .createdAt[0:10],
          venue: .repository.nameWithOwner, doi: null, arxiv: null, url, state, comments: .commentsCount,
          cited_by: null, is_retracted: null, kind: "issue"}' ;;
    esac ;;

  kci|riss|scienceon|ntis|core|unpaywall|ieee|springer|scopus)
    die 3 "$SOURCE 은 키가 필요해 아직 넣지 않았다 (TODO). WebSearch 'site:' 로 찾는다" ;;

  *) die 2 "모르는 출처 — $SOURCE" ;;
esac
