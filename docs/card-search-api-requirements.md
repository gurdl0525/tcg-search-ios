# Card Search API Plan

이 문서는 현재 iOS 화면을 기준으로 필요한 API를 정의한다. 기존 백엔드
구현 여부는 이 문서의 기준이 아니다. iOS Home, Search Results, Filter,
Collection, Deck 화면이 자연스럽게 동작하기 위해 필요한 계획 API를
화면 요소별로 정리한다.

## Goals

- 홈에서 검색어 또는 필터만으로 검색 결과 화면에 진입할 수 있어야 한다.
- 검색 결과는 이미지 중심 3열 그리드를 무한 스크롤로 보여준다.
- 필터 옵션은 서버 데이터 기준으로 내려받아 하드코딩을 줄인다.
- 등장인물, 일러스트레이터, 팩은 검색/선택형 UI로 확장 가능해야 한다.
- 컬렉션과 덱 탭은 아직 상세 화면 전이 전이라도 요약 API 기준을 둔다.

## API Summary

| API | Purpose | Screen |
| --- | --- | --- |
| `GET /api/cards/search` | 홈 검색 및 검색 결과 목록 조회 | Home, Search Results |
| `GET /api/cards/trending` | 홈 최근 많이 찾는 카드 조회 | Home |
| `GET /api/cards/filter-options` | 필터 시트 옵션 전체 조회 | Home, Search Results, Filter Sheet |
| `GET /api/cards/packs` | 팩 선택 목록 조회 | Filter Sheet |
| `GET /api/cards/characters` | 등장인물 검색 셀렉트 조회 | Filter Sheet |
| `GET /api/cards/illustrators` | 일러스트레이터 검색 자동완성 조회 | Filter Sheet |
| `GET /api/cards/{printing_id}` | 카드 상세 조회 | Search Results, Detail |
| `GET /api/cards/{printing_id}/related-printings` | 같은 카드의 다른 언어/버전 조회 | Detail |
| `GET /api/cards/{printing_id}/marketplace-links` | 카드 외부 거래/시세 링크 조회 | Detail |
| `POST /api/cards/search-events` | 검색/조회 로그 기록 | Home, Search Results, Detail |
| `GET /api/me/collections/summary` | 컬렉션 탭 요약 조회 | Collection |
| `GET /api/me/decks/summary` | 덱 탭 요약 조회 | Deck |

## Shared Rules

- 모든 인증 필요 API는 `Authorization: Bearer {access_token}`을 사용한다.
- 모든 요청/응답 필드는 snake_case를 사용한다.
- 카드 목록은 카드 식별자 단위가 아니라 프린팅 단위로 반환한다.
- iOS의 `전체` 선택은 명시적인 값으로 다룬다. 서버 요청에서는 `language=all`
  또는 필터 생략 중 하나로 통일한다.
- 검색어, 언어, 필터, 정렬이 변경되면 첫 페이지부터 다시 조회한다.
- 첫 페이지는 기존 목록을 대체하고, 다음 페이지는 기존 목록 뒤에 append한다.
- 네트워크 실패 시 기존 결과가 있으면 유지하고 재시도 액션을 제공한다.

## Data Types

### Card Search Item

검색 결과, 홈 최근 카드, 관련 프린팅에서 공통으로 쓰는 최소 카드 항목이다.

```json
{
  "printing_id": "uuid",
  "card_identity_id": "uuid",
  "card_no": "ST30-017",
  "name": "And You Get Yourself...",
  "card_type": "EVENT",
  "rarity": "C",
  "language": "jp",
  "colors": ["red"],
  "traits": ["Luffy & Ace"],
  "pack": {
    "code": "ST-30",
    "name": "Starter Deck"
  },
  "variant": {
    "is_parallel": false,
    "detail_tags": ["PROMO"],
    "display_name": null
  },
  "image_url": "https://..."
}
```

Required UI fields:

