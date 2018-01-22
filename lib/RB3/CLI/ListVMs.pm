#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.42/lib/RB3/CLI/ListVMs.pm $
# $LastChangedRevision: 26458 $
# $LastChangedDate: 2015-06-15 12:03:59 +0100 (Mon, 15 Jun 2015) $
# $LastChangedBy: oucs0146 $
#
package RB3::CLI::ListVMs;

use strict;
use warnings FATAL => 'all';

use RB3::Config;
use File::Spec;
use File::Basename;
use YAML;
use Readonly;

sub cmd_list_vms {
    my $class = shift;
    my $app_config = shift;
    my $sysdir = shift;

    Readonly my $vm_config => File::Spec->catdir(
        $app_config->basedir,
        'defaults/virt/virtual_machines.yml'
    );
    Readonly my $vms => YAML::LoadFile($vm_config)->{vms};

    my $rb3 = RB3::Config->new( { system_dir => $sysdir } );
    $rb3->read_config();

    my $files = $rb3->get_file_list();
    my @domus;

    foreach my $file ( map $_->as_hash, @$files ) {
        if ( $file->{dest} =~ /etc\/xen\/domains\/normal\// ) {
            push(@domus, basename($file->{dest}));
        }
    }

    foreach my $domu (
        sort {
            ($a =~ /vm(\d+)/)[0] <=> ($b =~ /vm(\d+)/)[0]
        } @domus
    ) {
        if ( $vms->{$domu} ) {
            print "$domu: $vms->{$domu}->{hostname}" .
                " ($vms->{$domu}->{description})\n";
        }
        else {
            print "ERROR: $domu is not defined in rb3 defaults\n";
        }
    }
}

1;

__END__
