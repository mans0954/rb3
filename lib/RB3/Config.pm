#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.25/lib/RB3/Config.pm $
# $LastChangedRevision: 16292 $
# $LastChangedDate: 2009-10-02 12:03:22 +0100 (Fri, 02 Oct 2009) $
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
    my %repovars_of      :ATTR( :get<repovars_list> );
    my %params_files_of  :ATTR( :get<params_file_list> );

    sub BUILD {
        my ( $self, $obj_id, $arg_ref ) = @_;

        $files_of{ $obj_id }  = RB3::FileList->new();
        $params_of{ $obj_id } = RB3::ParameterList->new( { params => {} } );
        $repovars_of{ $obj_id } = RB3::ParameterList->new( { params => {} } );
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

    sub get_home_dir {
        my $self = shift;
        File::Spec->catdir( $self->get_system_dir, 'home' );
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
        push @{$rb3_files_of{ ident $self }}, File::Spec->abs2rel( $rb3, '.' );
        while ( <$fh> ) {
            next if /^#/;
            chomp;
            while ( s{\\$}{} and my $cont = <$fh> ) {
                chomp( $cont );
                $_ .= $cont;
            }
            if ( s{^\+}{} ) {
                my $args = parse_add_args( split );

                $args->{ rb3_source } = File::Spec->abs2rel( $rb3, '.' );
                $self->get_file_list->add_file( RB3::File->new( $args ) );
            }
            elsif ( s{^\-/?}{} ) {
                $self->get_file_list->del_file( RB3::File->new( { dest => $_ } ) );
            }
            elsif ( s{^\!}{} ) {
                push @{$params_files_of{ ident $self }}, $_;
                my $params_path = File::Spec->catfile( '.', $_ );
                $self->get_parameter_list->load_from_yaml( $params_path );
            }
            elsif ( s{^\=}{} ) {
                my $rb3_path = File::Spec->catfile( '.', $_ );
                $self->parse_rb3( $rb3_path, $depth + 1 );
            }
            elsif ( s{^\:}{} ) {
                my $repovars_path = File::Spec->catfile( '.', $_ );
                $self->get_repovars_list->load_from_yaml( $repovars_path );
            }
            else {
                die "Parse error at $rb3 line $.\n";
            }
        }
        $fh->close();
    }

    sub parse_add_args : PRIVATE {
        my %properties;

        my $dest = shift;
        if( $dest =~ s,^/,, ) {
            $properties{ component } = 'root';
            $properties{ notation }  = '/';
        }
        elsif( $dest =~ s,^~,, ) {
            $properties{ component } = 'home';
            $properties{ notation  } = '~';
        }
        # "external" components, so they won't end up in configtool.meta:
        elsif( $dest =~ s{^([^:/]+):/}{} ) {
            my $comp = $1;
            $properties{ component } = $comp;
            $properties{ notation } = undef;
        }
        else {
            die "all file paths must start with / or ~ or COMPNAME:\ninvalid path: $dest\n";
        }

        $properties{ dest } = $dest;

        $properties{ params } = RB3::ParameterList->new();
        foreach ( @_ ) {
            if ( s/\!// ) {
                my $params_path = File::Spec->catfile( '.', $_ );
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