- `printing_id`: 카드 탭 시 상세 이동.
- `card_no`: 검색 결과 카드 번호.
- `name`: 카드명.
- `card_type`: 카드 타입 표시와 필터 일치.
- `rarity`: 레어도 표시와 필터 일치.
- `language`: 언어 배지.
- `colors`: 색상 배지 또는 보조 정보.
- `traits`: 등장인물/트레잇 보조 정보.
- `image_url`: 카드 이미지.

### Page Response

```json
{
  "content": [],
  "page": 0,
  "size": 20,
  "total_count": 120,
  "has_next": true,
  "next_page": 1
}
```

## Home

### Search Field

Element: 홈 상단 검색 입력.

API:

```http
GET /api/cards/search
```

Query:

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `query` | string | no | 카드명, 카드 번호, 다국어 검색어. |
| `language` | `all`, `ko`, `en`, `jp` | no | 홈 언어 칩 선택값. Default `all`. |
| `page` | integer | yes | 첫 검색은 `0`. |
| `size` | integer | yes | Default `20`. |
| `sort` | string | no | Default `card_no_desc`. |

Example:

```http
GET /api/cards/search?query=nami&language=all&page=0&size=20&sort=card_no_desc
```

UI behavior:

- 검색어 submit 시 검색 결과 화면으로 진입한다.
- 검색어가 비어 있어도 필터가 있으면 검색으로 인정한다.
- 검색 아이콘은 API 액션이 아니라 입력 affordance다.

### Language Chips

Element: `전체`, `한글`, `영어`, `일본어`.

API impact:

| UI label | API value |
| --- | --- |
| `전체` | `language=all` |
| `한글` | `language=ko` |
| `영어` | `language=en` |
| `일본어` | `language=jp` |

UI behavior:

- 홈에서 언어 변경 시 홈 최근 카드와 다음 검색 요청에 반영한다.
- 이미 검색 결과 화면에 있다면 현재 검색 조건으로 첫 페이지를 다시 조회한다.

### Recent Cards

Element: `최근 많이 찾는 카드`.

API:

```http
GET /api/cards/trending
```

Query:

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `language` | `all`, `ko`, `en`, `jp` | no | 표시 언어. Default `all`. |
| `limit` | integer | no | Home default `3`. |
| `period` | `day`, `week`, `month` | no | Default `week`. |

Response:

```json
{
  "content": [
    {
      "rank": 1,
      "search_count": 128,
      "card": {
        "printing_id": "uuid",
        "card_identity_id": "uuid",
        "card_no": "ST30-017",
        "name": "And You Get Yourself...",
        "card_type": "EVENT",
        "rarity": "C",
        "language": "jp",
        "colors": ["red"],
        "traits": ["Luffy & Ace"],
        "image_url": "https://..."
      }
    }
  ]
}
```

UI behavior:

- `content`가 비어 있으면 섹션 자체를 숨기거나 skeleton 없이 빈 영역을 줄인다.
- 카드 탭 시 `GET /api/cards/{printing_id}`로 상세 이동한다.

## Search Results

### Result List

Element: 검색 결과 3열 그리드.

API:

```http
GET /api/cards/search
```

Query:

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `query` | string | no | 홈 검색어 또는 결과 검색어. |
| `language` | `all`, `ko`, `en`, `jp` | no | 선택 언어. |
| `card_types` | string array | no | `CHARACTER`, `LEADER`, `DON`, `EVENT`, `STAGE`. |
| `rarities` | string array | no | `C`, `UC`, `R`, `SR`, `SEC`, `TR`. |
| `detail_tags` | string array | no | `SP`, `PARALLEL`, `MANGA`, `PROMO`. |
| `pack_codes` | string array | no | 팩 코드. |
| `character_ids` | string array | no | 등장인물 선택값. |
| `illustrator_ids` | string array | no | 일러스트레이터 선택값. |
| `sort` | string | no | `card_no_desc`, `card_no_asc`, `name_asc`, `name_desc`. |
| `page` | integer | yes | 현재 페이지. |
| `size` | integer | yes | Default `20`. |

Example:

