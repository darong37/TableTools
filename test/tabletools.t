use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../src";

use_ok('TableTools');
can_ok('TableTools', qw(validate group expand detach attach));

use TableTools qw(validate detach attach);

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

done_testing;
