package TableTools;

use strict;
use warnings;
use parent 'Exporter';
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw(validate group expand orderby detach attach);

sub _check_cols {
    my ($attrs, @cols) = @_;
    for my $col (@cols) {
        die "unknown column '$col'" unless exists $attrs->{$col};
    }
}

sub _resolve_meta {
    my ($table, $cols) = @_;
    my $called_validate = @_ == 2;
    my ($rows, $meta)   = detach($table);
    $meta //= {'#' => {}};

    my $attrs = $meta->{'#'}{attrs};
    my $order = $meta->{'#'}{order};

    if (!$attrs) {
        if ($called_validate) {
            my @keys = $cols ? @$cols : @$rows ? keys %{$rows->[0]} : ();
            $attrs = { map { $_ => 'unknown' } @keys };  # initial state: not yet determined
        } else {
            die "attrs not found. Call validate first";
        }
    }

    if ($cols) {
        die "cols count mismatch" unless @$cols == scalar keys %$attrs;
        _check_cols($attrs, @$cols);
        $order = [@$cols];
    }

    my $new_meta = {'#' => {attrs => $attrs}};
    $new_meta->{'#'}{order} = $order if $order;

    return ($rows, $new_meta, $attrs, $order);
}

sub validate {
    my ($table, $cols) = @_;
    my ($rows, $meta, $attrs, $order) = _resolve_meta($table, $cols);
    return [] unless @$rows;

    my $col_count = scalar keys %$attrs;

    for my $i (0 .. $#$rows) {
        my $row      = $rows->[$i];
        my @row_keys = keys %$row;
        die "Row $i: column count mismatch" unless @row_keys == $col_count;
        for my $k (@row_keys) {
            die "Row $i: unexpected column '$k'" unless defined $attrs->{$k};
            die "Row $i: column '$k' value is undef" unless defined $row->{$k};
            my $is_str = !looks_like_number($row->{$k});
            if ($attrs->{$k} eq 'unknown') {
                $attrs->{$k} = $is_str ? 'str' : 'num?';
            } elsif ($attrs->{$k} eq 'num?') {
                $attrs->{$k} = 'str' if $is_str;
            } elsif ($attrs->{$k} eq 'num' && $is_str) {
                die "Row $i: column '$k' is num but got non-numeric value";
            }
            # 'str': no change
        }
    }

    # finalize num? to num
    for my $k (keys %$attrs) {
        $attrs->{$k} = 'num' if $attrs->{$k} eq 'num?';
    }

    return attach($rows, $meta);
}

sub group {
    my ($table, @cols_list) = @_;
    return $table unless @cols_list;

    my ($rows, $meta, $attrs, $order) = _resolve_meta($table);

    return attach($rows, $meta) unless @$rows;

    _check_cols($attrs, map { @$_ } @cols_list);

    my $grouped = _group_rows($rows, $attrs, @cols_list);
    return attach($grouped, $meta);
}

sub orderby {
    my ($table, @cols) = @_;
    return $table unless @cols;

    my ($rows, $meta, $attrs, $order) = _resolve_meta($table);

    _check_cols($attrs, @cols);

    my @sorted = sort {
        for my $col (@cols) {
            my $cmp = $attrs->{$col} eq 'num'
                ? (($a->{$col} // 0) <=> ($b->{$col} // 0))
                : (($a->{$col} // '') cmp ($b->{$col} // ''));
            return $cmp if $cmp;
        }
        return 0;
    } @$rows;

    return attach(\@sorted, $meta);
}

sub _group_rows {
    my ($rows, $attrs, @cols_list) = @_;

    my $level_cols = $cols_list[0];
    my @rest       = @cols_list[1 .. $#cols_list];

    my @grouped;
    my ($current_key, $current_group);
    my %seen_keys;

    for my $row (@$rows) {
        my $key = join "\0", map { $row->{$_} // '' } @$level_cols;
        if (!defined $current_key || $key ne $current_key) {
            if (defined $current_group) {
                push @grouped, $current_group;
                $seen_keys{$current_key} = 1;
            }
            die "out of order: key reappeared\n" if $seen_keys{$key};
            $current_key   = $key;
            $current_group = { map { $_ => $row->{$_} } @$level_cols };
            $current_group->{'@'} = [];
        }
        my %child = %$row;
        delete $child{$_} for @$level_cols;
        push @{ $current_group->{'@'} }, \%child;
    }
    push @grouped, $current_group if defined $current_group;

    if (@rest) {
        for my $parent (@grouped) {
            $parent->{'@'} = _group_rows($parent->{'@'}, $attrs, @rest);
        }
    }

    return \@grouped;
}

sub expand {
    my ($table) = @_;
    my ($rows, $meta, $attrs, $order) = _resolve_meta($table);

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
        return (\@rows, $meta);
    }
    return ($table, undef);
}

sub attach {
    my ($table, $meta) = @_;
    return $table unless defined $meta;
    return [$meta, @$table];
}

1;
