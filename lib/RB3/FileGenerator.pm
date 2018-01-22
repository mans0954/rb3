#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.36/lib/RB3/FileGenerator.pm $
# $LastChangedRevision: 19698 $
# $LastChangedDate: 2012-07-12 00:31:21 +0100 (Thu, 12 Jul 2012) $
# $LastChangedBy: tom $
#
package RB3::FileGenerator;

use strict;
use warnings FATAL => 'all';

use base 'Class::Data::Inheritable';

__PACKAGE__->mk_classdata( DryRun  => 0     );
__PACKAGE__->mk_classdata( Quiet   => 0     );
__PACKAGE__->mk_classdata( Silent  => 0     );
__PACKAGE__->mk_classdata( Strict  => 0     );
__PACKAGE__->InitVMethods();

use Class::Std;
use File::Basename qw( dirname );
use File::Path qw( mkpath );
use File::Spec::Functions;
use File::Temp;
use IO::File;
use RB3::TemplateFunctions;
use Template;
use Template::Stash;

=head1 NAME

RB3::FileGenerator - Generate files for a target system.

=head1 SCOPE OF CONSUMERS

Internal to the rb3 application.

=cut

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
            my %ttopts = ( INCLUDE_PATH => '.' );
            if (RB3::FileGenerator->Strict) {
                $ttopts{STRICT} = 1;
            }
            $tt = Template->new( %ttopts );
        }
        return $tt;
    }
}

{

    my %params_of     :ATTR( :init_arg<params>     :get<params> );
    my %system_dir_of :ATTR( :init_arg<system_dir> :get<system_dir> );

    sub generate {
        my ( $self, $source, $dest, $ctmeta_path, $file_params,
             $component, $app_config ) = @_;

        my $dest_path = $self->repopath($component, $dest );
        my $dest_dir = dirname( $dest_path );
#        my $dest_relpath = File::Spec->abs2rel( $dest_path, "." );

        warn "Generating $dest_path\n      from $source\n"
            unless $self->Quiet;

        return
            if $self->DryRun;

        mkpath( $dest_dir, !$app_config->Silent, 0755 );

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

=head2 repopath($component, $destpath)

Given a destination path on the target of $destpath, and component
$component, returns the path of the output file relative to the rb3
repository that we're in.

=cut

    sub repopath {
        my ($self, $component, $destpath) = @_;

        return canonpath(catfile($self->get_system_dir, $component, $destpath));
    }
}

1;

__END__
