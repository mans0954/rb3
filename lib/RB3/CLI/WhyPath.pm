#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.34/lib/RB3/CLI/WhyPath.pm $
# $LastChangedRevision: 17648 $
# $LastChangedDate: 2010-10-05 23:12:33 +0100 (Tue, 05 Oct 2010) $
# $LastChangedBy: tom $
#
package RB3::CLI::WhyPath;

use strict;
use warnings FATAL => 'all';

use RB3::Config;
use File::Basename qw( basename );
use YAML;

sub cmd_why_path {
    my $class = shift;
    my $app_config = shift;
    my $sysdir = shift;

    my $rb3 = RB3::Config->new( { system_dir => $sysdir } );
    $rb3->read_config;

    foreach my $file ( @_ ) {

        my @rb3stack = $rb3->why_path($file);

        for my $item (@rb3stack) {
            print "$item\n";
        }
    }
}

1;

__END__
