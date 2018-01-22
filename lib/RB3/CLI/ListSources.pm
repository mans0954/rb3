#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.34/lib/RB3/CLI/ListSources.pm $
# $LastChangedRevision: 19193 $
# $LastChangedDate: 2012-01-05 12:52:33 +0000 (Thu, 05 Jan 2012) $
# $LastChangedBy: worc2070 $
#
package RB3::CLI::Build;

use strict;
use warnings FATAL => 'all';

use File::Basename qw( basename );
use File::Spec;
use IO::File;
use RB3::Config;
use RB3::File;
use RB3::FileGenerator;

sub cmd_list_sources {
    my $class = shift;
    my $app_config = shift;

    RB3::FileGenerator->DryRun( 1 )
          if $app_config->get( "dry-run" );

    RB3::FileGenerator->Quiet( 1 )
          if $app_config->quiet;

    my @files;

    foreach ( @_ ) {
        warn "Finding source files for $_\n";
        push @files, get_files_for_host( $app_config, $_ );
    }

    my %files = map { $_ => 1 } @files;
    print "$_\n" for sort keys %files;
}

sub get_files_for_host {
    my ( $app_config, $sysdir ) = @_;

    unless ( -d $sysdir ) {
        warn "Skipping $sysdir (not a directory)\n";
        return;
    }

    my $rb3 = RB3::Config->new( { system_dir => $sysdir } );

    unless ( -r $rb3->get_rb3_path ) {
        warn "Skipping $sysdir (no config.rb3)\n";
        return;
    }

    $rb3->read_config();

    my @files;

    foreach my $file ( @{ $rb3->get_file_list } ) {
        my $source = $file->get_source
            or next;
        push @files, $source;
    }

    push @files, @{ $rb3->get_rb3_file_list };
    push @files, @{ $rb3->get_params_file_list };
    return @files;
}

1;

__END__
