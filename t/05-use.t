#!/usr/bin/perl
#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.34/t/05-use.t $
# $LastChangedRevision: 11523 $
# $LastChangedDate: 2007-11-20 14:29:06 +0000 (Tue, 20 Nov 2007) $
# $LastChangedBy: ray $
#

use strict;
use warnings FATAL => 'all';

use Test::More;
use File::Find;
use IO::File;

my @MODULES;

find ( sub {
           -d $_ and $_ eq '.svn' and $File::Find::prune = 1 and return;
           if ( -f $_ and $_ =~ /\.pm$/ ) {
               my $fh = IO::File->new( $_ ) or die $!;
               while ( <$fh> ) {
                   /^package (.*);/ and push @MODULES, $1 and last;
               }
           }
       }, 'lib/' );

plan tests => scalar @MODULES;

use_ok( $_ ) for @MODULES;
