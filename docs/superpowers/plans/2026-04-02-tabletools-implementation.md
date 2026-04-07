# TableTools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Perl の Array of Hashes を操作する `TableTools` モジュールを、現行の上位仕様（`docs/spec.md` / `docs/test-spec.md` および worktree 側の同等文書）に一致する形で実装する。

**Public API:** `validate / group / expand / orderby / detach / attach`

**Architecture:** `Exporter` ベースの純粋関数モジュール。標準形は「先頭にメタデータ行を持つ AoH」。`validate` は bare AoH とメタデータ付き AoH の両方を受け付け、`group` / `expand` / `orderby` は `attrs` を持つメタデータ付きテーブルのみを受け付ける。入口は `_resolve_meta` で統一し、内部処理は bare AoH に対して行う。

**Tech Stack:** Perl 5、Test::More、Scalar::Util（`looks_like_number`）、Exporter

---

## ファイル構成

| ファイル | 役割 |
|----------|------|
| `src/TableTools.pm` | モジュール本体 |
| `test/tabletools.t` | テストスイート |

---

## 実装方針

- [ ] **メタデータ表現を統一する**

メタデータ行は先頭の 1 行だけで、形式は次のとおりとする。

```perl
{'#' => {attrs => {A => 'num', B => 'str'}, order => ['A', 'B']}}
```

- [ ] **`detach` / `attach` は低レベルプリミティブとして実装する**

`detach($table)` は次を返す。

```perl
my ($bare_table, $meta) = detach($table);
```

`attach($bare_table, $meta)` は `undef` メタデータなら入力をそのまま返し、メタデータがある場合だけ先頭に付加する。

- [ ] **入口処理を `_resolve_meta` に集約する**

`validate`・`group`・`expand`・`orderby` は先頭で `_resolve_meta($table)` または `_resolve_meta($table, $cols)` を呼び、以下を一度に解決する。

1. `detach` でメタデータとデータ行を分離する
2. `attrs` を確定する
3. 必要に応じて `order` を確定または保持する
4. `group` / `expand` / `orderby` では `attrs` がなければ `die` する

- [ ] **型推論は状態マシンで実装する**

`validate` は各カラムを `unknown -> num? -> num / str` の状態で走査し、確定済み `num` に非数値が来たら `die` する。数値判定は `looks_like_number` を使う。

- [ ] **`group` はソート済み入力を前提にする**

`group` は内部で並び替えない。`validate` や `orderby` を通した後のソート済み入力が渡される前提で走査し、同じキーが非連続で再出現したら `die "out of order: ..."` とする。

- [ ] **内部再帰ではメタデータを持ち込まない**

グループ化・展開の再帰処理では bare AoH だけを扱い、トップレベルでのみ `attach` して戻す。

---

## Task 1: モジュール骨格と公開 API

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] `TableTools` を `Exporter` ベースで定義する
- [ ] `@EXPORT_OK` に `validate group expand orderby detach attach` を並べる
- [ ] パブリック関数 stub と内部関数 stub（`_resolve_meta`、型検証/推論、グループ化/展開補助）を用意する
- [ ] `use_ok` と `can_ok` で公開 API 6 関数を確認する

期待状態:

```perl
use_ok('TableTools');
can_ok('TableTools', qw(validate group expand orderby detach attach));
```

---

## Task 2: `detach` / `attach`

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] メタデータ付きテーブルから `($bare_table, $meta)` を返すテストを書く
- [ ] bare AoH から `($table, undef)` を返すテストを書く
- [ ] `attach($bare, $meta)` が先頭にメタデータ行を付けるテストを書く
- [ ] `attach($bare, undef)` が入力をそのまま返すテストを書く
- [ ] 実装では返り値順を仕様どおり `($bare, $meta)` に固定する

テスト観点:

```perl
my ($bare, $meta) = detach($table);
my $table2 = attach($bare, $meta);
```

---

## Task 3: `_resolve_meta` とメタデータ正規化

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] bare AoH から `attrs` 初期状態を生成できることを確認する
- [ ] 既存メタデータの `attrs` / `order` を読み出せることを確認する
- [ ] `validate` 以外から `attrs` なしのテーブルを渡すと `die` することを確認する
- [ ] `$cols` 指定時に `attrs` とキー集合が一致しなければ `die` することを確認する
- [ ] `$cols` 指定時に `order = [@$cols]` を採用することを確認する

実装メモ:

```perl
my ($rows, $meta) = detach($table);
my ($resolved_rows, $resolved_meta, $attrs) = _resolve_meta($table, $cols);
```

`_resolve_meta` は少なくとも以下の情報を本体へ返せるようにしておくと実装しやすい。

- データ行配列
- 再利用または更新対象のメタデータ
- `attrs`
- `order`

---

## Task 4: `validate($table)` - `$cols` なし

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] 全行のキー集合が一致するケースのテストを書く
- [ ] キー不一致で `die` するケースのテストを書く
- [ ] 空テーブルで `[]` を返すテストを書く
- [ ] 既存 `order` を保持するケースのテストを書く
- [ ] 既存 `attrs` が `num` のカラムに非数値が来たら `die` するテストを書く
- [ ] 既存 `attrs` が `str` のカラムに数値が来ても通るテストを書く
- [ ] 実装では `attrs` 付きメタデータを返し、`order` は新規生成しないことを徹底する

