use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../src";

use_ok('TableTools');
can_ok('TableTools', qw(validate group expand orderby detach attach));

use TableTools qw(validate group expand orderby detach attach);

subtest 'detach: メタデータあり' => sub {
    my $table = [
        {'#' => {attrs => {A => 'num'}}},
        {A => 1},
        {A => 2},
    ];
    my ($rows, $meta) = detach($table);
    ok(defined $meta,                                       'meta が返る');
    is_deeply($meta->{'#'}, {attrs => {A => 'num'}},       'meta の中身が正しい');
    is(scalar @$rows, 2,                                    'データ行が2件');
    is($rows->[0]{A}, 1,                                    '1行目のデータが正しい');
};

subtest 'detach: メタデータなし' => sub {
    my $table = [{A => 1}, {A => 2}];
    my ($rows, $meta) = detach($table);
    ok(!defined $meta,          'meta は undef');
    is(scalar @$rows, 2,        'データ行が2件');
};

subtest 'attach: meta あり' => sub {
    my $meta  = {'#' => {attrs => {A => 'num'}}};
    my $rows  = [{A => 1}, {A => 2}];
    my $table = attach($rows, $meta);
    is(scalar @$table, 3,               '3要素（meta + データ2行）');
    ok(exists $table->[0]{'#'},         '先頭がメタデータ行');
    is($table->[1]{A}, 1,               'データ行が続く');
};

subtest 'attach: meta が undef' => sub {
    my $rows  = [{A => 1}, {A => 2}];
    my $table = attach($rows, undef);
    is(scalar @$table, 2, 'データ行のみ');
};

subtest 'validate: cols なし・正常' => sub {
    my $rows  = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    my $table = validate($rows);

    is(scalar @$table, 3, 'meta + データ2行 = 3要素');
    ok(exists $table->[0]{'#'},           '先頭はメタデータ行');
    ok(exists $table->[0]{'#'}{attrs},    'attrs が存在する');
    ok(!exists $table->[0]{'#'}{order},   'order は存在しない');
    is($table->[0]{'#'}{attrs}{A}, 'num', 'A は num');
    is($table->[0]{'#'}{attrs}{B}, 'str', 'B は str');
    is($table->[1]{A}, 1,                 'データ1行目が正しい');
};

subtest 'validate: cols なし・空テーブル' => sub {
    my $result = validate([]);
    is_deeply($result, [], '空テーブルは [] をそのまま返す');
};

subtest 'validate: cols なし・キー不一致で die' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, C => 'y'}];
    eval { validate($table) };
    like($@, qr/column/i, 'キー不一致で die');
};

subtest 'validate: cols なし・既存 order を保持' => sub {
    my $table = validate([{A => 1, B => 'x'}, {A => 2, B => 'y'}], ['A', 'B']);
    my $result = validate($table);
    ok(exists $result->[0]{'#'}{order},              'order が保持されている');
    is_deeply($result->[0]{'#'}{order}, ['A', 'B'],  'order の内容が正しい');
};


subtest 'validate: cols あり・メタデータ付きで返す' => sub {
    my $rows  = [{A => 1, B => 'foo', C => 3}, {A => 2, B => 'bar', C => 4}];
    my $table = validate($rows, ['A', 'B', 'C']);

    is(scalar @$table, 3, 'meta + データ2行 = 3要素');
    ok(exists $table->[0]{'#'}, '先頭はメタデータ行');

    my $meta = $table->[0]{'#'};
    is_deeply($meta->{order}, ['A', 'B', 'C'], 'order が正しい');
    is($meta->{attrs}{A}, 'num', 'A は num');
    is($meta->{attrs}{B}, 'str', 'B は str');
    is($meta->{attrs}{C}, 'num', 'C は num');

    is($table->[1]{A}, 1, 'データ1行目が正しい');
    is($table->[2]{A}, 2, 'データ2行目が正しい');
};

subtest 'validate: cols あり・空テーブル' => sub {
    my $result = validate([], ['A', 'B']);
    is_deeply($result, [], '空テーブルは [] をそのまま返す');
};

subtest 'validate: cols あり・キー不一致で die' => sub {
    my $rows = [{A => 1, B => 'x'}, {A => 2, C => 'y'}];
    eval { validate($rows, ['A', 'B']) };
    like($@, qr/column/i, 'キー不一致で die');
};

subtest 'validate: cols あり・既存 attrs との集合不一致で die' => sub {
    my $table = validate([{A => 1, B => 'x'}, {A => 2, B => 'y'}], ['A', 'B']);
    eval { validate($table, ['A', 'C']) };
    like($@, qr/column/i, '$cols と既存 attrs の集合不一致で die');
};

subtest 'validate: cols あり・既存 order と異なる順序で order が上書きされる' => sub {
    my $table  = validate([{A => 1, B => 'x'}, {A => 2, B => 'y'}], ['A', 'B']);
    my $result = validate($table, ['B', 'A']);
    is_deeply($result->[0]{'#'}{order}, ['B', 'A'], '$cols の順序で order が上書きされる');
};

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