```http
GET /api/cards/search?query=luffy&language=ko&card_types=CHARACTER&rarities=SR&detail_tags=PARALLEL&sort=card_no_desc&page=0&size=20
```

Response:

```json
{
  "content": [
    {
      "printing_id": "uuid",
      "card_identity_id": "uuid",
      "card_no": "OP01-001",
      "name": "몽키 D. 루피",
      "card_type": "LEADER",
      "rarity": "L",
      "language": "ko",
      "colors": ["red"],
      "traits": ["Straw Hat Crew"],
      "pack": {
        "code": "OP-01",
        "name": "ROMANCE DAWN"
      },
      "variant": {
        "is_parallel": true,
        "detail_tags": ["PARALLEL"],
        "display_name": "Parallel"
      },
      "image_url": "https://..."
    }
  ],
  "page": 0,
  "size": 20,
  "total_count": 1,
  "has_next": false,
  "next_page": null
}
```

UI behavior:

- 첫 페이지 요청 중에는 검색 결과 loading 화면을 보여준다.
- 첫 페이지 `content=[]`이면 빈 페이지를 보여준다.
- 다음 페이지 요청 중에는 그리드 하단에 inline loader만 보여준다.
- `has_next=false`면 추가 요청하지 않는다.

### Sort Control

Element: 검색 결과 정렬 컨트롤.

API mapping:

| UI label | API value |
| --- | --- |
| `카드 번호 내림차순` | `sort=card_no_desc` |
| `카드 번호 오름차순` | `sort=card_no_asc` |
| `이름 오름차순` | `sort=name_asc` |
| `이름 내림차순` | `sort=name_desc` |

UI behavior:

- 정렬 변경 시 `page=0`으로 재조회한다.

## Filter Sheet

### Filter Options

Element: 필터 시트 초기 옵션.

API:

```http
GET /api/cards/filter-options
```

Query:

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `language` | `all`, `ko`, `en`, `jp` | no | 옵션 표시 언어. |

Response:

```json
{
  "languages": [
    { "code": "all", "name": "전체" },
    { "code": "ko", "name": "한글" },
    { "code": "en", "name": "영어" },
    { "code": "jp", "name": "일본어" }
  ],
  "card_types": [
    { "code": "CHARACTER", "name": "캐릭터" },
    { "code": "LEADER", "name": "리더" },
    { "code": "DON", "name": "두웅!!" },
    { "code": "EVENT", "name": "이벤트" },
    { "code": "STAGE", "name": "스테이지" }
  ],
  "rarities": [
    { "code": "C", "name": "C" },
    { "code": "UC", "name": "UC" },
    { "code": "R", "name": "R" },
    { "code": "SR", "name": "SR" },
    { "code": "SEC", "name": "SEC" },
    { "code": "TR", "name": "TR" }
  ],
  "detail_tags": [
    { "code": "SP", "name": "SP" },
    { "code": "PARALLEL", "name": "Parallel" },
    { "code": "MANGA", "name": "망가" },
    { "code": "PROMO", "name": "프로모" }
  ],
  "default_sort": "card_no_desc"
}
```

UI behavior:

- 앱 시작 후 Home 진입 시 1회 로드하고 캐시한다.
- 실패 시 필터 버튼은 열 수 있되, 옵션 영역에는 retry 상태를 보여준다.

### Pack Select

Element: 팩 select.

API:

```http
GET /api/cards/packs
```

Query:

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `language` | `all`, `ko`, `en`, `jp` | no | 팩명 표시 언어. |
| `query` | string | no | 팩명 검색. |
| `limit` | integer | no | Default `50`. |

Response:

```json
{
  "content": [
    {
      "code": "EB-03",
      "name": "엑스트라 부스터3 히로인즈 에디션",
      "release_date": "2026-01-01"
    },
    {
      "code": "OP-17",
      "name": "OP 17",
      "release_date": "2026-03-01"
    }
  ]
}
```

UI behavior:

