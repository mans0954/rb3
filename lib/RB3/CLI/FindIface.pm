#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.37/lib/RB3/CLI/FindIface.pm $
# $LastChangedRevision: 19495 $
# $LastChangedDate: 2012-03-22 14:26:20 +0000 (Thu, 22 Mar 2012) $
# $LastChangedBy: worc2070 $
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
            my $addr;
            if ( ( $addr ) = $_ =~ /^\s+address\s+$RE{net}{IPv4}{-keep}\s*$/
                    or  ( $addr ) = $_ =~ /^\s+(?:pre-|post-)?up\s+ip\s+addr\s+add\s+$RE{net}{IPv4}{-keep}\/\d+/ ) {
                # Also cope with 'up ip addr add $ip/$mask...' syntax
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
