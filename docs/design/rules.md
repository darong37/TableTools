# Design Rules
Date: 2026-04-07

## design-concept.md
- 必須の項目は `Concept`、`Rules`、`API`

## design-implementation-sketch.md
- 最初に `package ...` を置く
- `package` の直下には `Rules:` コメントを書く
- その下には `design-concept.md` の `API` に書いた公開 API だけを書く
- 順番は `design-concept.md` の `API` と同じ順番にする
- 各 API には、その関数の中で処理がどう流れるかをコメントで書く
- 内部関数は書かない
