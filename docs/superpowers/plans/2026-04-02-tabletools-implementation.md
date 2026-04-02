# TableTools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Perl の Array of Hashes を操作する `TableTools` モジュールを実装する（validate / group / expand / detach / attach の5関数）

**Architecture:** `Exporter` ベースの純粋関数モジュール。状態なし・OO なし。全関数はメタデータ付き AoH と純粋 AoH の両方を受け付ける。`_attrs` 内部関数が型推論の共通基盤。

**Tech Stack:** Perl 5、Test::More、Scalar::Util（looks_like_number）、Exporter

---

## ファイル構成

| ファイル | 役割 |
|----------|------|
| `src/TableTools.pm` | モジュール本体（全関数を実装） |
| `test/tabletools.t` | テストスイート（各タスクで追記） |

---

## Task 1: モジュールスケルトンとテストファイル修正

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] **Step 1: テストファイルを修正して失敗を確認**

`test/tabletools.t` を以下の内容に書き換える（`use lib '../src'` を `FindBin` で正しいパスに修正し、エクスポート確認テストを追加）:

```perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../src";

use_ok('TableTools');
can_ok('TableTools', qw(validate group expand detach attach));

done_testing;
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
perl -I src test/tabletools.t
```

期待する出力（失敗）:
```
ok 1 - use TableTools;
not ok 2 - TableTools->can('validate')
```

- [ ] **Step 3: モジュールスケルトンを実装**

`src/TableTools.pm` を以下の内容に書き換える:

```perl
package TableTools;

use strict;
use warnings;
use parent 'Exporter';
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw(validate group expand detach attach);

sub validate { }
sub group    { }
sub expand   { }
sub detach   { }
sub attach   { }

sub _attrs   { }

1;
```

- [ ] **Step 4: テストを実行して通過を確認**

```bash
perl -I src test/tabletools.t
```

期待する出力:
```
ok 1 - use TableTools;
ok 2 - TableTools->can('validate')
1..2
```

- [ ] **Step 5: コミット**

```bash
cd .claude/worktrees/feature/design-spec
git add src/TableTools.pm test/tabletools.t
git commit -m "feat: add TableTools module skeleton with Exporter"
```

---

## Task 2: `_attrs` 内部関数

全データ行をスキャンして各カラムの型（`'num'` / `'str'`）を返す内部関数。

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] **Step 1: テストを追加して失敗を確認**

`test/tabletools.t` の `done_testing;` の前に追加:

```perl
subtest '_attrs' => sub {
    my $table = [
        {A => 1,   B => 'foo', C => 3},
        {A => 2,   B => 'bar', C => 4},
        {A => 'x', B => 'baz', C => 5},
    ];
    my $attrs = TableTools::_attrs($table);
    is($attrs->{A}, 'str', 'A は文字列混在なので str');
    is($attrs->{B}, 'str', 'B は文字列なので str');
    is($attrs->{C}, 'num', 'C は全て数値なので num');
};

subtest '_attrs: メタデータ行を無視する' => sub {
    my $table = [
        {'#' => [{col => 'A', attr => 'num'}]},
        {A => 1},
        {A => 2},
    ];
    my $attrs = TableTools::_attrs($table);
    is($attrs->{A}, 'num', 'A は数値');
    ok(!exists $attrs->{'#'}, "'#' キーはカラムとして扱わない");
};
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
perl -I src test/tabletools.t
```

期待する出力（失敗）:
```
not ok - _attrs
```

- [ ] **Step 3: `_attrs` を実装**

`src/TableTools.pm` の `sub _attrs { }` を以下に書き換える:

```perl
sub _attrs {
    my ($table) = @_;
    my %attrs;
    for my $row (@$table) {
        next if exists $row->{'#'};
        for my $col (keys %$row) {
            $attrs{$col} //= 'num';
            $attrs{$col} = 'str' unless looks_like_number($row->{$col} // '');
        }
    }
    return \%attrs;
}
```

- [ ] **Step 4: テストを実行して通過を確認**