- `전체`는 클라이언트 기본 옵션이며 서버 응답에 없어도 된다.
- 선택된 팩은 검색 요청의 `pack_codes`로 전달한다.

### Character Select

Element: 등장인물 검색 select.

API:

```http
GET /api/cards/characters
```

Query:

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `query` | string | no | 등장인물명 검색어. |
| `language` | `all`, `ko`, `en`, `jp` | no | 표시 언어. |
| `limit` | integer | no | Default `20`. |

Response:

```json
{
  "content": [
    {
      "id": "uuid",
      "name": "Nami",
      "aliases": ["나미", "ナミ"],
      "card_count": 42
    }
  ]
}
```

UI behavior:

- 검색어 입력 시 debounce 후 조회한다.
- 선택된 값은 검색 요청의 `character_ids`로 전달한다.
- 서버가 character 도메인을 아직 분리하지 않는다면 trait 기반으로 구현하더라도
  iOS 계약은 `characters`로 유지한다.

### Illustrator Search

Element: 일러스트레이터 검색 input/autocomplete.

API:

```http
GET /api/cards/illustrators
```

Query:

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `query` | string | no | 작가명 검색어. |
| `limit` | integer | no | Default `20`. |

Response:

```json
{
  "content": [
    {
      "id": "uuid",
      "name": "Eiichiro Oda",
      "card_count": 12
    }
  ]
}
```

UI behavior:

- 선택된 값은 검색 요청의 `illustrator_ids`로 전달한다.
- 단순 텍스트 입력만 유지할 경우 `illustrator_query`를 검색 API에 전달할 수
  있지만, 장기적으로는 id 기반 선택을 우선한다.

### Reset

Element: `초기화`.

API:

- 호출하지 않는다.

UI behavior:

- 언어는 `전체`로 되돌린다.
- 카드 타입, 레어도, 세부 조건, 팩, 등장인물, 일러스트레이터를 비운다.
- 자동 검색하지 않고 사용자가 `필터 적용`을 누를 때 검색한다.

### Apply

Element: `필터 적용`.

API:

```http
GET /api/cards/search
```

UI behavior:

- 필터 시트를 닫고 Home 플로우 안의 Search Results 화면으로 진입한다.
- 검색어가 없어도 필터가 있으면 검색으로 인정한다.
- 첫 페이지를 새로 조회한다.

## Card Detail

### Detail

Element: 검색 결과 카드 탭 후 상세 화면.

API:

```http
GET /api/cards/{printing_id}
```

Response:

```json
{
  "printing_id": "uuid",
  "card_identity_id": "uuid",
  "card_no": "OP01-001",
  "name": "Monkey.D.Luffy",
  "card_type": "LEADER",
  "rarity": "L",
  "language": "en",
  "colors": ["red"],
  "traits": ["Straw Hat Crew"],
  "cost": 5,
  "life": 5,
  "power": 5000,
  "counter": null,
  "attribute": "Strike",
  "effect_text": "Full effect text",
  "trigger_text": null,
  "pack": {
    "code": "OP-01",
    "name": "ROMANCE DAWN"
  },
  "variant": {
    "is_parallel": true,
    "detail_tags": ["PARALLEL"],
    "display_name": "Parallel"
  },
  "illustrator": {
    "id": "uuid",
    "name": "Eiichiro Oda"
  },
  "image_url": "https://...",
  "source_url": "https://..."
}
```

UI behavior:

- `image_url` 실패 시 placeholder를 보여준다.
- 상세 화면은 같은 카드의 다른 언어/버전, 거래 링크를 추가로 로드할 수 있다.

### Related Printings

Element: 같은 카드의 다른 언어/버전 영역.

API:

```http
GET /api/cards/{printing_id}/related-printings
```

Response:

```json
{
  "content": [
    {
      "printing_id": "uuid",
      "language": "jp",
      "variant": {
        "is_parallel": true,
        "detail_tags": ["PARALLEL"],
        "display_name": "Parallel"
      },
      "image_url": "https://..."
    }
  ]
}
```

