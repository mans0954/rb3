#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.42/lib/RB3/CLI/FindIface.pm $
# $LastChangedRevision: 26315 $
# $LastChangedDate: 2015-05-19 10:56:18 +0100 (Tue, 19 May 2015) $
# $LastChangedBy: ouit0139 $
#
package RB3::CLI::FindIface;

use strict;
use warnings FATAL => 'all';

use File::Spec;

use RB3::Interface;

sub cmd_find_iface {
    my $class = shift;
    my $app_config = shift;

    my $hostname = shift @ARGV
        or die "hostname not specified";

    my $sys_dir = File::Spec->catdir( $app_config->basedir, 'systems' );

    foreach my $host (RB3::Interface::parse_interfaces($hostname, $sys_dir)) {
	print "$host\n";
    }

}

1;

__END__