```bash
perl -I src test/tabletools.t
```

期待する出力:
```
ok - _attrs
ok - _attrs: メタデータ行を無視する
```

- [ ] **Step 5: コミット**

```bash
git add src/TableTools.pm test/tabletools.t
git commit -m "feat: implement _attrs internal type inference"
```

---

## Task 3: `detach` と `attach`

メタデータ行の分離・付加ユーティリティ。

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] **Step 1: テストを追加して失敗を確認**

`done_testing;` の前に追加:

```perl
subtest 'detach: メタデータあり' => sub {
    my $table = [
        {'#' => [{col => 'A', attr => 'num'}]},
        {A => 1},
        {A => 2},
    ];
    my ($meta, $bare) = detach($table);
    ok(defined $meta,           'meta が返る');
    is_deeply($meta->{'#'}, [{col => 'A', attr => 'num'}], 'meta の中身が正しい');
    is(scalar @$bare, 2,        'データ行が2件');
    is($bare->[0]{A}, 1,        '1行目のデータが正しい');
};

subtest 'detach: メタデータなし' => sub {
    my $table = [{A => 1}, {A => 2}];
    my ($meta, $bare) = detach($table);
    ok(!defined $meta,          'meta は undef');
    is(scalar @$bare, 2,        'データ行が2件');
};

subtest 'attach: meta あり' => sub {
    my $meta  = {'#' => [{col => 'A', attr => 'num'}]};
    my $bare  = [{A => 1}, {A => 2}];
    my $table = attach($bare, $meta);
    is(scalar @$table, 3,               '3要素（meta + データ2行）');
    ok(exists $table->[0]{'#'},         '先頭がメタデータ行');
    is($table->[1]{A}, 1,               'データ行が続く');
};

subtest 'attach: meta が undef' => sub {
    my $bare  = [{A => 1}, {A => 2}];
    my $table = attach($bare, undef);
    is(scalar @$table, 2, 'データ行のみ');
};
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 3: `detach` と `attach` を実装**

`src/TableTools.pm` の該当 stub を書き換える:

```perl
sub detach {
    my ($table) = @_;
    if (@$table && exists $table->[0]{'#'}) {
        my ($meta, @rows) = @$table;
        return ($meta, \@rows);
    }
    return (undef, $table);
}

sub attach {
    my ($table, $meta) = @_;
    return $table unless defined $meta;
    return [$meta, @$table];
}
```

- [ ] **Step 4: テストを実行して通過を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 5: コミット**

```bash
git add src/TableTools.pm test/tabletools.t
git commit -m "feat: implement detach and attach"
```

---

## Task 4: `validate`（`$cols` 省略時）

キー集合の一致検証のみ。メタデータは付加しない。

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] **Step 1: テストを追加して失敗を確認**

```perl
subtest 'validate: cols なし・正常' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    my $result = validate($table);
    is_deeply($result, $table, '入力をそのまま返す');
};

subtest 'validate: cols なし・キー不一致で die' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, C => 'y'}];
    eval { validate($table) };
    like($@, qr/column/i, 'キー不一致で die');
};
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 3: `validate`（cols なし部分）を実装**

```perl
sub validate {
    my ($table, $cols) = @_;
    my ($meta, $rows) = detach($table);
    return $table unless @$rows;

    my $base = do {
        if ($cols) {
            +{ map { $_ => 1 } @$cols };
        } else {
            +{ map { $_ => 1 } keys %{$rows->[0]} };
        }
    };

    for my $i (0 .. $#$rows) {
        my $row = $rows->[$i];
        for my $k (keys %$base) {
            die "Row $i: missing column '$k'" unless exists $row->{$k};
        }
        for my $k (keys %$row) {
            die "Row $i: unexpected column '$k'" unless exists $base->{$k};
        }
    }

    return $table unless $cols;

    my $new_attrs = _attrs($rows);
    my $new_meta  = {'#' => [map { {col => $_, attr => $new_attrs->{$_} // 'str'} } @$cols]};
    return [$new_meta, @$rows];
}
```