### Marketplace Links

Element: 외부 거래/시세 링크.

API:

```http
GET /api/cards/{printing_id}/marketplace-links
```

Response:

```json
{
  "content": [
    {
      "provider": "SNKRDUNK",
      "label": "SNKRDUNK 검색",
      "url": "https://snkrdunk.com/...",
      "updated_at": "2026-07-01T00:00:00Z"
    }
  ]
}
```

## Search Events

Element: 검색 로그, 최근 많이 찾는 카드, 개인화 추천 기반 데이터.

API:

```http
POST /api/cards/search-events
```

Request:

```json
{
  "event_type": "search",
  "query": "nami",
  "language": "all",
  "filters": {
    "card_types": ["CHARACTER"],
    "rarities": ["SR"],
    "detail_tags": ["PARALLEL"],
    "pack_codes": ["OP-17"],
    "character_ids": ["uuid"],
    "illustrator_ids": ["uuid"]
  },
  "result_count": 120,
  "selected_printing_id": null
}
```

Event types:

| Type | Trigger |
| --- | --- |
| `search` | 사용자가 검색을 실행했을 때. |
| `filter_apply` | 필터 적용으로 검색 결과에 진입했을 때. |
| `card_open` | 검색 결과에서 카드 상세를 열었을 때. |

UI behavior:

- 이벤트 기록 실패는 사용자 흐름을 막지 않는다.
- 홈 trending 계산에 사용할 수 있다.

## Collection Tab

### Collection Summary

Element: 컬렉션 탭 요약.

API:

```http
GET /api/me/collections/summary
```

Response:

```json
{
  "total_cards": 128,
  "unique_identities": 92,
  "parallel_cards": 14,
  "recent_cards": [
    {
      "printing_id": "uuid",
      "card_no": "OP01-001",
      "name": "Monkey.D.Luffy",
      "image_url": "https://..."
    }
  ]
}
```

UI behavior:

- 로그인 필요.
- 실패 시 컬렉션 탭 안에서 retry 상태를 보여준다.

## Deck Tab

### Deck Summary

Element: 덱 탭 요약.

API:

```http
GET /api/me/decks/summary
```

Response:

```json
{
  "deck_count": 3,
  "recent_decks": [
    {
      "deck_id": "uuid",
      "name": "Red Luffy",
      "card_count": 50,
      "leader": {
        "printing_id": "uuid",
        "name": "Monkey.D.Luffy",
        "image_url": "https://..."
      },
      "updated_at": "2026-07-01T00:00:00Z"
    }
  ]
}
```

UI behavior:

- 현재 bottom navigation의 `덱` 탭은 추후 덱 빌딩 화면 진입점이다.
- 상세 덱 CRUD API는 덱 빌딩 화면 설계 후 별도 문서로 정의한다.

## Error Handling

| Case | UI behavior |
| --- | --- |
| `400` validation error | 현재 화면 유지, 필드 또는 시트 안에 짧은 오류 표시. |
| `401` unauthorized | 토큰 refresh 1회 시도 후 실패하면 auth 화면으로 이동. |
| `403` forbidden | 권한 문제 메시지와 재로그인 액션 제공. |
| Network failure | 기존 데이터 유지, retry affordance 표시. |
| First-page empty | 검색 결과 빈 상태 화면 표시. |
| Next-page empty | 조용히 무한 스크롤 종료. |
| Image load failure | 카드 이미지 placeholder 표시. |

## Implementation Order

1. `GET /api/cards/filter-options`
2. `GET /api/cards/search`
3. `GET /api/cards/trending`
4. `GET /api/cards/packs`
5. `GET /api/cards/characters`
6. `GET /api/cards/illustrators`
7. `GET /api/cards/{printing_id}`
8. `GET /api/cards/{printing_id}/related-printings`
9. `GET /api/cards/{printing_id}/marketplace-links`
10. `POST /api/cards/search-events`
11. `GET /api/me/collections/summary`
12. `GET /api/me/decks/summary`

