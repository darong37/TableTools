package TableTools;

use strict;
use warnings;
use parent 'Exporter';
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw(validate group expand detach attach);

sub validate { }
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
