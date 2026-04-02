use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../src";

use_ok('TableTools');
can_ok('TableTools', qw(validate group expand detach attach));

use TableTools qw(validate group detach attach);

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

done_testing;
