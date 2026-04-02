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
