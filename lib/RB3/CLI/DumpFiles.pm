#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.41.2/lib/RB3/CLI/DumpFiles.pm $
# $LastChangedRevision: 16026 $
# $LastChangedDate: 2009-08-06 16:51:34 +0100 (Thu, 06 Aug 2009) $
# $LastChangedBy: tom $
#
package RB3::CLI::DumpFiles;

use strict;
use warnings FATAL => 'all';

use RB3::Config;
use File::Basename qw( basename );
use YAML;

sub cmd_dump_files {
    my $class = shift;
    my $app_config = shift;
    my $sysdir = shift;

    my $rb3 = RB3::Config->new( { system_dir => $sysdir } );
    $rb3->read_config();

    my $files = $rb3->get_file_list();

    if ( @_ ) {
        foreach my $file ( @_ ) {
            $file =~ s{^/}{};
            my $file_obj = $files->get_file( $file )
                or die "$file not under rb3 control for $sysdir\n";
            print YAML::Dump( $file_obj->as_hash );
        }
    }
    else {
        print YAML::Dump( [ map $_->as_hash, @$files ] );
    }
}

1;

__END__
