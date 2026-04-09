# 変更仕様書
Date: 2026-04-09

## 背景と目的

`validate()` が生成するメタデータに `count`（table の rows 件数）を追加する。
これにより、テーブルを受け取った側が `detach()` せずに件数を参照できるようになる。

### `count` の位置づけ

`count` は `validate()` が meta を新規生成するときに必ず含めるキーである。
`attrs` が必須、`order` が任意であるのと同様に、`validate()` が生成した meta では `count` も必須となる。

`validate()` のアーリーリターン（`attrs` を持つ既存 meta の table をそのまま返す場合）は
meta を生成しないため、このキー追加の保証対象外である。
`count` のない旧形式の table はアーリーリターンでそのまま通過し、後付け補完は行わない。
これは意図的な設計であり、旧形式 table の通過を例外として許容する。

## 変更対象ファイル

| ファイル | 変更種別 |
|---|---|
| `docs/design/design-concept.md` | `count` の定義・例・Rules を追記 |
| `src/TableTools.pm` | `validate()` / `group()` / `expand()` の meta 生成を更新 |
| `docs/spec.md` | `count` を含む形に仕様を更新 |
| `docs/test-spec.md` | テスト仕様を `count` 前提に更新 |
| `test/tabletools.t` | meta 比較箇所を `count` 含む形に更新 |

---

## 0. `docs/design/design-concept.md` の変更

### 0-1. メタデータの定義に `count` を追加する

`attrs`・`order` と並べて `count` を定義する。

```
- `count` は validate() が生成する meta に必ず含まれるキー
- `count` は table の rows 件数（スカラー値）を表す
- `attrs` と `count` が必須、`order` が任意
```

メタデータ例と table 例に `count` を追加し、必須・任意の区別を例でも読めるようにする。

```perl
# メタデータ例（validate() が生成する meta: attrs と count が必須、order は任意）
{'#' => {
    attrs => {A => 'num', B => 'str', C => 'num'},
    count => 2,
    order => ['A', 'B', 'C'],   # 省略可
}}

# table 例
[
    {'#' => {
        attrs => {A => 'num', B => 'str', C => 'num'},
        count => 2,
        order => ['A', 'B', 'C'],   # 省略可
    }},
    {A => 1, B => 'x', C => 10},
    {A => 2, B => 'y', C => 20},
]
```

### 0-2. 方針に `count` に関する記述を追加する

```
- `validate()` が meta を新規生成するときは `count` を必ず含める
- `count` は table の rows 件数とする
- `orderby()` は rows 件数を変えないので、入力 table の meta をそのまま維持する
- `group()` は rows 件数が変わるので、`count` を再計算した新 meta を生成する
- `expand()` は rows 件数が変わるので、`count` を再計算した新 meta を生成する
```

### 0-3. Rules コメントに `count` を追加する

```perl
# count は validate() が生成する meta に必ず含まれ、table の rows 件数を表す
# orderby() は行数不変なので meta をそのまま維持する
# group() と expand() は rows 件数が変わるので count を再計算した新 meta を生成する
```

---

## 1. `src/TableTools.pm` の変更

### 1-1. 冒頭 Rules コメントに `count` を追加する

```perl
# count は validate() が生成する meta に必ず含まれ、table の rows 件数を表す
# orderby() は行数不変なので meta をそのまま維持する
# group() と expand() は rows 件数が変わるので count を再計算した新 meta を生成する
```

### 1-2. `validate()` の meta 生成に `count` を追加する

変更前：
```perl
my $new_meta = {'#' => {attrs => $attrs}};
$new_meta->{'#'}{order} = $order if $order;
```

変更後：
```perl
my $new_meta = {'#' => {attrs => $attrs, count => scalar(@$rows)}};
$new_meta->{'#'}{order} = $order if $order;
```

アーリーリターンの条件（`$cols` なし かつ `$meta->{'#'}{attrs}` が存在する）は変更なし。
`count` の有無は問わずそのまま返す。

### 1-3. `group()` の meta 生成を `count` 込みの新 meta に変更する

変更前：
```perl
return attach($grouped, $meta);
```

変更後：
```perl
my $new_meta = {'#' => {attrs => $attrs, count => scalar(@$grouped)}};
$new_meta->{'#'}{order} = $meta->{'#'}{order} if $meta->{'#'}{order};
return attach($grouped, $new_meta);
```

現仕様では `attrs` と `order`（存在する場合）を引き継ぎ、`count` のみ再計算する。
将来 meta にキーが増えた場合はこの引き継ぎ方針を見直す。

### 1-4. `expand()` の meta 生成を `count` 込みの新 meta に変更する

変更前：
```perl
return attach(\@flat, $meta);
```

変更後：
```perl
my $new_meta = {'#' => {attrs => $meta->{'#'}{attrs}, count => scalar(@flat)}};
$new_meta->{'#'}{order} = $meta->{'#'}{order} if $meta->{'#'}{order};
return attach(\@flat, $new_meta);
```

現仕様では `attrs` と `order`（存在する場合）を引き継ぎ、`count` のみ再計算する。
将来 meta にキーが増えた場合はこの引き継ぎ方針を見直す。

### 1-5. `detach()` と `attach()` は変更なし

どちらも受け取った meta をそのまま扱うため、この変更の影響を受けない。

---

## 2. `docs/spec.md` の変更

- メタデータの説明に `count` を追加する（`validate()` が生成する meta のキーとして）
- 各 API の説明で `count` の扱いを明記する

---

## 3. `docs/test-spec.md` の変更

- `count` を含むメタデータ比較のテストケースを追加・更新する
- `group()` と `expand()` のテストで返る `count` の期待値を明記する

---

## 4. `test/tabletools.t` の変更

- meta 比較をしている全テストに `count` を含める
- 具体的な変更が必要な箇所：
  - `validate()` が返す meta の比較
  - `orderby()` が返す meta の比較（`count` は入力と同じ値のまま）
  - `group()` が返す meta の比較（`count` = トップレベルグループ数）
  - `expand()` が返す meta の比較（`count` = 展開後フラット行数）

---

## 変更しない前提

- `attach()` は受け取った `rows` と `meta` をそのまま組み立てるだけ。`count` の補完は行わない
- `detach()` は meta をそのまま分離するだけ。`count` の検証は行わない
- 既存の `table`（`count` なし）を `validate()` に渡したとき、`attrs` を持つ meta があればそのまま返す。`count` の後付け補完は行わない。これは旧形式 table の通過を例外として許容する意図的な設計である
