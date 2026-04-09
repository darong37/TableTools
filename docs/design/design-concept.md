# Design Concept
Date: 2026-04-07

## Instruction
この文書は設計を決めるための単一の指示書である。
内容は `Concept`、`API`、`Rules` の順で定める。

- `Concept`: このプロジェクトの設計方針を書く
- `API`: その方針を外から見える操作として定める
- `Rules`: その方針と API を支える制約を、Perl のコメント文として書く

`Concept` には、何を大事にし、どのように作るかを書く。
コードを作るときは、`Rules` を `package` 宣言の直下に必ず置く。

## Concept
用語は次のとおり。

- `AoH`: ハッシュリファレンスの配列リファレンス
- メタデータ: AoH の先頭にだけ置く。形は次のとおり

```perl
{'#' => {
    attrs => {A => 'num', B => 'str', C => 'num'},
    count => 2,
    order => ['A', 'B', 'C'],   # 省略可（validate($aoh, $cols) のときだけ付く）
}}
```

- `attrs` はカラム名をキーに持つハッシュ
- `attrs` の値は `num` または `str`
- `num` は数値としてソートするカラムを表す
- `str` は文字列としてソートするカラムを表す
- `attrs` は必須
- `count` は validate() が生成する meta に必ず含まれるキー
- `count` は table の rows 件数（スカラー値）を表す
- `attrs` と `count` が必須、`order` が任意
- `order` はカラム名の並びを表す配列リファレンス
- `order` は列順を指定した `validate` のときだけ持つ
- `rows`: メタデータを持たない AoH。形は次のとおり

```perl
[
    {A => 1, B => 'x', C => 10},
    {A => 2, B => 'y', C => 20},
]
```

- `table`: 先頭にメタデータを持つ AoH。各 row は `attrs` に定義された全キーを持つ。形は次のとおり

```perl
[
    {'#' => {
        attrs => {A => 'num', B => 'str', C => 'num'},
        count => 2,
        order => ['A', 'B', 'C'],   # 省略可（validate($aoh, $cols) のときだけ付く）
    }},
    {A => 1, B => 'x', C => 10},
    {A => 2, B => 'y', C => 20},
]
```

方針は次のとおり。

- `validate()` は入口の処理とする
- `validate()` は `rows` または `table` を受け取り、条件を満たす `table` にそろえる
- `validate()` は `undef` の値を空文字 `''` に置き換える
- `validate()` は rows が 0 件かどうかを必ず確認し、0 件なら `[]` を返す
- すでに条件を満たす `table` を受けたときは、メタデータを作り直さずそのまま返す
- `detach()` と `attach()` を除く各 API は、内部で必ず `validate()` を呼ぶ
- `detach()` と `attach()` を除く各 API は `rows` と `table` のどちらを受け取ってもよい
- ただし `detach()` を除き、出力は `table` に統一する
- データ rows が 0 件の場合は、`table` を作らず `[]` を返す
- `attach()` は `validate()` を呼ばず、受け取った `rows` と `meta` から `table` を組み立てる
- `validate()` が meta を新規生成するときは `count` を必ず含める
- `count` は table の rows 件数とする
- `orderby()` は rows 件数を変えないので、入力 table の meta をそのまま維持する
- `group()` は rows 件数が変わるので、`count` を再計算した新 meta を生成する
- `expand()` は rows 件数が変わるので、`count` を再計算した新 meta を生成する

## API
記号は次のとおり。

- `$aoh`: `AoH`
- `$rows`: `rows`
- `$table`: `table`
- `$cols`: カラム名の配列リファレンス
- `@cols_list`: カラム名の配列リファレンスの並び
- `$meta`: メタデータ

| API | 役割 | 入力 | 出力 |
|---|---|---|---|
| `validate($aoh)` | 検証 | `AoH` | `$table` |
| `validate($aoh, $cols)` | 検証 | `AoH`, `$cols` | `$table` |
| `orderby($aoh, $cols)` | 整列 | `AoH`, `$cols` | `$table` |
| `group($aoh, @cols_list)` | 構造化 | `AoH`, `@cols_list` | `$table` |
| `expand($aoh)` | 展開 | `AoH` | `$table` |
| `detach($aoh)` | 分離 | `AoH` | `$rows` |
| `attach($rows, $meta)` | 付与 | `$rows`, `$meta` | `$table` |

## Rules
```perl
# Terms:
# AoH はハッシュリファレンスの配列リファレンス
# rows はメタデータを持たない AoH
# table は先頭行にメタデータを持つ AoH
# table のメタデータは '#' に置く
# attrs はカラム名をキーに持つハッシュで、値は num または str
# order はカラム名の並びを表す配列リファレンス
#
# Rules:
# detach() と attach() を除く API は rows でも table でも受け取れる
# detach() を除く API の出力は table とする
# データ rows が 0 件の場合は、table を作らず [] を返す
# validate() は rows が 0 件かどうかを必ず確認し、0 件なら [] を返す
# attach() は validate() を呼ばず、rows と meta から table を組み立てる
# attrs は必須で、order は列順を指定した validate() のときだけ付く
# validate() は undef の値を空文字 '' に置き換える
# orderby() は attrs に従って num は数値、str は文字列として並べる
# group() は入力順をそのまま使うので、必要なら先に orderby() を使う
# group() では非連続な同一キーの再出現をエラーにする
# expand() は group() 済みの table を平坦化して table を返す
# count は validate() が生成する meta に必ず含まれ、table の rows 件数を表す
# orderby() は行数不変なので meta をそのまま維持する
# group() と expand() は rows 件数が変わるので count を再計算した新 meta を生成する
```
