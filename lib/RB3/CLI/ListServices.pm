#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.37/lib/RB3/CLI/ListServices.pm $
# $LastChangedRevision: 21931 $
# $LastChangedDate: 2013-09-17 11:40:44 +0100 (Tue, 17 Sep 2013) $
# $LastChangedBy: dom $
#
package RB3::CLI::ListServices;

use strict;
use warnings FATAL => 'all';

use File::Spec;
use IO::File;
use Regexp::Common qw( net );
use Socket;

sub cmd_list_services {
    my $class = shift;
    my $app_config = shift;
    
    my $sys_dir = shift @ARGV
        or die "System directory not specified\n";

    my @path_sections = $app_config->basedir;

    unless( $sys_dir =~ m{^/?systems/} ){
        push @path_sections, "systems";
    }

    push @path_sections, $sys_dir, "root/etc/network/interfaces";
    
    my $int_file = File::Spec->catdir(
        @path_sections
    );
    
    my $fh = IO::File->new( $int_file, O_RDONLY )
        or die "open $int_file: $!";
    
    while ( <$fh> ) {
        my $addr;
        if ( ( $addr ) = $_ =~ /^\s+address\s+$RE{net}{IPv4}{-keep}\s*$/
            or ( $addr ) = $_ =~ /^\s+(?:pre-|post-)?up\s+ip\s+addr\s+add\s+$RE{net}{IPv4}{-keep}\/\d+/ ) {
            # Also cope with 'up ip addr add $ip/$mask...' syntax
            my $name = gethostbyaddr( inet_aton( $addr ), AF_INET )
                or die "failed to resolve $addr: $!";
            print "$name\n";
        }
    }
}

1;

__END__
