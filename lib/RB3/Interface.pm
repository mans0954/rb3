#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/trunk/lib/RB3/TemplateFunctions.pm $
# $LastChangedRevision: 26289 $
# $LastChangedDate: 2015-05-13 16:58:10 +0100 (Wed, 13 May 2015) $
# $LastChangedBy: ouit0139 $
#
package RB3::Interface;

=head1 NAME

RB3::Interface - function used to find interfaces in network configs

=head1 DESCRIPTION

The following subroutine is used by the CLI and the template functions

=cut

use strict;
use warnings FATAL => 'all';
use feature 'state';

use File::Spec;
use IO::File;
use Regexp::Common qw( net );
use Socket 'inet_ntoa';

sub parse_interfaces {
    my $hostname = shift;
    my $sys_dir = shift;

    my @addrs = gethostbyname( $hostname )
        or die "gethostbyname $hostname failed\n";

    splice( @addrs, 0, 4 );

    my %wanted = map { inet_ntoa( $_ ) => 1 } @addrs;

    my @hosts;

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
                    push(@hosts, $system);
                    last;
                }
            }
        }
    }
    
    return @hosts;
}

1;

__END__
