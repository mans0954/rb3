#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.37/lib/RB3/CLI/FindInstalled.pm $
# $LastChangedRevision: 11642 $
# $LastChangedDate: 2007-11-29 13:40:39 +0000 (Thu, 29 Nov 2007) $
# $LastChangedBy: ray $
#
package RB3::CLI::FindInstalled;

use strict;
use warnings FATAL => 'all';

use File::Spec;
use RB3::Desc;
use Readonly;

Readonly my @SSH_CMD     => qw( ssh -oConnectTimeout=5 -oBatchMode=yes );
Readonly my $GREP_STATUS => "grep-status -FStatus -r ^install -a -FPackage,Source -X %s -sPackage,Version";

sub cmd_find_installed {
    my $class = shift;
    my $app_config = shift;

    my $package = shift @ARGV
        or die "package not specified";

    if ( @ARGV ) {
        foreach ( @ARGV ) {
            check_installed( $app_config, $package, $_ );
        }
    }
    else {
        my $sys_dir = File::Spec->catdir( $app_config->basedir, 'systems' );
        foreach my $desc_path ( glob( "$sys_dir/*/desc.yml" ) ) {
            my $desc = RB3::Desc->new( YAML::LoadFile( $desc_path ) );
            next unless $desc->is_active
                and $desc->is_autoupdate;
            check_installed( $app_config, $package, $desc->get_hostname );
        }
    }
}

sub check_installed {
    my ( $app_config, $package, $hostname ) = @_;

    my @cmd = ( @SSH_CMD, $hostname, sprintf( $GREP_STATUS, $package ) );

    warn "Checking for $package on $hostname\n"
        unless $app_config->quiet;

    eval {
        local $/ = "";
        open( my $remote_grep_status, '-|', @cmd )
            or die "failed to run @cmd\n";
        while ( <$remote_grep_status> ) {
            my ( $pkg, $ver ) = $_ =~ /^Package:\s(\S+)\n^Version:\s(\S+)/m
                or die "failed to parse dpkg-status output";
            print "$hostname $pkg $ver\n";
        }
        close( $remote_grep_status );
        my $rc = $? >> 8;
        die "Remote command exited $rc\n"
            if $rc != 0 and $rc != 1;

    };
    if ( $@ ) {
        warn "Failed to run grep-status on $hostname: $@\n";
    }
}

1;

__END__
