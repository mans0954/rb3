#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.28/lib/RB3/FileGenerator.pm $
# $LastChangedRevision: 16972 $
# $LastChangedDate: 2010-02-12 12:28:25 +0000 (Fri, 12 Feb 2010) $
# $LastChangedBy: tom $
#
package RB3::FileGenerator;

use strict;
use warnings FATAL => 'all';

use base 'Class::Data::Inheritable';

__PACKAGE__->mk_classdata( DryRun  => 0     );
__PACKAGE__->mk_classdata( Quiet   => 0     );
__PACKAGE__->mk_classdata( Silent  => 0     );
__PACKAGE__->InitVMethods();

use Class::Std;
use File::Basename qw( dirname );
use File::Path qw( mkpath );
use File::Temp;
use IO::File;
use RB3::TemplateFunctions;
use Template;
use Template::Stash;

sub InitVMethods {
    my $class = shift;

    Template::Stash->define_vmethod( 'scalar', 'lc', sub { lc $_[0] } );
    Template::Stash->define_vmethod( 'list', 'contains', \&RB3::TemplateFunctions::contains );
    Template::Stash->define_vmethod( 'list', 'fieldsort', \&RB3::TemplateFunctions::fieldsort );
}

{
    my $tt;

    sub Template {
        unless ( $tt ) {
            $tt = Template->new( { INCLUDE_PATH => '.' } );
        }
        return $tt;
    }
}

{

    my %params_of     :ATTR( :init_arg<params>     :get<params> );
    my %system_dir_of :ATTR( :init_arg<system_dir> :get<system_dir> );

    sub generate {
        my ( $self, $source, $dest, $ctmeta_path, $file_params, $component ) = @_;

        my $dest_path = File::Spec->catfile( $self->get_system_dir, $component, $dest );
        my $dest_dir = dirname( $dest_path );
#        my $dest_relpath = File::Spec->abs2rel( $dest_path, "." );

        warn "Generating $dest_path\n      from $source\n"
            unless $self->Quiet;

        return
            if $self->DryRun;

        mkpath( $dest_dir, 1, 0755 );

        my $tmp = File::Temp->new( DIR => $dest_dir, UNLINK => 1 );

        my $ifh = IO::File->new( $source, O_RDONLY )
            or die "Error opening $source for reading: $!";

        if ( $source =~ /\.tt$/ ) {
            my $params = $self->get_params->merge( $file_params )->template_vars;

            my $packvars = { tmpl_source => $source, tmpl_dest => $ctmeta_path };

            my $tt = $self->Template();
            $self->Template->process( $ifh, { params => $params, packvars => $packvars, %RB3::TemplateFunctions::functions }, $tmp )
                or die $self->Template->error() . "\n";
        }
        else {
            while ( <$ifh> ) {
                $tmp->print( $_ )
                    or die "Error writing to " . $tmp->filename . ": $!";
            }
        }
        $ifh->close();
        $tmp->close();

        rename( $tmp->filename, $dest_path )
            or die "Error renaming " . $tmp->filename . " to $dest_path: $!";
    }
}

1;

__END__
