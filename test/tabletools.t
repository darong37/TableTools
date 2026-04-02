use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../src";

use_ok('TableTools');
can_ok('TableTools', qw(validate group expand detach attach));

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

done_testing;
