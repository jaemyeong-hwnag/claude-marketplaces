---
name: plugin-search
description: 이 마켓의 public 플러그인을 기능 · 키워드로 찾거나 어떤 플러그인과 연관된 것을 볼 때 사용한다. 이름 · 태그(도메인 · 기술) · 키워드 · 스킬 · 훅 · MCP · 설명을 동의어 · 오타 허용으로 검색하고 의존 · 공유 태그로 연관을 낸다. 트리거 — "플러그인 찾아", "~하는 플러그인 있어?", "비슷한 플러그인", "연관 플러그인", "plugin search".
---

# 플러그인 검색 · 연관 조회

규칙 원본: [`references/search-rules.md`](../../references/search-rules.md) — 질의 문법 2절, 점수 3절, 연관 4절.

대상은 **이 플러그인이 설치되어 온 마켓의 public 플러그인**뿐이다 (규칙 0절). 다른 마켓 · internal 은 나오지 않는다.

MCP 도구 `search_plugins` · `list_related_plugins` · `list_plugin_facets` 가 보이면 그것을 쓴다 — 같은 엔진이고 Bash 가 필요 없다. 없으면 스크립트를 쓴다.

```bash
PSI="${CLAUDE_PLUGIN_ROOT}/scripts/plugin-search-install.sh"
```

## 1. 질문을 질의로 바꾼다

요청 문장을 그대로 넘기지 않는다. **기능 단어**만 뽑고 관점에 맞는 문법을 고른다.

| 요청 | 명령 |
|---|---|
| "테스트 커버리지 올려주는 플러그인" | `"$PSI" search 테스트 커버리지` |
| "훅으로 막아주는 네이밍 플러그인, 자바 말고" | `"$PSI" search naming has:hook -java` |
| "깃허브나 깃랩 연동" | `"$PSI" search 'github\|gitlab'` |
| "스프링 태그 붙은 것 중 안 깐 것" | `"$PSI" search tech:spring is:not-installed` |
| "개발 도메인 플러그인 전부" | `"$PSI" search --domain development --limit 0` |
| "뭐가 있는지부터" | `"$PSI" facets` — 도메인 · 기술 태그(설명 포함) · 키워드 · 구성요소별 개수 |
| "issue-create 스킬 있는 플러그인" | `"$PSI" search skill:issue-create` |
| "MCP 서버 주는 것만" | `"$PSI" search --has mcp <단어>` |
| "많이 쓰는 순으로" | `--sort installs` |
| "plugin-naming 이랑 비슷한 것" | `"$PSI" related plugin-naming` |
| "github-workflow 에 기대는 것" | `"$PSI" related github-workflow --by dependent` |
| "문서 동기화 쪽 연관 플러그인" | `"$PSI" related 문서 동기화` — 기능어면 검색 상위를 씨앗으로 연관을 합친다 |

필터 옵션: `--tag` · `--domain` · `--technology` · `--keyword` · `--has` · `--installed` · `--not-installed` · `--min-score`. 결과가 많으면 `--limit`, 정확히만 보려면 `--exact`.

## 2. 결과를 읽는다

`--format json` 의 `results[]` 에서 `rank` · `id` · `installed` · `score` · `why` · `description` 을 쓴다.

- `relaxed: true` — 모든 단어에 맞는 것이 없어 일부만 맞는 결과다. 사용자에게 그렇다고 말하고 어느 단어를 뺄지 제안한다
- `why` 의 `(동의어 …)` · `(오타 허용 → …)` 는 약한 근거다. 그것만으로 맞은 결과는 그렇게 밝힌다
- 결과가 0개면 `--any` 로 넓히거나 `"$PSI" facets` 로 쓸 수 있는 태그 · 키워드를 보여준다. 다른 마켓에 있을 것 같으면 이 플러그인의 대상이 아니라고 말한다

## 3. 보여주고 다음을 묻는다

```
# | 플러그인 | 설치 | 왜 맞았나 | 설명(한 줄)
```

번호는 `rank` 그대로 둔다 — 설치 단계에서 같은 번호로 고른다. 설치를 원하면 `plugin-install` 로 넘긴다.

## 하지 않을 것

- 결과에 없는 플러그인을 추측해 추천하기
- 검색 단계에서 설치하기
- 설명을 지어내기 — `description` 이 비어 있으면 비어 있다고 말한다
