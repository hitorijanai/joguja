#!/usr/bin/perl -w
use lib '/home/affath/www/modules/';
use CGI::Carp qw( fatalsToBrowser );
use DaijoBB;

my $webapp = DaijoBB->new();
$webapp->run();

