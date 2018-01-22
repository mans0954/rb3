#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.26/lib/RB3/CLI/FindIface.pm $
# $LastChangedRevision: 11543 $
# $LastChangedDate: 2007-11-22 09:58:42 +0000 (Thu, 22 Nov 2007) $
# $LastChangedBy: ray $
#
package RB3::CLI::FindIface;

use strict;
use warnings FATAL => 'all';

use File::Spec;
use IO::File;
use Regexp::Common qw( net );
use Socket 'inet_ntoa';

sub cmd_find_iface {
    my $class = shift;
    my $app_config = shift;

    my $hostname = shift @ARGV
        or die "hostname not specified";

    my @addrs = gethostbyname( $hostname )
        or die "gethostbyname $hostname failed\n";

    splice( @addrs, 0, 4 );

    my %wanted = map { inet_ntoa( $_ ) => 1 } @addrs;

    my $sys_dir = File::Spec->catdir( $app_config->basedir, 'systems' );

    foreach my $path ( glob( "$sys_dir/*/root/etc/network/interfaces" ) ) {
        my $fh = IO::File->new( $path, O_RDONLY )
            or die "open $path: $!";
        while ( <$fh> ) {
            if ( ( my $addr ) = $_ =~ /^\s+address\s+$RE{net}{IPv4}{-keep}\s*$/ ) {
                if ( $wanted{ $addr } ) {
                    ( my $system ) = $path =~ m{^\Q$sys_dir\E/$RE{net}{domain}{-keep}/};
                    print "$system\n";
                    last;
                }
            }
        }
    }
}

1;

__END__
