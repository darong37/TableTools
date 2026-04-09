# TableTools 仕様書

## 概要

`TableTools` は Perl の Array of Hashes（AoH）を操作するためのユーティリティモジュール。
データベースのテーブルに相当する構造（同じキー集合を持つハッシュリファレンスの配列）を
検証・グループ化・展開するための関数群を提供する。

```perl
use TableTools qw(validate group expand orderby detach attach);
```

`Exporter` ベースの純粋な関数モジュール。状態なし、OO なし。

## 用語と記号

- `AoH`: ハッシュリファレンスの配列リファレンス
- `rows`: メタデータを持たない AoH
- `table`: 先頭行にメタデータを持つ AoH
- メタデータ: `'#'` キーに置くハッシュリファレンス
- `attrs`: カラム名をキー、`num` / `str` を値とするハッシュ
- `count`: validate() が生成する meta のキー。table の rows 件数を表す
- `order`: カラム名の並びを表す配列リファレンス

- `$aoh`: `AoH`
- `$rows`: `rows`
- `$table`: `table`
- `$cols`: カラム名の配列リファレンス
- `@cols_list`: カラム名の配列リファレンスの並び
- `$meta`: メタデータ

## 前提条件・制限事項

`detach()` と `attach()` を除く各 API は内部で `validate()` を呼ぶ。
`attach()` は `validate()` を呼ばない低レベルプリミティブであり、受け取った `$rows` と `$meta` をそのまま組み立てる。
`detach()` と `attach()` を除く各 API は `rows` と `table` のどちらを受け取ってもよい。

`validate()` は rows が 0 件かどうかを必ず確認し、0 件なら `[]` を返す。
`attrs` 付き `table` を `$cols` なしで `validate()` に渡すと、各行の検証をスキップして同一参照を返す（アーリーリターン）。
これは「先頭行に `attrs` がある = `validate` が生成した信頼できる `table`」という実装判断に基づく。
`validate()` は `undef` の値を空文字 `''` に置き換える。

行ごとにキー集合が異なる場合の動作は保証されない。処理中に存在しないカラムが見つかった場合は `die` する。

```perl
my $sorted  = orderby(\@rows, ['A', 'B']);   # rows を直接渡せる
my $grouped = group(\@rows, ['A']);           # rows を直接渡せる
my $flat    = expand($grouped);
```

## データ構造

### `rows` と `table`

`detach()` と `attach()` を除く各 API は `rows` と `table` のどちらも受け付ける。

メタデータ付きの `table` を標準形とする。`validate` の戻り値は通常 `table`。ただしデータ rows が 0 件の場合は `[]` を返す。メタデータのない形が必要な場合は `detach` を利用する。

```perl
# rows
[
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]

# table（attrs + count + order）
[
    {'#' => {attrs => {A => 'num', B => 'str', C => 'num'}, count => 2, order => ['A', 'B', 'C']}},
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]

# table（旧形式: validate() アーリーリターンで通過しうる attrs のみ）
[
    {'#' => {attrs => {A => 'num', B => 'str', C => 'num'}}},
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]
```

### メタデータ行

`'#'` キーのみを持つハッシュリファレンス。`table` の先頭に置く。

```perl
{'#' => {attrs => {A => 'num', B => 'str'}, count => 2, order => ['A', 'B', 'C']}}
```

- `attrs`: カラム名をキー、型情報（`'num'` または `'str'`）を値とするハッシュ
  - `'num'`: 全値が数値
  - `'str'`: 1つでも文字列を含む
- `order`: カラム順序を表す配列リファレンス（省略可）
- `'#'` キーを持つ行はデータ行として処理しない
- `attrs` と `count` は必須。`order` は省略可能
- `order` は `validate($table, $cols)` を通じた場合のみ生成される
- `attrs` を持たないメタデータを `group`・`expand` に渡した場合は `die` する
- `'#' => {}` のように `attrs`・`order` の両方を持たない空のメタデータは、仕様上存在しない前提とする
- `scalar @$table` はメタデータ行を含む（データ行数は `scalar @$table - 1`）

### 空テーブルの扱い

空テーブル（data row が 0 件の AoH）はメタデータ付与の対象外とする。
`validate` は rows 数を必ず確認し、いずれの形式でも data row が 0 件ならメタデータを生成せず `[]` を返す。

### グループ化後のテーブル

子行は `'@'` キーに配列リファレンスとして格納する。`'@'` は Perl の配列シジルと同じ直感で「このキーの値は子行の配列リファレンス」を意味する。

```perl
[
    {'#' => {attrs => {A => 'num', B => 'str', C => 'num'}, count => 2, order => ['A', 'B', 'C']}},
    {A => 1, '@' => [
        {B => 'foo', C => 3},
        {B => 'bar', C => 7},
    ]},
    {A => 5, '@' => [
        {B => 'baz', C => 9},
    ]},
]
```

## コーディング方針

- `detach()` と `attach()` を除く各パブリック API は冒頭で `validate($aoh)` を呼び出す。data row が 0 件なら `[]` を返す
- `validate` の戻り値を `detach` で分離してメタとデータ行を取り出す
- 本体ロジックはメタデータを知らない内部関数に切り出す
- 処理完了後、トップレベルでのみ `attach` でメタデータを先頭に戻す
- `attach` は `validate` を呼ばず、渡された `$rows` と `$meta` をそのまま組み立てる
- `validate` は `undef` の値を空文字 `''` に置き換える

## 関数仕様

### `validate($aoh, $cols)`

テーブルを検証する。`$cols` の有無によって動作が異なる。

