# TableTools API Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `design-concept.md` の新方針（`detach`/`attach` を除く全 API が `validate` を内部呼び出し、`rows`/`table` どちらも受け取れる、`validate` アーリーリターン、`orderby` が `$cols` arrayref を受け取る）を実装・ドキュメントに反映する。

**Architecture:**
`_resolve_meta` を廃止し、`group`/`orderby`/`expand` の冒頭で `validate($aoh)` → `detach($table)` のパターンに統一する。`validate` に「`attrs` 付き `table` + `$cols` なし → 同一参照を返す」アーリーリターンを追加する。`orderby` のシグネチャを `@cols`（フラットなリスト）から `$cols`（配列リファレンス）に変更する。

**Tech Stack:** Perl 5, Test::More, Scalar::Util

---

## ファイルマップ

| ファイル | 変更種別 | 内容 |
|---|---|---|
| `test/tabletools.t` | 更新 | validate マトリクス対応・orderby arrayref 化・各 API の rows 直接入力テスト追加 |
| `src/TableTools.pm` | 更新 | validate アーリーリターン・orderby シグネチャ変更・group/orderby/expand の内部 validate 化・_resolve_meta 削除・コメント更新 |
| `docs/spec.md` | 更新 | 節ごと差し替え（前提条件・用語記号・データ構造・コーディング方針・各関数仕様・エラーハンドリング） |
| `docs/test-spec.md` | 更新 | 節ごと差し替え（validate マトリクス・group/orderby/expand/attach の rows/table 両入力整理） |

---

## Task 1: validate テスト変更（マトリクス対応）

**Files:**
- Modify: `test/tabletools.t`

### 変更の概要

- 旧テスト「`cols なし・既存 attrs が num のカラムに非数値で die`」を削除し、アーリーリターン確認テスト（A-6）に差し替える
- 旧テスト「`cols なし・既存 attrs が str のカラムに数値は通過`」を削除（アーリーリターンで自明なため）
- 新テスト A-4「`attrs` 付き `table` は同一参照が返る」を追加
- 新テスト B-4「`$cols` あり・`attrs` 付き `table`・`$cols` 順で `order` が設定される」を追加

- [ ] **Step 1: 旧テスト2件を削除し、A-4・A-6・B-4 を追加する**

`test/tabletools.t` の該当箇所を以下のとおり変更する。

**削除する2つのテスト（旧 line 78〜88）:**
```perl
# 削除: validate: cols なし・既存 attrs が num のカラムに非数値で die
subtest 'validate: cols なし・既存 attrs が num のカラムに非数値で die' => sub {
    my $table = validate([{A => 1}, {A => 2}], ['A']);
    eval { validate([{'#' => {attrs => {A => 'num'}}}, {A => 'x'}]) };
    like($@, qr/num/i, '既存 num カラムに非数値で die');
};

subtest 'validate: cols なし・既存 attrs が str のカラムに数値は通過' => sub {
    my $table = [{'#' => {attrs => {A => 'str'}}}, {A => 1}, {A => 2}];
    my $result = validate($table);
    is($result->[0]{'#'}{attrs}{A}, 'str', 'str カラムに数値でも str のまま');
};
```

