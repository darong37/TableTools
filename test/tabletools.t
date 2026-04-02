use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../src";

use_ok('TableTools');
can_ok('TableTools', qw(validate group expand detach attach));

done_testing;
