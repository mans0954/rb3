#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/trunk/lib/RB3/Config.pm $
# $LastChangedRevision: 16026 $
# $LastChangedDate: 2009-08-06 16:51:34 +0100 (Thu, 06 Aug 2009) $
# $LastChangedBy: tom $
#
package RB3::Config;

use strict;
use warnings FATAL => 'all';

use base 'Class::Data::Inheritable';

__PACKAGE__->mk_classdata( MaxDepth  => 20  );
__PACKAGE__->mk_classdata( BaseDir   => undef );

use Class::Std;
use File::Basename qw( basename );
use File::Find;
use File::Spec;
use IO::File;
use RB3::FileList;
use RB3::ParameterList;
use YAML;

{
    my %system_dir_of    :ATTR( :get<system_dir> :init_arg<system_dir> );
    my %files_of         :ATTR( :get<file_list> );
    my %rb3_files_of     :ATTR( :get<rb3_file_list> );
    my %params_of        :ATTR( :get<parameter_list> );
    my %params_files_of  :ATTR( :get<params_file_list> );

    sub BUILD {
        my ( $self, $obj_id, $arg_ref ) = @_;

        my %params = (
            hostname => RB3::Parameter->new(
                {
                    name   => 'hostname',
                    value  => basename( $arg_ref->{ system_dir } ),
                    source => 'auto'
                }
            ),
        );

        $files_of{ $obj_id }  = RB3::FileList->new();
        $params_of{ $obj_id } = RB3::ParameterList->new( { params => \%params } );
        $rb3_files_of{ $obj_id } = [];
        $params_files_of{ $obj_id } = [];
    }

    sub START {
        my ( $self, $obj_id, $arg_ref ) = @_;

        $self->init_files();
    }

    sub read_config {
        my $self = shift;
        $self->parse_rb3( $self->get_rb3_path, 0 );
    }

    sub get_root_dir {
        my $self = shift;
        File::Spec->catdir( $self->get_system_dir, 'root' );
    }

    sub get_rb3_path {
        my $self = shift;
        File::Spec->catfile( $self->get_system_dir, 'config.rb3' );
    }

    sub init_files : PRIVATE {
        my $self = shift;

        my $sys_root_dir = $self->get_root_dir;

        -d $sys_root_dir
            or return;

        my $files = $self->get_file_list;

        File::Find::find( sub {
                              if ( -d && /^\.svn$/ ) {
                                  $File::Find::prune = 1;
                                  return;
                              }
                              if ( -f _ ) {
                                  $files->add_file( { dest => File::Spec->abs2rel( $File::Find::name, $sys_root_dir ) } );
                              }
                          },
                          $sys_root_dir);
    }

    sub parse_rb3 : PRIVATE {
        my ( $self, $rb3, $depth ) = @_;

        die( "Exceeded maximum parse depth at $rb3 line $. - circular includes?\n" )
            if $depth > __PACKAGE__->MaxDepth;

        my $fh = IO::File->new( $rb3, O_RDONLY )
            or die( "Error opening $rb3: $!\n" );
        push @{$rb3_files_of{ ident $self }}, File::Spec->abs2rel( $rb3, __PACKAGE__->BaseDir );
        while ( <$fh> ) {
            next if /^#/;
            chomp;
            while ( s{\\$}{} and my $cont = <$fh> ) {
                chomp( $cont );
                $_ .= $cont;
            }
            if ( s{^\+}{} ) {
                my $args = parse_add_args( split );
                die( "BaseDir not set" )
                    unless defined __PACKAGE__->BaseDir;
                $args->{ rb3_source } = File::Spec->abs2rel( $rb3, __PACKAGE__->BaseDir );
                $self->get_file_list->add_file( RB3::File->new( $args ) );
            }
            elsif ( s{^\-/?}{} ) {
                $self->get_file_list->del_file( RB3::File->new( { dest => $_ } ) );
            }
            elsif ( s{^\!}{} ) {
                push @{$params_files_of{ ident $self }}, $_;
                my $params_path = File::Spec->catfile( __PACKAGE__->BaseDir, $_ );
                $self->get_parameter_list->load_from_yaml( $params_path );
            }
            elsif ( s{^\=}{} ) {
                my $rb3_path = File::Spec->catfile( __PACKAGE__->BaseDir, $_ );
                $self->parse_rb3( $rb3_path, $depth + 1 );
            }
            else {
                die "Parse error at $rb3 line $.\n";
            }
        }
        $fh->close();
    }

    sub parse_add_args : PRIVATE {
        my %properties;
        ( $properties{ dest } = shift ) =~ s{^/+}{};
        $properties{ params } = RB3::ParameterList->new();
        foreach ( @_ ) {
            if ( s/\!// ) {
                my $params_path = File::Spec->catfile( __PACKAGE__->BaseDir, $_ );
                $properties{ params }->load_from_yaml( $params_path );
            }
            elsif ( /:/ ) {
                die( "duplicate owner/group" )
                    if defined $properties{ owner } or defined $properties{ group };
                @properties{ qw( owner group } ) } = split ":";
            }
            elsif ( /^0/ ) {
                die( "duplicate mode" )
                    if defined $properties{ mode };
                $properties{ mode } = $_;
            }
            else {
                die( "duplicate source" )
                    if defined $properties{ source };
                $properties{ source } = $_;
            }
        }
        return \%properties;
    }

}

1;

__END__