- [ ] **Step 4: テストを実行して通過を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 5: コミット**

```bash
git add src/TableTools.pm test/tabletools.t
git commit -m "feat: implement validate (without cols)"
```

---

## Task 5: `validate`（`$cols` あり時）

型推論してメタデータを付加したテーブルを返す。

**Files:**
- Modify: `test/tabletools.t`（実装は Task 4 で完了済み）

- [ ] **Step 1: テストを追加して失敗を確認**

```perl
subtest 'validate: cols あり・メタデータ付きで返す' => sub {
    my $rows  = [{A => 1, B => 'foo', C => 3}, {A => 2, B => 'bar', C => 4}];
    my $table = validate($rows, ['A', 'B', 'C']);

    is(scalar @$table, 3, 'meta + データ2行 = 3要素');
    ok(exists $table->[0]{'#'}, '先頭はメタデータ行');

    my $meta_cols = $table->[0]{'#'};
    is($meta_cols->[0]{col},  'A',   '1番目は A');
    is($meta_cols->[0]{attr}, 'num', 'A は num');
    is($meta_cols->[1]{col},  'B',   '2番目は B');
    is($meta_cols->[1]{attr}, 'str', 'B は str');
    is($meta_cols->[2]{col},  'C',   '3番目は C');
    is($meta_cols->[2]{attr}, 'num', 'C は num');

    is($table->[1]{A}, 1, 'データ1行目が正しい');
    is($table->[2]{A}, 2, 'データ2行目が正しい');
};

subtest 'validate: cols あり・キー不一致で die' => sub {
    my $rows = [{A => 1, B => 'x'}, {A => 2, C => 'y'}];
    eval { validate($rows, ['A', 'B']) };
    like($@, qr/column/i, 'キー不一致で die');
};
```

- [ ] **Step 2: テストを実行して通過を確認**（実装は Task 4 で完了している）

```bash
perl -I src test/tabletools.t
```

期待する出力: 全テスト PASS

- [ ] **Step 3: コミット**

```bash
git add test/tabletools.t
git commit -m "test: add validate with cols tests"
```

---

## Task 6: `group`（1段グループ化）

指定カラムでグループ化し、子行を `'@'` に格納する。

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] **Step 1: テストを追加して失敗を確認**

