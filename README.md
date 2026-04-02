# TableTools

Perl の Array of Hashes（AoH）を操作するユーティリティモジュール。
テーブル構造の検証・グループ化・展開・メタデータ管理を行う関数群を提供する。

## 使い方

```perl
use TableTools qw(validate group expand detach attach);
```

## 関数

### `validate($table, $cols)`

テーブルを検証する。

- `$cols` なし：全行が同じキー集合を持つか検証し、入力をそのまま返す
- `$cols` あり：全行が `$cols` のキー集合と一致するか検証し、型情報付きのメタデータ行を先頭に付加したテーブルを返す

```perl
my $table = validate(\@rows, ['A', 'B', 'C']);  # メタデータ付きで返す
my $table = validate(\@rows);                    # 検証のみ
```

### `group($table, @cols_list)`

テーブルを多段グループ化する。グループキーの値でソートし、子行を `'@'` キーに格納する。

```perl
my $grouped = group($table, ['A']);           # 1段グループ化
my $grouped = group($table, ['A'], ['B']);    # 2段グループ化
```

### `expand($table)`

グループ化されたテーブルを完全にフラット化する。何重のネストでも一度に展開する。

```perl
my $flat = expand($grouped);
```

### `detach($table)`

テーブルからメタデータ行を分離する。

```perl
my ($meta, $bare) = detach($table);
```

### `attach($table, $meta)`

メタデータ行をテーブルの先頭に付加する。`$meta` が `undef` の場合は何もしない。

```perl
my $table = attach($bare, $meta);
```

## データ構造

### テーブル

```perl
# 純粋な AoH
[
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]

# メタデータ付き AoH（validate($table, $cols) が返す形式）
[
    {'#' => [{col => 'A', attr => 'num'}, {col => 'B', attr => 'str'}, {col => 'C', attr => 'num'}]},
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]
```

### グループ化後

```perl
[
    {'#' => [...]},
    {A => 1, '@' => [
        {B => 'foo', C => 3},
        {B => 'bar', C => 7},
    ]},
]
```

- `'#'`：メタデータ行。カラム名と型情報（`'num'` / `'str'`）を保持
- `'@'`：子行の配列リファレンス
