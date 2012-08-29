#!/usr/bin/perl -w

use lib '/home/affath/www/modules/'; #change the path to the actual full path of module location
use DaijoBB;

my $webapp = DaijoBB->new();
$webapp->run();