```perl
subtest 'group: 1段グループ化' => sub {
    my $table = [
        {A => 1, B => 'x', C => 10},
        {A => 1, B => 'y', C => 20},
        {A => 2, B => 'x', C => 30},
    ];
    my $grouped = group($table, ['A']);

    is(scalar @$grouped, 2, 'グループ数は2');
    is($grouped->[0]{A}, 1, '1グループ目は A=1');
    is(scalar @{$grouped->[0]{'@'}}, 2, 'A=1 の子は2件');
    is($grouped->[0]{'@'}[0]{B}, 'x', '子の1行目 B=x');
    is($grouped->[0]{'@'}[0]{C}, 10,  '子の1行目 C=10');
    ok(!exists $grouped->[0]{'@'}[0]{A}, '子行に A は含まれない');

    is($grouped->[1]{A}, 2, '2グループ目は A=2');
    is(scalar @{$grouped->[1]{'@'}}, 1, 'A=2 の子は1件');
};

subtest 'group: ソート順（数値）' => sub {
    my $table = [
        {A => 10, B => 'z'},
        {A => 2,  B => 'a'},
        {A => 10, B => 'b'},
    ];
    my $grouped = group($table, ['A']);
    is($grouped->[0]{A}, 2,  '数値ソートで A=2 が先');
    is($grouped->[1]{A}, 10, '次に A=10');
};

subtest 'group: メタデータを引き継ぐ' => sub {
    my $table = validate(
        [{A => 1, B => 'x'}, {A => 2, B => 'y'}],
        ['A', 'B'],
    );
    my $grouped = group($table, ['A']);
    ok(exists $grouped->[0]{'#'}, '先頭にメタデータ行がある');
};
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 3: `group` を実装（1段・多段両対応）**

```perl
sub group {
    my ($table, @cols_list) = @_;
    return $table unless @cols_list;

    my ($meta, $rows) = detach($table);
    return attach($rows, $meta) unless @$rows;

    # 型情報を取得
    my $attrs = $meta
        ? { map { $_->{col} => $_->{attr} } @{$meta->{'#'}} }
        : _attrs($rows);

    # 全グループキーを展開してソート順を決定
    my @sort_cols = map { @$_ } @cols_list;
    my @sorted = sort {
        for my $col (@sort_cols) {
            my $cmp = ($attrs->{$col} // 'str') eq 'num'
                ? (($a->{$col} // 0) <=> ($b->{$col} // 0))
                : (($a->{$col} // '') cmp ($b->{$col} // ''));
            return $cmp if $cmp;
        }
        return 0;
    } @$rows;

    # 先頭レベルでグループ化
    my $level_cols = $cols_list[0];
    my @rest       = @cols_list[1 .. $#cols_list];

    my @grouped;
    my ($current_key, $current_group);

    for my $row (@sorted) {
        my $key = join "\0", map { $row->{$_} // '' } @$level_cols;
        if (!defined $current_key || $key ne $current_key) {
            push @grouped, $current_group if defined $current_group;
            $current_key   = $key;
            $current_group = { map { $_ => $row->{$_} } @$level_cols };
            $current_group->{'@'} = [];
        }
        my %child = %$row;
        delete $child{$_} for @$level_cols;
        push @{ $current_group->{'@'} }, \%child;
    }
    push @grouped, $current_group if defined $current_group;

    # 残りのレベルで再帰的にグループ化
    if (@rest) {
        for my $parent (@grouped) {
            my $child_grouped = group($parent->{'@'}, @rest);
            my (undef, $child_rows) = detach($child_grouped);
            $parent->{'@'} = $child_rows;
        }
    }

    return attach(\@grouped, $meta);
}
```

- [ ] **Step 4: テストを実行して通過を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 5: コミット**

```bash
git add src/TableTools.pm test/tabletools.t
git commit -m "feat: implement group (single and multi-level)"
```

---

## Task 7: `group`（多段グループ化の追加テスト）

2段以上のグループ化が正しく動作するかを確認する。

**Files:**
- Modify: `test/tabletools.t`

- [ ] **Step 1: テストを追加**

```perl
subtest 'group: 2段グループ化' => sub {
    my $table = [
        {A => 1, B => 'x', C => 10},
        {A => 1, B => 'x', C => 20},
        {A => 1, B => 'y', C => 30},
        {A => 2, B => 'x', C => 40},
    ];
    my $grouped = group($table, ['A'], ['B']);

    # トップレベル: A=1, A=2
    is(scalar @$grouped, 2, 'トップレベル2グループ');
    is($grouped->[0]{A}, 1, 'A=1 が先');

    # A=1 の子: B=x, B=y
    my $a1_children = $grouped->[0]{'@'};
    is(scalar @$a1_children, 2, 'A=1 の子グループは2件');
    is($a1_children->[0]{B}, 'x', '先にB=x');
    is($a1_children->[1]{B}, 'y', '次にB=y');

    # B=x の孫: C=10, C=20
    my $bx_children = $a1_children->[0]{'@'};
    is(scalar @$bx_children, 2,  'B=x の孫は2件');
    is($bx_children->[0]{C}, 10, '孫1: C=10');
    is($bx_children->[1]{C}, 20, '孫2: C=20');

    ok(!exists $bx_children->[0]{A}, '孫行に A は含まれない');
    ok(!exists $bx_children->[0]{B}, '孫行に B は含まれない');
};
```

- [ ] **Step 2: テストを実行して通過を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 3: コミット**

```bash
git add test/tabletools.t
git commit -m "test: add multi-level group tests"
```

---

## Task 8: `expand`

グループ化されたテーブルを完全にフラット化する。

**Files:**
- Modify: `src/TableTools.pm`
- Modify: `test/tabletools.t`

- [ ] **Step 1: テストを追加して失敗を確認**

```perl
subtest 'expand: 1段グループ化を戻す' => sub {
    my $original = [
        {A => 1, B => 'x', C => 10},
        {A => 1, B => 'y', C => 20},
        {A => 2, B => 'x', C => 30},
    ];
    my $grouped  = group($original, ['A']);
    my $flat     = expand($grouped);

    is(scalar @$flat, 3, '元の行数に戻る');
    is($flat->[0]{A}, 1,   '1行目 A=1');
    is($flat->[0]{B}, 'x', '1行目 B=x');
    is($flat->[0]{C}, 10,  '1行目 C=10');
};

subtest 'expand: 2段グループ化を戻す' => sub {
    my $original = [
        {A => 1, B => 'x', C => 10},
        {A => 1, B => 'x', C => 20},
        {A => 1, B => 'y', C => 30},
        {A => 2, B => 'x', C => 40},
    ];
    my $grouped = group($original, ['A'], ['B']);
    my $flat    = expand($grouped);

    is(scalar @$flat, 4, '元の4行に戻る');
    is($flat->[0]{A}, 1,   '1行目 A=1');
    is($flat->[0]{B}, 'x', '1行目 B=x');
    is($flat->[0]{C}, 10,  '1行目 C=10');
    is($flat->[3]{A}, 2,   '4行目 A=2');
};

subtest 'expand: メタデータを引き継ぐ' => sub {
    my $table   = validate([{A => 1, B => 'x'}, {A => 2, B => 'y'}], ['A', 'B']);
    my $grouped = group($table, ['A']);
    my $flat    = expand($grouped);
    ok(exists $flat->[0]{'#'}, '先頭にメタデータ行がある');
    is($flat->[1]{A}, 1, 'データ行が続く');
};

subtest 'expand: 純粋 AoH（グループ化なし）はそのまま返る' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    my $flat  = expand($table);
    is(scalar @$flat, 2, '2行のまま');
    is($flat->[0]{A}, 1, '1行目 A=1');
};
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
perl -I src test/tabletools.t
```

- [ ] **Step 3: `expand` を実装**

```perl
sub expand {
    my ($table) = @_;
    my ($meta, $rows) = detach($table);
    my @flat = _expand_rows($rows, {});
    return attach(\@flat, $meta);
}

sub _expand_rows {
    my ($rows, $parent) = @_;
    my @result;
    for my $row (@$rows) {
        my %base = (%$parent, %$row);
        if (exists $base{'@'}) {
            my $children = delete $base{'@'};
            push @result, _expand_rows($children, \%base);
        } else {
            push @result, \%base;
        }
    }
    return @result;
}
```

- [ ] **Step 4: テストを実行して通過を確認**

```bash
perl -I src test/tabletools.t
```

期待する出力: 全テスト PASS

- [ ] **Step 5: コミット**

```bash
git add src/TableTools.pm test/tabletools.t
git commit -m "feat: implement expand"
```

---

## セルフレビュー結果

### スペックカバレッジ確認

| 仕様項目 | 対応タスク |
|----------|-----------|
| `validate`（cols なし）: キー検証のみ、純粋 AoH を返す | Task 4 |
| `validate`（cols あり）: メタデータ付き AoH を返す | Task 5 |
| `validate`: キー不一致で die | Task 4 |
| `group`: ソート（型推論で num/str 切替） | Task 6 |
| `group`: 1段グループ化 | Task 6 |
| `group`: 多段グループ化（再帰） | Task 6, 7 |
| `group`: メタデータ引き継ぎ | Task 6 |
| `expand`: 完全フラット化 | Task 8 |
| `expand`: メタデータ引き継ぎ | Task 8 |
| `detach`: メタデータ分離 | Task 3 |
| `attach`: メタデータ付加 | Task 3 |
| `_attrs`: 型推論内部関数 | Task 2 |
| メタデータなし AoH でも全関数動作 | 各タスクでカバー |
