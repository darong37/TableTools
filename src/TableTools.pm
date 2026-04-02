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

sub group    { }
sub expand   { }

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
