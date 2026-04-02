package TableTools;

use strict;
use warnings;
use parent 'Exporter';
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw(validate group expand detach attach);

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

1;