| 引数 | 説明 |
|------|------|
| `$aoh` | `AoH`（`rows` / `table` どちらでもよい） |
| `$cols` | カラム名の配列リファレンス（省略可）|

**`$cols` なし:**

| 入力形式 | アーリーリターン | 動作 | 結果 |
|---|---|---|---|
| `rows` | なし | `undef` を `''` に正規化し、型推論で `attrs` を確定 | `attrs` と `count` 付きの `table` |
| `table`（`attrs` あり） | あり | rows 数確認後、`undef` を `''` に正規化し、同一参照をそのまま返す（再検証しない） | 入力と同じ参照 |
| 空テーブル | なし | — | `[]` |

補足: `table` 入力のアーリーリターンは「先頭行に `attrs` がある = validate 済みと信頼する」実装判断。型の不整合があっても再検証しない。

**`$cols` あり:**

| 入力形式 | アーリーリターン | 動作 | 結果 |
|---|---|---|---|
| `rows` | なし | `undef` を `''` に正規化し、`$cols` キー集合照合 + 型推論 | `attrs` + `count` + `order` 付きの `table` |
| `table`（`attrs` あり） | なし | `undef` を `''` に正規化し、`$cols` と `attrs` キー集合を照合 | `$cols` 順で `order` を設定した `table` |
| 空テーブル | なし | — | `[]` |

検証失敗・型不一致・キー集合不一致の場合は `die`。`undef` は `''` に正規化してから扱う。

```perl
my $table = validate(\@rows, ['A', 'B', 'C']);  # attrs + count + order 付きメタデータを返す
my $table = validate(\@rows);                    # attrs + count 付きメタデータを返す
my $same  = validate($table);                    # attrs 付きなら同一参照を返す
```

### `group($aoh, @cols_list)`

テーブルを多段グループ化する。

| 引数 | 説明 |
|------|------|
| `$aoh` | `AoH`（`rows` / `table` どちらでもよい） |
| `@cols_list` | グループ化するカラム名の配列リファレンスのリスト |

1. `validate($aoh)` を呼び出す。空テーブルの場合はそのまま返す。`detach` でメタとデータ行を取り出す
2. `@cols_list` が空なら、`validate` 済みの結果をそのまま返す
3. `@cols_list` に存在しないカラム名が含まれる場合は即 `die`
4. 入力行を**ソートせず**そのまま走査する（ソート済み前提）
5. 先頭レベルのカラムでグループ化し、子行を `'@'` に格納。同一キーが非連続で再出現した場合は `die "out of order: key reappeared"`
6. 残りのレベルで内部関数 `_group_rows` が再帰的にグループ化
7. `count` を再計算した新 meta（`attrs` と `order` は入力から引き継ぎ）を付けた `table` を返す

```perl
# 2段グループ化
my $grouped = group($table, ['A'], ['B', 'C']);
```

### `expand($aoh)`

グループ化されたテーブルを完全にフラット化する。何重のネストでも一度にフラット化する。

1. `validate($aoh)` を呼び出す。空テーブルの場合はそのまま返す。`detach` でメタとデータ行を取り出す
2. `'@'` キーを持つ行を再帰的に展開（親キーと子行をマージ）
3. `count` を再計算した新 meta（`attrs` と `order` は入力から引き継ぎ）を付けて返す

```perl
my $flat = expand($grouped);
```

### `orderby($aoh, $cols)`

テーブルを指定カラムの優先順でソートする。

| 引数 | 説明 |
|------|------|
| `$aoh` | `AoH`（`rows` / `table` どちらでもよい） |
| `$cols` | ソートに使うカラム名の配列リファレンス |

1. `validate($aoh)` を呼び出す。空テーブルの場合はそのまま返す。`detach` でメタとデータ行を取り出す
2. `$cols` が空なら、`validate` 済みの結果をそのまま返す
3. `$cols` に存在しないカラム名が含まれる場合は即 `die`
4. `$cols` の優先順に従い、`attrs` の型情報でソート（`num` は `<=>`、`str` は `cmp`）
5. 入力のメタデータをそのまま付け直して返す

```perl
my $sorted = orderby($table, ['A', 'B']);
```

### `detach($table)`

`table` からメタデータ行を分離する。

```perl
my ($rows, $meta) = detach($table);
# $meta は undef（メタデータなし）またはメタデータハッシュリファレンス
```

### `attach($rows, $meta)`

メタデータ行を `rows` の先頭に付加する。`$meta` が `undef` の場合は `$rows` をそのまま返す。

```perl
my $table = attach($rows, $meta);
```

## 型推論ルール

`validate` が使用する。カラムごとに状態マシンで型を確定する。

| 現在の状態 | 値が数値 | 値が非数値 |
|-----------|---------|----------|
| `'unknown'`（初期） | `'num?'` に遷移 | `'str'` に確定 |
| `'num?'`（数値候補） | `'num?'` を維持 | `'str'` に確定 |
| `'num'`（確定済み） | `'num'` を維持 | `die` |
| `'str'`（確定済み） | `'str'` を維持 | `'str'` を維持 |

全行処理後、`'num?'` は `'num'` に確定する。
数値判定は `Scalar::Util::looks_like_number` を使用する。

## エラーハンドリング

- `validate`: キー集合の不一致、確定済み `'num'` カラムに非数値を検出した場合は `die`
- `group`: 未知カラム指定時に `die`。非連続な同一キーの再出現時に `die "out of order: key reappeared"`
- `expand`: エラー条件なし（`validate` が内部で処理）
- `orderby`: 未知カラム指定時に `die`