**代わりに以下を追加する（`validate: cols あり・既存 order と異なる順序で order が上書きされる` の直後に挿入）:**
```perl
subtest 'validate: cols なし・attrs 付き table は同一参照が返る（アーリーリターン）' => sub {
    my $table  = validate([{A => 1, B => 'x'}, {A => 2, B => 'y'}], ['A', 'B']);
    my $result = validate($table);
    is($result, $table, '同一参照が返る（再検証しない）');
};

subtest 'validate: cols なし・attrs 付き table は再検証しない（die しない）' => sub {
    my $broken = [{'#' => {attrs => {A => 'num'}}}, {A => 'not_a_number'}];
    my $result = eval { validate($broken) };
    ok(!$@,              'die しない（アーリーリターン）');
    is($result, $broken, '同一参照が返る');
};

subtest 'validate: cols あり・attrs 付き table・$cols 順で order が設定される' => sub {
    my $table  = validate([{A => 1, B => 'x'}, {A => 2, B => 'y'}]);
    my $result = validate($table, ['B', 'A']);
    is_deeply($result->[0]{'#'}{order}, ['B', 'A'], '$cols 順で order が設定される');
};
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: A-4「同一参照が返る」と A-6「die しない」の2テストが FAIL する。B-4「$cols 順で order」は FAIL する可能性がある。その他のテストは PASS のまま。

---

## Task 2: validate アーリーリターン実装

**Files:**
- Modify: `src/TableTools.pm` (`validate` 関数のみ)

- [ ] **Step 1: validate の冒頭にアーリーリターン条件を追加する**

`src/TableTools.pm` の `validate` 関数を以下のとおり変更する（`_resolve_meta` はまだ残す）。

```perl
sub validate {
    my ($aoh, $cols) = @_;
    # attrs 付き table + $cols なし → 同一参照をそのまま返す（アーリーリターン）
    if (!$cols && @$aoh && exists $aoh->[0]{'#'} && $aoh->[0]{'#'}{attrs}) {
        return $aoh;
    }
    # meta と rows を分離する
    my ($rows, $meta, $attrs, $order) = _resolve_meta($aoh, $cols);
    return [] unless @$rows;

    my $col_count = scalar keys %$attrs;

    # 列集合を検証する
    for my $i (0 .. $#$rows) {
        my $row      = $rows->[$i];
        my @row_keys = keys %$row;
        die "Row $i: column count mismatch" unless @row_keys == $col_count;
        for my $k (@row_keys) {
            die "Row $i: unexpected column '$k'" unless defined $attrs->{$k};
            die "Row $i: column '$k' value is undef" unless defined $row->{$k};
            my $is_str = !looks_like_number($row->{$k});
            # attrs を確定する
            if ($attrs->{$k} eq 'unknown') {
                $attrs->{$k} = $is_str ? 'str' : 'num?';
            } elsif ($attrs->{$k} eq 'num?') {
                $attrs->{$k} = 'str' if $is_str;
            } elsif ($attrs->{$k} eq 'num' && $is_str) {
                die "Row $i: column '$k' is num but got non-numeric value";
            }
        }
    }

    for my $k (keys %$attrs) {
        $attrs->{$k} = 'num' if $attrs->{$k} eq 'num?';
    }

    # attach() で meta を戻して返す
    return attach($rows, $meta);
}
```

- [ ] **Step 2: テストを実行して Task 1 で追加したテストが通ることを確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: 全 PASS。

- [ ] **Step 3: コミットする**

```bash
git add test/tabletools.t src/TableTools.pm
git commit -m "feat: validate に attrs 付き table のアーリーリターンを追加"
```

---

## Task 3: orderby テスト変更（$cols arrayref + rows 直接入力）

**Files:**
- Modify: `test/tabletools.t` (orderby サブテスト全件)

- [ ] **Step 1: orderby の全テストを $cols arrayref 形式に変更し、rows 直接入力テストを追加する**

`test/tabletools.t` の orderby セクション全体を以下のとおり差し替える。

```perl
subtest 'orderby: 数値カラムによるソート' => sub {
    my $table  = validate([{A => 10, B => 'z'}, {A => 2, B => 'a'}, {A => 5, B => 'm'}], ['A', 'B']);
    my $sorted = orderby($table, ['A']);
    is($sorted->[1]{A}, 2,  '1行目 A=2');
    is($sorted->[2]{A}, 5,  '2行目 A=5');
    is($sorted->[3]{A}, 10, '3行目 A=10');
};

subtest 'orderby: 文字列カラムによるソート' => sub {
    my $table  = validate([{A => 1, B => 'z'}, {A => 2, B => 'a'}, {A => 3, B => 'm'}], ['A', 'B']);
    my $sorted = orderby($table, ['B']);
    is($sorted->[1]{B}, 'a', '1行目 B=a');
    is($sorted->[2]{B}, 'm', '2行目 B=m');
    is($sorted->[3]{B}, 'z', '3行目 B=z');
};

