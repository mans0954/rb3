#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.40/lib/RB3/CLI/Update.pm $
# $LastChangedRevision: 14469 $
# $LastChangedDate: 2008-09-15 15:04:36 +0100 (Mon, 15 Sep 2008) $
# $LastChangedBy: ray $
#
package RB3::CLI::Update;

use strict;
use warnings FATAL => 'all';

use File::Basename qw( basename );
use Term::Query qw( query );
use Text::ParseWords qw( quotewords );

sub run_remote_configtool {
    my ( $app_config, @systems ) = @_;
    my $cmd_str = $app_config->configtool_cmd
        or die "configtool_cmd not specified\n";
    my @cmd = quotewords( qr/\s+/, 0, $cmd_str );
    exec( @cmd, @systems );
}

sub run_cfgdist_update {
    my ( $cfgdist_server, @legacy_clients ) = @_;
    return unless @legacy_clients;
    die "cfgdist_server not specified: legacy clients will not be updated\n"
        unless defined $cfgdist_server;
    foreach my $c ( @legacy_clients ) {
        print "Updating rsync repository for $c\n";
        system( 'ssh', $cfgdist_server, 'cfgdist-update', $c ) == 0
            or die "Failed to update rsync server\n";
    }
}

sub cmd_update {
    my $class = shift;
    my $app_config = shift;

    my $cfgdist_server = $app_config->cfgdist_server;
    my %legacy_clients = map { $_ => 1 } @{ $app_config->legacy_client };

    if ( @_ ) {
        my @systems = map basename( $_ ), @_;
        run_cfgdist_update( $cfgdist_server, grep $legacy_clients{ $_ }, @systems );
        run_remote_configtool( $app_config, @systems )
            if query( "Update remote systems?", "N" ) eq 'yes';
    }
    else {
        run_cfgdist_update( $cfgdist_server, keys %legacy_clients );
    }
}

1;

__END__
