# TableTools

Perl の Array of Hashes（AoH）を操作するユーティリティモジュール。
テーブル構造の検証・グループ化・展開・ソート・メタデータ管理を行う関数群を提供する。

## 使い方

```perl
use TableTools qw(validate group expand orderby detach attach);
```

用語:

- `AoH`: ハッシュリファレンスの配列リファレンス
- `rows`: メタデータを持たない AoH
- `table`: 先頭行にメタデータを持つ AoH

## 関数

### `validate($aoh, $cols)`

`AoH` を検証し、`table` を返す。

- `$cols` なし：全行が同じキー集合を持つか検証し、カラムの型を推論してメタデータ行を先頭に付加したテーブルを返す。入力に既存の `order` がある場合は保持する
- `$cols` あり：全行が `$cols` のキー集合と一致するか検証し、型情報と順序情報（`attrs` + `order`）を含むメタデータ行を先頭に付加したテーブルを返す

`group`・`expand`・`orderby` は `validate` 済みのテーブルが必要。

```perl
my $table = validate(\@rows, ['A', 'B', 'C']);  # attrs + order 付きメタデータで返す
my $table = validate(\@rows);                    # attrs のみのメタデータで返す
```

### `group($table, @cols_list)`

`validate` 済みテーブルを多段グループ化する。入力はソート済みであることが前提（事前に `orderby` を使用）。子行を `'@'` キーに格納し、同一グループキーが非連続で再出現した場合はエラーとなる。

```perl
my $sorted  = orderby($table, 'A');
my $grouped = group($sorted, ['A']);           # 1段グループ化
my $grouped = group($sorted, ['A'], ['B']);    # 2段グループ化
```

### `expand($table)`

グループ化されたテーブルを完全にフラット化する。何重のネストでも一度に展開する。

```perl
my $flat = expand($grouped);
```

### `orderby($table, @cols)`

`validate` 済みテーブルを指定カラムの優先順でソートする。型情報に従い数値は `<=>`、文字列は `cmp` で比較する。

```perl
my $sorted = orderby($table, 'A', 'B');
```

### `detach($table)`

`table` からメタデータ行を分離する。

```perl
my ($rows, $meta) = detach($table);
# メタデータ行がない場合 $meta は undef
```

### `attach($rows, $meta)`

メタデータ行を `rows` の先頭に付加する。`$meta` が `undef` の場合は `$rows` をそのまま返す。

```perl
my $table = attach($rows, $meta);
```

## データ構造

### `rows` と `table`

```perl
# rows
[
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]

# table（validate が返す形式）
[
    {'#' => {attrs => {A => 'num', B => 'str', C => 'num'}, order => ['A', 'B', 'C']}},
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]
```

- `attrs`：カラム名をキー、型情報（`'num'` または `'str'`）を値とするハッシュ
- `order`：カラム順序を表す配列リファレンス（`validate($table, $cols)` を通じた場合のみ生成）

### グループ化後のテーブル

```perl
[
    {'#' => {attrs => {A => 'num', B => 'str', C => 'num'}, order => ['A', 'B', 'C']}},
    {A => 1, '@' => [
        {B => 'foo', C => 3},
        {B => 'bar', C => 7},
    ]},
    {A => 5, '@' => [
        {B => 'baz', C => 9},
    ]},
]
```

- `'#'`：メタデータ行。`attrs` と任意の `order` を保持する
- `'@'`：子行の配列リファレンス