subtest 'group: 1段グループ化' => sub {
    my $table = validate(
        [{A => 1, B => 'x', C => 10}, {A => 1, B => 'y', C => 20}, {A => 2, B => 'x', C => 30}],
        ['A', 'B', 'C'],
    );
    my $grouped = group($table, ['A']);

    is(scalar @$grouped, 3, 'meta + グループ2件 = 3要素');
    ok(exists $grouped->[0]{'#'}, '先頭はメタデータ行');
    is($grouped->[1]{A}, 1, '1グループ目は A=1');
    is(scalar @{$grouped->[1]{'@'}}, 2, 'A=1 の子は2件');
    is($grouped->[1]{'@'}[0]{B}, 'x', '子の1行目 B=x');
    is($grouped->[1]{'@'}[0]{C}, 10,  '子の1行目 C=10');
    ok(!exists $grouped->[1]{'@'}[0]{A}, '子行に A は含まれない');

    is($grouped->[2]{A}, 2, '2グループ目は A=2');
    is(scalar @{$grouped->[2]{'@'}}, 1, 'A=2 の子は1件');
};

subtest 'group: ソート済み入力で正常動作' => sub {
    my $table = validate(
        [{A => 2, B => 'a'}, {A => 10, B => 'b'}, {A => 10, B => 'z'}],
        ['A', 'B'],
    );
    my $grouped = group($table, ['A']);
    is($grouped->[1]{A}, 2,  'A=2 が先');
    is($grouped->[2]{A}, 10, '次に A=10');
    is(scalar @{ $grouped->[2]{'@'} }, 2, 'A=10 の子は2件');
};

subtest 'group: 順序違反で die' => sub {
    my $table = validate(
        [{A => 1, B => 'x'}, {A => 2, B => 'y'}, {A => 1, B => 'z'}],
        ['A', 'B'],
    );
    eval { group($table, ['A']) };
    like($@, qr/out of order/, '順序違反で die する');
};

subtest 'group: メタデータを引き継ぐ' => sub {
    my $table = validate(
        [{A => 1, B => 'x'}, {A => 2, B => 'y'}],
        ['A', 'B'],
    );
    my $grouped = group($table, ['A']);
    ok(exists $grouped->[0]{'#'},                    '先頭にメタデータ行がある');
    ok(exists $grouped->[0]{'#'}{order},             'order が引き継がれている');
    is_deeply($grouped->[0]{'#'}{order}, ['A', 'B'], 'order の内容が正しい');
    is($grouped->[0]{'#'}{attrs}{A}, 'num',          'attrs A が引き継がれている');
    is($grouped->[0]{'#'}{attrs}{B}, 'str',          'attrs B が引き継がれている');
};

subtest 'group: 2段グループ化' => sub {
    my $table = validate(
        [{A => 1, B => 'x', C => 10}, {A => 1, B => 'x', C => 20},
         {A => 1, B => 'y', C => 30}, {A => 2, B => 'x', C => 40}],
        ['A', 'B', 'C'],
    );
    my $grouped = group($table, ['A'], ['B']);

    is(scalar @$grouped, 3, 'meta + トップレベル2グループ = 3要素');
    is($grouped->[1]{A}, 1, 'A=1 が先');

    my $a1_children = $grouped->[1]{'@'};
    is(scalar @$a1_children, 2, 'A=1 の子グループは2件');
    is($a1_children->[0]{B}, 'x', '先にB=x');
    is($a1_children->[1]{B}, 'y', '次にB=y');

    my $bx_children = $a1_children->[0]{'@'};
    is(scalar @$bx_children, 2,  'B=x の孫は2件');
    is($bx_children->[0]{C}, 10, '孫1: C=10');
    is($bx_children->[1]{C}, 20, '孫2: C=20');

    ok(!exists $bx_children->[0]{A}, '孫行に A は含まれない');
    ok(!exists $bx_children->[0]{B}, '孫行に B は含まれない');
};

subtest 'group: 存在しないカラム指定で die' => sub {
    my $table = validate([{A => 1}, {A => 2}], ['A']);
    eval { group($table, ['B']) };
    like($@, qr/column/i, '未存在カラム指定で die');
};

subtest 'group: バリデートなしの AoH で die' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    eval { group($table, ['A']) };
    like($@, qr/validate/i, 'バリデートなしで die');
};

subtest 'orderby: 数値カラムによるソート' => sub {
    my $table  = validate([{A => 10, B => 'z'}, {A => 2, B => 'a'}, {A => 5, B => 'm'}], ['A', 'B']);
    my $sorted = orderby($table, 'A');
    is($sorted->[1]{A}, 2,  '1行目 A=2');
    is($sorted->[2]{A}, 5,  '2行目 A=5');
    is($sorted->[3]{A}, 10, '3行目 A=10');
};

