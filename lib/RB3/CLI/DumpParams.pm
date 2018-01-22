#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.41.2/lib/RB3/CLI/DumpParams.pm $
# $LastChangedRevision: 21960 $
# $LastChangedDate: 2013-09-18 15:44:08 +0100 (Wed, 18 Sep 2013) $
# $LastChangedBy: worc2070 $
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
    binmode STDOUT, ':utf8';
    print YAML::Dump( { map { $_->get_name => $_->as_hash } @{ $rb3->get_parameter_list } } );
}

1;

__END__
