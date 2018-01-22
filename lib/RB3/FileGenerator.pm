#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/trunk/lib/RB3/FileGenerator.pm $
# $LastChangedRevision: 15812 $
# $LastChangedDate: 2009-07-06 11:49:15 +0100 (Mon, 06 Jul 2009) $
# $LastChangedBy: tom $
#
package RB3::FileGenerator;

use strict;
use warnings FATAL => 'all';

use base 'Class::Data::Inheritable';

__PACKAGE__->mk_classdata( BaseDir => undef );
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
    $class->DisableShuffle();
    Template::Stash->define_vmethod( 'scalar', 'lc', sub { lc $_[0] } );
    Template::Stash->define_vmethod( 'list', 'contains', \&RB3::TemplateFunctions::contains );
    Template::Stash->define_vmethod( 'list', 'fieldsort', \&RB3::TemplateFunctions::fieldsort );
}

sub EnableShuffle {
    Template::Stash->define_vmethod( 'list', 'shuffle', \&RB3::TemplateFunctions::shuffle );
}

sub DisableShuffle {
    Template::Stash::->define_vmethod( 'list', 'shuffle', \&RB3::TemplateFunctions::die_shuffle );
}

{
    my $tt;

    sub Template {
        unless ( $tt ) {
            $tt = Template->new( { INCLUDE_PATH => __PACKAGE__->BaseDir } );
        }
        return $tt;
    }
}

{

    my %params_of     :ATTR( :init_arg<params>     :get<params> );
    my %system_dir_of :ATTR( :init_arg<system_dir> :get<system_dir> );

    sub generate {
        my ( $self, $source, $dest, $file_params ) = @_;

        my $source_path = File::Spec->catfile( $self->BaseDir, $source );

        my $component = $dest =~ s{^([^:/]+):/}{} ? $1 : 'root';

        my $dest_path = File::Spec->catfile( $self->get_system_dir, $component, $dest );
        my $dest_dir = dirname( $dest_path );
        my $dest_relpath = File::Spec->abs2rel( $dest_path, $self->BaseDir );

        warn "Generating $dest_relpath\n      from $source\n"
            unless $self->Quiet;

        return
            if $self->DryRun;

        mkpath( $dest_dir, 1, 0755 );

        my $tmp = File::Temp->new( DIR => $dest_dir, UNLINK => 1 );

        eval {
            my $ifh = IO::File->new( $source_path, O_RDONLY )
                or die "Error opening $source_path for reading: $!";

            if ( $source =~ /\.tt$/ ) {
                my $params = $self->get_params->merge( $file_params )->template_vars;
                $params->{ tmpl_source } = $source;
                $params->{ tmpl_dest }   = "/$dest";
                my $tt = $self->Template();
                $self->Template->process( $ifh, { params => $params, %RB3::TemplateFunctions::functions }, $tmp )
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
        };
        if ( $@ ) {
            if ( $@ =~ /Shuffle not enabled/ ) {
                warn "  skipping $dest: shuffle not enabled\n"
                    unless $self->Silent;
#                die  "  Missing $dest"
#                    if ! -f $dest_path && $options{diemissing};
                return;
            }
            else {
                die $@;
            }
        }

        rename( $tmp->filename, $dest_path )
            or die "Error renaming " . $tmp->filename . " to $dest_path: $!";
    }
}

1;

__END__