subtest 'orderby: 文字列カラムによるソート' => sub {
    my $table  = validate([{A => 1, B => 'z'}, {A => 2, B => 'a'}, {A => 3, B => 'm'}], ['A', 'B']);
    my $sorted = orderby($table, 'B');
    is($sorted->[1]{B}, 'a', '1行目 B=a');
    is($sorted->[2]{B}, 'm', '2行目 B=m');
    is($sorted->[3]{B}, 'z', '3行目 B=z');
};

subtest 'orderby: 複数カラムによる優先順位ソート' => sub {
    my $table  = validate(
        [{A => 1, B => 'z'}, {A => 2, B => 'a'}, {A => 1, B => 'a'}],
        ['A', 'B'],
    );
    my $sorted = orderby($table, 'A', 'B');
    is($sorted->[1]{A}, 1,   '1行目 A=1');
    is($sorted->[1]{B}, 'a', '1行目 B=a');
    is($sorted->[2]{A}, 1,   '2行目 A=1');
    is($sorted->[2]{B}, 'z', '2行目 B=z');
    is($sorted->[3]{A}, 2,   '3行目 A=2');
};

subtest 'orderby: メタデータを引き継ぐ' => sub {
    my $table  = validate([{A => 2, B => 'x'}, {A => 1, B => 'y'}], ['A', 'B']);
    my $sorted = orderby($table, 'A');
    ok(exists $sorted->[0]{'#'},                    '先頭にメタデータ行がある');
    ok(exists $sorted->[0]{'#'}{order},             'order が引き継がれている');
    is_deeply($sorted->[0]{'#'}{order}, ['A', 'B'], 'order の内容が正しい');
    is($sorted->[0]{'#'}{attrs}{A}, 'num',          'attrs A が引き継がれている');
    is($sorted->[0]{'#'}{attrs}{B}, 'str',          'attrs B が引き継がれている');
};

subtest 'orderby: バリデートなしの AoH で die' => sub {
    my $table = [{A => 2, B => 'x'}, {A => 1, B => 'y'}];
    eval { orderby($table, 'A') };
    like($@, qr/validate/i, 'バリデートなしで die');
};

subtest 'orderby: 存在しないカラム指定で die' => sub {
    my $table = validate([{A => 1}, {A => 2}], ['A']);
    eval { orderby($table, 'B') };
    like($@, qr/column/i, '未存在カラム指定で die');
};

subtest 'expand: 1段グループ化を戻す' => sub {
    my $original = validate(
        [{A => 1, B => 'x', C => 10}, {A => 1, B => 'y', C => 20}, {A => 2, B => 'x', C => 30}],
        ['A', 'B', 'C'],
    );
    my $grouped  = group($original, ['A']);
    my $flat     = expand($grouped);

    is(scalar @$flat, 4, 'meta + 元の3行 = 4要素');
    ok(exists $flat->[0]{'#'}, '先頭はメタデータ行');
    is($flat->[1]{A}, 1,   '1行目 A=1');
    is($flat->[1]{B}, 'x', '1行目 B=x');
    is($flat->[1]{C}, 10,  '1行目 C=10');
};

subtest 'expand: 2段グループ化を戻す' => sub {
    my $original = validate(
        [{A => 1, B => 'x', C => 10}, {A => 1, B => 'x', C => 20},
         {A => 1, B => 'y', C => 30}, {A => 2, B => 'x', C => 40}],
        ['A', 'B', 'C'],
    );
    my $grouped = group($original, ['A'], ['B']);
    my $flat    = expand($grouped);

    is(scalar @$flat, 5, 'meta + 元の4行 = 5要素');
    ok(exists $flat->[0]{'#'}, '先頭はメタデータ行');
    is($flat->[1]{A}, 1,   '1行目 A=1');
    is($flat->[1]{B}, 'x', '1行目 B=x');
    is($flat->[1]{C}, 10,  '1行目 C=10');
    is($flat->[4]{A}, 2,   '4行目 A=2');
};

subtest 'expand: メタデータを引き継ぐ' => sub {
    my $table   = validate([{A => 1, B => 'x'}, {A => 2, B => 'y'}], ['A', 'B']);
    my $grouped = group($table, ['A']);
    my $flat    = expand($grouped);
    ok(exists $flat->[0]{'#'},                   '先頭にメタデータ行がある');
    ok(exists $flat->[0]{'#'}{order},            'order が引き継がれている');
    is_deeply($flat->[0]{'#'}{order}, ['A', 'B'], 'order の内容が正しい');
    is($flat->[0]{'#'}{attrs}{A}, 'num',         'attrs A が引き継がれている');
    is($flat->[0]{'#'}{attrs}{B}, 'str',         'attrs B が引き継がれている');
    is($flat->[1]{A}, 1, 'データ行が続く');
};

subtest 'expand: バリデートなしの AoH で die' => sub {
    my $table = [{A => 1, B => 'x'}, {A => 2, B => 'y'}];
    eval { expand($table) };
    like($@, qr/validate/i, 'バリデートなしで die');
};

done_testing;