期待結果:

- bare AoH を受け取っても戻り値はメタデータ付きテーブル
- `order` は入力に既存のものがあれば保持
- 空テーブルは `[]` のまま

---

## Task 5: `validate($table, $cols)` - `$cols` あり

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] 正常系で `attrs` と `order` の両方を持つメタデータが付くテストを書く
- [ ] キー不一致で `die` するテストを書く
- [ ] 空テーブルで `[]` を返すテストを書く
- [ ] 既存 `attrs` と `$cols` の集合不一致で `die` するテストを書く
- [ ] 既存 `order` と異なる順序でも `$cols` で上書きされるテストを書く
- [ ] 実装では `$cols` の順序どおり `order` を付与する

期待結果:

```perl
my $table = validate(\@rows, ['A', 'B', 'C']);
# => {'#' => {attrs => {...}, order => ['A', 'B', 'C']}} を先頭に持つ
```

---

## Task 6: 型推論と型検証

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] 全値が数値なら `num` になるテストを書く
- [ ] 1 つでも非数値があれば `str` になるテストを書く
- [ ] 既存 `attrs = num` の列に非数値が来たら `die` するテストを書く
- [ ] `undef` 値を含む場合に `die` するテストを書く
- [ ] 状態マシン実装を共通化し、`validate` の両経路から使う

状態:

| 現在の状態 | 値が数値 | 値が非数値 |
|-----------|---------|----------|
| `unknown` | `num?`  | `str`    |
| `num?`    | `num?`  | `str`    |
| `num`     | `num`   | `die`    |
| `str`     | `str`   | `str`    |

---

## Task 7: `orderby`

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] 数値カラムを `<=>` でソートするテストを書く
- [ ] 文字列カラムを `cmp` でソートするテストを書く
- [ ] 複数カラム優先のソートテストを書く
- [ ] 入力メタデータをそのまま保持するテストを書く
- [ ] bare AoH を渡すと `die` するテストを書く
- [ ] 未知カラム指定で `die` するテストを書く

実装メモ:

- `attrs` に基づいて比較演算子を切り替える
- 並べ替え対象はデータ行のみ
- 戻り値ではトップレベルに元のメタデータを付け直す

---

## Task 8: `group` - 1段グループ化

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] `validate` 済みテーブルを 1 段グループ化するテストを書く
- [ ] 子行からグループキー列が除かれることを確認する
- [ ] 入力順のままグループが並ぶことを確認する
- [ ] 同一キーが非連続で再出現したとき `out of order` で `die` するテストを書く
- [ ] 入力メタデータが保持されるテストを書く
- [ ] 未知カラム指定で `die` するテストを書く
- [ ] bare AoH を渡すと `die` するテストを書く

実装メモ:

- 内部ソートはしない
- 走査中に現在キーと直前キーを比較して境界を検出する
- すでに閉じたキーが再登場したら順序違反とみなす

---

## Task 9: `group` - 多段グループ化

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] `group($table, ['A'], ['B'])` の 2 段グループ化テストを書く
- [ ] 孫行から上位グループキーが除かれていることを確認する
- [ ] 再帰処理の中でメタデータを持ち込まない実装にする
- [ ] トップレベルの戻り値だけにメタデータを再付加する

期待形:

```perl
[
    {'#' => {...}},
    {A => 1, '@' => [
        {B => 'x', '@' => [
            {C => 10},
            {C => 20},
        ]},
    ]},
]
```

---

## Task 10: `expand`

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] 1 段グループ化を元に戻すテストを書く
- [ ] 2 段グループ化を完全にフラット化するテストを書く
- [ ] メタデータがそのまま保持されるテストを書く
- [ ] bare AoH を渡すと `die` するテストを書く
- [ ] 再帰展開で親キーと子行を正しくマージする

実装メモ:

- `'@'` を持つ行は再帰展開する
- `'@'` を持たない行はフラットな結果として push する
- 戻り値のメタデータは入力トップレベルのものをそのまま再利用する

---

## セルフレビュー観点

- [ ] `validate` の戻り値が常にメタデータ付きテーブルになっているか（空テーブル除く）
- [ ] `validate($table)` が `order` を新規生成していないか
- [ ] `validate($table, $cols)` が `order` を `$cols` で上書きしているか
- [ ] `detach` の返り値順が `($bare, $meta)` になっているか
- [ ] `group` が内部ソートしていないか
- [ ] `group` の順序違反検出があるか
- [ ] `orderby` が API とテスト計画に含まれているか
- [ ] `group` / `expand` / `orderby` が bare AoH を拒否するか
- [ ] メタデータ形式が `{'#' => {attrs => ..., order => ...}}` に揃っているか

---

## 変更時の注意

- この計画書は上位仕様に従属する。食い違いが見つかった場合は `docs/spec.md` / `docs/test-spec.md` を正とし、この計画書側を更新する
- 実装途中で仕様変更が入ったら、先にこの計画書とテスト仕様を同期してからコードへ進む