subtest 'orderby: 複数カラムによる優先順位ソート' => sub {
    my $table  = validate(
        [{A => 1, B => 'z'}, {A => 2, B => 'a'}, {A => 1, B => 'a'}],
        ['A', 'B'],
    );
    my $sorted = orderby($table, ['A', 'B']);
    is($sorted->[1]{A}, 1,   '1行目 A=1');
    is($sorted->[1]{B}, 'a', '1行目 B=a');
    is($sorted->[2]{A}, 1,   '2行目 A=1');
    is($sorted->[2]{B}, 'z', '2行目 B=z');
    is($sorted->[3]{A}, 2,   '3行目 A=2');
};

subtest 'orderby: メタデータを引き継ぐ' => sub {
    my $table  = validate([{A => 2, B => 'x'}, {A => 1, B => 'y'}], ['A', 'B']);
    my $sorted = orderby($table, ['A']);
    ok(exists $sorted->[0]{'#'},                    '先頭にメタデータ行がある');
    ok(exists $sorted->[0]{'#'}{order},             'order が引き継がれている');
    is_deeply($sorted->[0]{'#'}{order}, ['A', 'B'], 'order の内容が正しい');
    is($sorted->[0]{'#'}{attrs}{A}, 'num',          'attrs A が引き継がれている');
    is($sorted->[0]{'#'}{attrs}{B}, 'str',          'attrs B が引き継がれている');
};

subtest 'orderby: rows を直接渡せる' => sub {
    my $rows   = [{A => 3}, {A => 1}, {A => 2}];
    my $sorted = orderby($rows, ['A']);
    is($sorted->[1]{A}, 1, '1行目 A=1');
    is($sorted->[2]{A}, 2, '2行目 A=2');
    is($sorted->[3]{A}, 3, '3行目 A=3');
};

