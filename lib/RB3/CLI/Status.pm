#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/trunk/lib/RB3/CLI/Status.pm $
# $LastChangedRevision: 11523 $
# $LastChangedDate: 2007-11-20 14:29:06 +0000 (Tue, 20 Nov 2007) $
# $LastChangedBy: ray $
#
package RB3::CLI::Status;

use strict;
use warnings FATAL => 'all';

use File::Basename qw( basename );

use RB3::Config;

sub cmd_status {
    my $class = shift;
    my $app_config = shift;

    if ( @_ ) {
        foreach ( @_ ) {
            my $hostname = basename( $_ );
            my $rb3 = RB3::Config->new( { hostname => $hostname } );
            system( 'svn', 'status', $rb3->get_system_dir );
        }
    }
    else {
        system( 'svn', 'status',  RB3::Config->BaseDir );
    }

}

1;

__END__
