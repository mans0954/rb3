#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/trunk/lib/RB3/CLI/DumpParams.pm $
# $LastChangedRevision: 16026 $
# $LastChangedDate: 2009-08-06 16:51:34 +0100 (Thu, 06 Aug 2009) $
# $LastChangedBy: tom $
#
package RB3::CLI::DumpParams;

use strict;
use warnings FATAL => 'all';

use File::Basename qw( basename );
use RB3::Config;
use YAML;

sub cmd_dump_params {
    my $class = shift;
    my $app_config = shift;
    my $sysdir = shift;

    my $rb3 = RB3::Config->new( { system_dir => $sysdir } );
    $rb3->read_config();
    print YAML::Dump( { map { $_->get_name => $_->as_hash } @{ $rb3->get_parameter_list } } );
}

1;

__END__