subtest 'orderby: 存在しないカラム指定で die' => sub {
    my $table = validate([{A => 1}, {A => 2}], ['A']);
    eval { orderby($table, ['B']) };
    like($@, qr/column/i, '未存在カラム指定で die');
};
```

（旧テスト「`orderby: バリデートなしの AoH で die`」は削除する。）

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: orderby の全テストが FAIL する（シグネチャ不一致のため）。

---

## Task 4: orderby 実装変更（$cols arrayref + validate 内部呼び出し）

**Files:**
- Modify: `src/TableTools.pm` (`orderby` 関数のみ)

- [ ] **Step 1: orderby を $cols arrayref + validate 内部呼び出しに変更する**

```perl
sub orderby {
    my ($aoh, $cols) = @_;
    return $aoh unless $cols && @$cols;

    # validate を内部で呼ぶ（rows でも table でも受け取れる）
    my $table = validate($aoh);
    return $table unless @$table;
    my ($rows, $meta) = detach($table);
    my $attrs = $meta->{'#'}{attrs};

    _check_cols($attrs, @$cols);

    # attrs を見て rows をソートする
    my @sorted = sort {
        for my $col (@$cols) {
            my $cmp = $attrs->{$col} eq 'num'
                ? (($a->{$col} // 0) <=> ($b->{$col} // 0))
                : (($a->{$col} // '') cmp ($b->{$col} // ''));
            return $cmp if $cmp;
        }
        return 0;
    } @$rows;

    # attach() で meta を戻して返す
    return attach(\@sorted, $meta);
}
```

- [ ] **Step 2: テストを実行して全 PASS を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: 全 PASS。

- [ ] **Step 3: コミットする**

```bash
git add test/tabletools.t src/TableTools.pm
git commit -m "feat: orderby を \$cols arrayref に変更し validate を内部呼び出しに統一"
```

---

## Task 5: group テスト変更（rows 直接入力）

**Files:**
- Modify: `test/tabletools.t` (group の「バリデートなしで die」テストのみ)

- [ ] **Step 1: 旧テストを rows 直接入力テストに差し替える**

`test/tabletools.t` の以下のテストを削除する。

```perl
# 削除
subtest 'group: バリデートなしの AoH で die' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    eval { group($table, ['A']) };
    like($@, qr/validate/i, 'バリデートなしで die');
};
```

以下に差し替える。

```perl
subtest 'group: rows を直接渡せる' => sub {
    my $rows    = [{A => 1, B => 'x'}, {A => 1, B => 'y'}, {A => 2, B => 'z'}];
    my $grouped = group($rows, ['A']);
    is($grouped->[1]{A}, 1,          'rows を直接渡してもグループ化される');
    is(scalar @{$grouped->[1]{'@'}}, 2, 'A=1 の子は2件');
    is($grouped->[2]{A}, 2,          'A=2 グループも正しい');
};
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: `group: rows を直接渡せる` が FAIL する（現実装では attrs なしで die するため）。

---

## Task 6: group 実装変更（validate 内部呼び出し）

**Files:**
- Modify: `src/TableTools.pm` (`group` 関数のみ)

- [ ] **Step 1: group を validate 内部呼び出しに変更する**

```perl
sub group {
    my ($aoh, @cols_list) = @_;
    return $aoh unless @cols_list;

    # validate を内部で呼ぶ（rows でも table でも受け取れる）
    my $table = validate($aoh);
    return $table unless @$table;
    my ($rows, $meta) = detach($table);
    my $attrs = $meta->{'#'}{attrs};

    _check_cols($attrs, map { @$_ } @cols_list);

    # 入力順のまま連続行をまとめる
    my $grouped = _group_rows($rows, $attrs, @cols_list);
    # attach() で meta を戻して返す
    return attach($grouped, $meta);
}
```

- [ ] **Step 2: テストを実行して全 PASS を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: 全 PASS。

- [ ] **Step 3: コミットする**

```bash
git add test/tabletools.t src/TableTools.pm
git commit -m "feat: group を validate 内部呼び出しに統一し rows を直接受け取れるよう変更"
```

---

## Task 7: expand テスト変更（rows 直接入力）

**Files:**
- Modify: `test/tabletools.t` (expand の「バリデートなしで die」テストのみ)

- [ ] **Step 1: 旧テストを rows 直接入力テストに差し替える**

`test/tabletools.t` の以下のテストを削除する。

```perl
# 削除
subtest 'expand: バリデートなしの AoH で die' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    eval { expand($table) };
    like($@, qr/validate/i, 'バリデートなしで die');
};
```

以下に差し替える。

```perl
subtest 'expand: rows を直接渡せる' => sub {
    my $rows   = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    my $result = expand($rows);
    is(scalar @$result, 3, 'meta + 2行 = 3要素');
    is($result->[1]{A}, 1, '1行目 A=1');
    is($result->[2]{A}, 2, '2行目 A=2');
};
```

- [ ] **Step 2: テストを実行して失敗を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: `expand: rows を直接渡せる` が FAIL する。

---

## Task 8: expand 実装変更（validate 内部呼び出し）

**Files:**
- Modify: `src/TableTools.pm` (`expand` 関数のみ)

- [ ] **Step 1: expand を validate 内部呼び出しに変更する**

```perl
sub expand {
    my ($aoh) = @_;
    # validate を内部で呼ぶ（rows でも table でも受け取れる）
    my $table = validate($aoh);
    return $table unless @$table;
    my ($rows, $meta) = detach($table);
    # '@' を再帰的に展開する
    my @flat = _expand_rows($rows, {});

    # attach() で meta を戻して返す
    return attach(\@flat, $meta);
}
```

- [ ] **Step 2: テストを実行して全 PASS を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: 全 PASS。

- [ ] **Step 3: コミットする**

```bash
git add test/tabletools.t src/TableTools.pm
git commit -m "feat: expand を validate 内部呼び出しに統一し rows を直接受け取れるよう変更"
```

---

## Task 9: _resolve_meta 削除 + 冒頭コメント更新

**Files:**
- Modify: `src/TableTools.pm` (`_resolve_meta` 削除、`package` 直下コメント更新)

この時点で `_resolve_meta` は `validate` からのみ呼ばれているが、`validate` も `_resolve_meta` を経由しなくなるよう書き直す。

- [ ] **Step 1: validate を _resolve_meta 非経由に書き直し、_resolve_meta を削除する**

`src/TableTools.pm` の `_resolve_meta` 関数を丸ごと削除し、`validate` を以下のとおり書き直す。

```perl
sub validate {
    my ($aoh, $cols) = @_;
    # attrs 付き table + $cols なし → 同一参照をそのまま返す（アーリーリターン）
    if (!$cols && @$aoh && exists $aoh->[0]{'#'} && $aoh->[0]{'#'}{attrs}) {
        return $aoh;
    }

    # meta と rows を分離する
    my ($rows, $meta) = detach($aoh);
    $meta //= {'#' => {}};

    my $attrs = $meta->{'#'}{attrs};
    my $order = $meta->{'#'}{order};

    if (!$attrs) {
        my @keys = $cols ? @$cols : @$rows ? keys %{$rows->[0]} : ();
        $attrs = { map { $_ => 'unknown' } @keys };
    }

    if ($cols) {
        die "cols count mismatch" unless @$cols == scalar keys %$attrs;
        _check_cols($attrs, @$cols);
        $order = [@$cols];
    }

    my $new_meta = {'#' => {attrs => $attrs}};
    $new_meta->{'#'}{order} = $order if $order;

    return [] unless @$rows;

    my $col_count = scalar keys %$attrs;

    # 列集合を検証する
    for my $i (0 .. $#$rows) {
        my $row      = $rows->[$i];
        my @row_keys = keys %$row;
        die "Row $i: column count mismatch" unless @row_keys == $col_count;
        for my $k (@row_keys) {
            die "Row $i: unexpected column '$k'" unless defined $attrs->{$k};
            die "Row $i: column '$k' value is undef" unless defined $row->{$k};
            my $is_str = !looks_like_number($row->{$k});
            # attrs を確定する
            if ($attrs->{$k} eq 'unknown') {
                $attrs->{$k} = $is_str ? 'str' : 'num?';
            } elsif ($attrs->{$k} eq 'num?') {
                $attrs->{$k} = 'str' if $is_str;
            } elsif ($attrs->{$k} eq 'num' && $is_str) {
                die "Row $i: column '$k' is num but got non-numeric value";
            }
        }
    }

    for my $k (keys %$attrs) {
        $attrs->{$k} = 'num' if $attrs->{$k} eq 'num?';
    }

    # attach() で meta を戻して返す
    return attach($rows, $new_meta);
}
```

- [ ] **Step 2: package 直下のコメントを design-concept.md の Rules セクションと一致させる**

`package TableTools;` の直下のコメントブロックを以下のとおり差し替える。

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
# attach() は validate() を呼ばず、rows と meta から table を組み立てる
# attrs は必須で、order は列順を指定した validate() のときだけ付く
# orderby() は attrs に従って num は数値、str は文字列として並べる
# group() は入力順をそのまま使うので、必要なら先に orderby() を使う
# group() では非連続な同一キーの再出現をエラーにする
# expand() は group() 済みの table を平坦化して table を返す
```

- [ ] **Step 3: テストを実行して全 PASS を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: 全 PASS。

- [ ] **Step 4: コミットする**

```bash
git add src/TableTools.pm
git commit -m "refactor: _resolve_meta を廃止し validate を直接 detach 呼び出し形式に変更"
```

---

## Task 10: attach テスト追加（$meta 同一参照確認）

**Files:**
- Modify: `test/tabletools.t` (attach サブテストに1件追加)

- [ ] **Step 1: attach テストに $meta 同一参照テストを追加する**

既存の `attach: meta が undef` テストの直後に以下を追加する。

```perl
subtest 'attach: 渡した $meta がそのまま先頭に付く' => sub {
    my $meta  = {'#' => {attrs => {A => 'num'}, order => ['A']}};
    my $rows  = [{A => 1}, {A => 2}];
    my $table = attach($rows, $meta);
    is($table->[0], $meta, '渡した $meta と同一参照が先頭に付く');
};
```

- [ ] **Step 2: テストを実行して全 PASS を確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: 全 PASS（`attach` は実装変更不要のため既に通る）。

- [ ] **Step 3: コミットする**

```bash
git add test/tabletools.t
git commit -m "test: attach に \$meta 同一参照テストを追加"
```

---

## Task 11: docs/spec.md 更新（節ごと差し替え）

**Files:**
- Modify: `docs/spec.md`

旧前提が残らないよう、以下の各節を**節ごと差し替える**。一部追記では旧記述が残るため必ず節全体を置き換えること。

- [ ] **Step 1: 「用語と記号」節から `@cols` を削除する**

`docs/spec.md` の「用語と記号」節から以下の1行を削除する。

```
- `@cols`: カラム名の並び
```

- [ ] **Step 2: 「前提条件・制限事項」節を差し替える**

節全体を以下の内容に置き換える。

```markdown
## 前提条件・制限事項

`detach()` と `attach()` を除く各 API は内部で `validate()` を呼ぶ。
`attach()` は `validate()` を呼ばない低レベルプリミティブであり、受け取った `$rows` と `$meta` をそのまま組み立てる。
`detach()` と `attach()` を除く各 API は `rows` と `table` のどちらを受け取ってもよい。

`attrs` 付き `table` を `$cols` なしで `validate()` に渡すと、各行の検証をスキップして同一参照を返す（アーリーリターン）。
これは「先頭行に `attrs` がある = `validate` が生成した信頼できる `table`」という実装判断に基づく。
各行の型整合は確認しない。

行ごとにキー集合が異なる場合の動作は保証されない。処理中に存在しないカラムが見つかった場合は `die` する。

```perl
my $sorted  = orderby(\@rows, ['A', 'B']);   # rows を直接渡せる
my $grouped = group(\@rows, ['A']);           # rows を直接渡せる
my $flat    = expand($grouped);
```
```

- [ ] **Step 3: 「データ構造 — `rows` と `table`」節の該当記述を更新する**

以下の記述を削除する。

```
`group`・`expand`・`orderby` は `table` のみ受け付ける。
```

以下に置き換える。

```
`detach()` と `attach()` を除く各 API は `rows` と `table` のどちらも受け付ける。
`validate` の戻り値は常に `table`。メタデータのない形が必要な場合は `detach` を利用する。
```

- [ ] **Step 4: 「コーディング方針」節を差し替える**

節全体を以下の内容に置き換える。

```markdown
## コーディング方針

各パブリック API (`detach`・`attach` を除く) は冒頭で `validate($aoh)` を呼び出す。空テーブル（`[]`）はそのまま返す。
`validate` の戻り値を `detach` で分離してメタとデータ行を取り出す。
本体ロジックはメタデータを知らない内部関数に切り出す。
処理完了後、トップレベルでのみ `attach` でメタデータを先頭に戻す。
`attach` は `validate` を呼ばず、渡された `$rows` と `$meta` をそのまま組み立てる。
```

- [ ] **Step 5: 「関数仕様 — `validate`」節を差し替える**

`validate` の関数仕様節全体を以下のとおり置き換える（`$cols` なし / あり の2ブロック構成）。

```markdown
### `validate($aoh, $cols)`

テーブルを検証する。

| 引数 | 説明 |
|------|------|
| `$aoh` | `AoH`（`rows` / `table` どちらでもよい） |
| `$cols` | カラム名の配列リファレンス（省略可）|

**`$cols` なし:**

| 入力形式 | アーリーリターン | 動作 | 結果 |
|---|---|---|---|
| `rows` | なし | 型推論で `attrs` を確定 | `attrs` のみ付きの `table` |
| `table`（`attrs` あり） | あり | 同一参照をそのまま返す（再検証しない） | 入力と同じ参照 |
| 空テーブル | なし | — | `[]` |

補足: `table` 入力のアーリーリターンは「先頭行に `attrs` がある = validate 済みと信頼する」実装判断。型の不整合があっても再検証しない。

**`$cols` あり:**

| 入力形式 | アーリーリターン | 動作 | 結果 |
|---|---|---|---|
| `rows` | なし | `$cols` キー集合照合 + 型推論 | `attrs` + `order` 付きの `table` |
| `table`（`attrs` あり） | なし | `$cols` と `attrs` キー集合を照合 | `$cols` 順で `order` を設定した `table` |
| 空テーブル | なし | — | `[]` |

検証失敗・型不一致・キー集合不一致の場合は `die`。

```perl
my $table = validate(\@rows, ['A', 'B', 'C']);  # attrs + order 付きメタデータを返す
my $table = validate(\@rows);                    # attrs のみのメタデータを返す
my $same  = validate($table);                    # attrs 付きなら同一参照を返す
```
```

- [ ] **Step 6: 「関数仕様 — `group`」節の引数と手順を更新する**

引数表の `$table` を `$aoh`（`rows` / `table` どちらでもよい）に変更する。
手順1を以下に変更する。

```
1. validate($aoh) を呼び出す。空テーブルの場合はそのまま返す。detach でメタとデータ行を取り出す
```

- [ ] **Step 7: 「関数仕様 — `orderby`」節を更新する**

引数表を以下のとおり置き換える。

| 引数 | 説明 |
|------|------|
| `$aoh` | `AoH`（`rows` / `table` どちらでもよい） |
| `$cols` | ソートに使うカラム名の配列リファレンス |

手順を以下のとおり更新する。

```
1. validate($aoh) を呼び出す。空テーブルの場合はそのまま返す。detach でメタとデータ行を取り出す
2. $cols に存在しないカラム名が含まれる場合は即 die
3. $cols の優先順に従い、attrs の型情報でソート（num は <=>、str は cmp）
4. 入力のメタデータをそのまま付け直して返す
```

呼び出し例を更新する。

```perl
my $sorted = orderby($table, ['A', 'B']);
```

- [ ] **Step 8: 「関数仕様 — `expand`」節の引数と手順を更新する**

引数表の `$table` を `$aoh`（`rows` / `table` どちらでもよい）に変更する。
手順1を以下に変更する。

```
1. validate($aoh) を呼び出す。空テーブルの場合はそのまま返す。detach でメタとデータ行を取り出す
```

- [ ] **Step 9: 「エラーハンドリング」節を差し替える**

節全体を以下の内容に置き換える。

```markdown
## エラーハンドリング

- `validate`: キー集合の不一致、undef 値の行がある、確定済み `'num'` カラムに非数値を検出した場合は `die`
- `group`: 未知カラム指定時に `die`。非連続な同一キーの再出現時に `die "out of order: key reappeared"`
- `expand`: エラー条件なし（validate が内部で処理）
- `orderby`: 未知カラム指定時に `die`
```

- [ ] **Step 10: コミットする**

```bash
git add docs/spec.md
git commit -m "docs: spec.md を新方針（validate 内部呼び出し・orderby \$cols arrayref）に更新"
```

---

## Task 12: docs/test-spec.md 更新（節ごと差し替え）

**Files:**
- Modify: `docs/test-spec.md`

- [ ] **Step 1: `validate` 節を $cols なし / あり マトリクスに差し替える**

`docs/test-spec.md` の `## validate` 節全体を以下のとおり置き換える。

```markdown
## `validate`

**`$cols` なし**

| # | 入力形式 | ケース | アーリーリターン | 検証 | 期待結果 |
|---|---|---|---|---|---|
| A-1 | rows | 全行キー一致・正常データ | なし | あり（型推論） | `attrs` のみ付きの `table`。`order` は生成しない |
| A-2 | rows | キー不一致の行あり | なし | あり | `die`（"column" を含む） |
| A-3 | rows | 空テーブル | なし | なし | `[]` |
| A-4 | table（attrs あり） | 正常な `table` | あり | なし | 同一参照を返す |
| A-5 | table（attrs + order あり） | `order` 付き `table` | あり | なし | 同一参照を返す（`order` も保持） |
| A-6 | table（attrs あり） | `attrs` が `num` のカラムに非数値値あり | あり | なし | 同一参照を返す（再検証しないため die しない） |
| A-7 | table（空） | 空テーブル | なし | なし | `[]` |

**`$cols` あり**

| # | 入力形式 | ケース | アーリーリターン | 検証 | 期待結果 |
|---|---|---|---|---|---|
| B-1 | rows | 正常データ | なし | あり（型推論） | `attrs` + `order` 付きの `table` |
| B-2 | rows | キー不一致の行あり | なし | あり | `die`（"column" を含む） |
| B-3 | rows | 空テーブル | なし | なし | `[]` |
| B-4 | table（attrs あり） | `$cols` と `attrs` が一致 | なし | あり（`$cols` 照合） | `$cols` 順序で `order` が設定された `table` |
| B-5 | table（attrs あり） | `$cols` と `attrs` が不一致 | なし | あり（`$cols` 照合） | `die`（"column" を含む） |
| B-6 | table（attrs + order あり） | `$cols` と既存 `order` が異なる順序 | なし | あり | `$cols` の順序で `order` が上書きされる |
| B-7 | table（空） | 空テーブル | なし | なし | `[]` |
```

- [ ] **Step 2: `detach` 節と `attach` 節を更新する**

`## attach` 節に以下のテストケースを追加する。

| # | テストケース | 期待結果 |
|---|---|---|
| 3 | 渡した `$meta` がそのまま先頭に付く | `$table->[0]` が渡した `$meta` と同一参照である |

- [ ] **Step 3: `group` 節を差し替える**

`## group` 節全体を以下のとおり置き換える。

```markdown
## `group`

| # | 入力形式 | テストケース | 期待結果 |
|---|---|---|---|
| 1 | rows | `rows` を直接渡す | 内部で `validate` が呼ばれ、グループ化された `table` を返す |
| 2 | table | 1段グループ化 | グループキーの値でまとめられた行を `'@'` に格納。子行からグループキーが除かれる。メタデータ引き継ぎ |
| 3 | table | ソート済み入力で正常動作 | 入力行の順番どおりにグループが並ぶ（内部ソートなし） |
| 4 | table | 順序違反（同一キーが非連続で再出現） | `die`（メッセージに "out of order" を含む） |
| 5 | table | `attrs`・`order` 付きのグループ化 | 入力の `attrs`・`order` がそのまま引き継がれる |
| 6 | table | 2段グループ化 | 先頭の `@cols_list` でグループ化し、子行を残りの `@cols_list` で再帰的にグループ化する |
| 7 | table | 存在しないカラム指定 | `die`（メッセージに "column" を含む） |
```

- [ ] **Step 4: `orderby` 節を差し替える**

`## orderby` 節全体を以下のとおり置き換える（`$cols` arrayref 形式に統一）。

```markdown
## `orderby`

| # | 入力形式 | テストケース | 期待結果 |
|---|---|---|---|
| 1 | rows | `rows` を直接渡す（`['A']`） | 内部で `validate` が呼ばれ、ソートされた `table` を返す |
| 2 | table | 数値カラムによるソート（`['A']`） | `<=>` による数値ソートで行が並ぶ |
| 3 | table | 文字列カラムによるソート（`['B']`） | `cmp` による辞書順ソートで行が並ぶ |
| 4 | table | 複数カラムによる優先順位ソート（`['A', 'B']`） | 第1キーで並べ、同値なら第2キーで並べる |
| 5 | table | メタデータを引き継ぐ | 入力の `attrs`・`order` がそのまま引き継がれる |
| 6 | table | 存在しないカラム指定 | `die`（メッセージに "column" を含む） |
```

- [ ] **Step 5: `expand` 節を差し替える**

`## expand` 節全体を以下のとおり置き換える。

```markdown
## `expand`

| # | 入力形式 | テストケース | 期待結果 |
|---|---|---|---|
| 1 | rows | `rows` を直接渡す | 内部で `validate` が呼ばれ、`table` を返す（グループ化なしなので展開後も同内容） |
| 2 | table | 1段グループ化を展開 | 先頭にメタデータ行がある。元の行数に戻り、すべてのカラムがフラットな行に復元される |
| 3 | table | 2段グループ化を展開 | 多段ネストを一度にフラット化。元の行数・カラム値がすべて復元される |
| 4 | table | `attrs`・`order` 付きグループ化を展開 | 入力の `attrs`・`order` がそのまま引き継がれる |
```

- [ ] **Step 6: コミットする**

```bash
git add docs/test-spec.md
git commit -m "docs: test-spec.md を新方針（validate マトリクス・rows/table 両入力）に更新"
```

---

## 最終確認

- [ ] **全テストが通ることを確認する**

```bash
perl test/tabletools.t 2>&1
```

期待: 全 PASS。

- [ ] **コーディングのルール自己確認**

`src/TableTools.pm` について以下を確認する。

1. `package` 直下のコメントが `design-concept.md` の Rules セクションと完全一致している
2. `_resolve_meta` が残っていないこと（`grep _resolve_meta src/TableTools.pm` で何も出ない）
3. `group`/`orderby`/`expand` の冒頭が全て `validate($aoh)` → `return $table unless @$table` → `detach($table)` のパターンになっている
4. `orderby` の引数が `($aoh, $cols)` であり `@$cols` で参照している
5. `attach` に `validate` 呼び出しが含まれていないこと
