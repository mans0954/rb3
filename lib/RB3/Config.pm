#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.42/lib/RB3/Config.pm $
# $LastChangedRevision: 21892 $
# $LastChangedDate: 2013-09-06 15:40:30 +0100 (Fri, 06 Sep 2013) $
# $LastChangedBy: oucs0173 $
#

=head1 NAME

RB3::Config

=head1 SCOPE OF CONSUMERS

Internal to the rb3 application.

=head1 UTILITY FUNCTIONS

=head2 decode_path_notation($pathspec)

Given a path in rb3's notation for destination paths, returns a hash
containing the file's path within that component (key: "dest"), 
the name of the component (key: "component"), and a hint about the
notation that was used originally (key: "notation").

For example, decode_path_notation('~/foo') should return:

  (dest => 'foo', component => 'home', notation => '~')

=cut

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
use RB3::File;
use RB3::FileList;
use RB3::ParameterList;
use RB3::RB3File;
use YAML;

{
    my %system_dir_of    :ATTR( :get<system_dir> :init_arg<system_dir> );
    my %files_of         :ATTR( :get<file_list> );
    my %rb3_files_of     :ATTR( :get<rb3_file_list> );
    my %params_of        :ATTR( :get<parameter_list> );
    my %repovars_of      :ATTR( :get<repovars_list> );
    my %params_files_of  :ATTR( :get<params_file_list> );
    my %rb3_files        :ATTR;

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
        $self->parse_rb3(RB3::RB3File->new({path => $self->get_rb3_path}), 0);
        return;
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

        File::Find::find(
            sub {
                if ( -d && /^\.svn$/ ) {
                    $File::Find::prune = 1;
                    return;
                }
                if ( -f _ ) {
                    $files->add_file(
                        RB3::File->new({
                            dest => File::Spec->abs2rel( 
                                $File::Find::name, $sys_root_dir 
                            ) 
                        })
                    );
                }
            },
            $sys_root_dir
        );
    }

    sub parse_rb3 : PRIVATE {
        my ( $self, $rb3, $depth ) = @_;

        $self->register_rb3_file($rb3);

        die( "Exceeded maximum parse depth at " . $rb3->path
            . " line $. - circular includes?\n" )
            if $depth > __PACKAGE__->MaxDepth;

        my $fh = IO::File->new( $rb3->path, O_RDONLY )
            or die( "Error opening " . $rb3->path . ": $!\n" );
        push @{$rb3_files_of{ ident $self }}, 
            File::Spec->abs2rel( $rb3->path, '.' );

        while ( <$fh> ) {
            next if /^#/;
            chomp;
            while ( s{\\$}{} and my $cont = <$fh> ) {
                chomp( $cont );
                $_ .= $cont;
            }
            if ( s{^\+}{} ) {
                my $args = parse_add_args( split );

                $args->{ rb3_source } = $rb3->path;
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
                my $child_rb3 = RB3::RB3File->new({
                    path => $rb3_path, parent => $rb3,
                });

                $self->parse_rb3($child_rb3, $depth + 1);

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

        %properties = decode_path_notation($dest);

        $properties{ params } = RB3::ParameterList->new();
        foreach ( @_ ) {
            if ( s/^\!// ) {
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
            elsif ( /^\$(.*?)=(.*)/ ) {
                $properties{extras}{$1} = $2;
            }
            else {
                die( "duplicate source" )
                    if defined $properties{ source };
                $properties{ source } = $_;
            }
        }
        return \%properties;
    }


    sub decode_path_notation {
        my $dest_encoded = shift;

        my %properties;

        # Call it $dest_ptype while under construction.
        my $dest_ptype = $dest_encoded;

        if( $dest_ptype =~ s,^/,, ) {
            $properties{ component } = 'root';
            $properties{ notation }  = '/';
        }
        elsif( $dest_ptype =~ s,^~,, ) {
            $properties{ component } = 'home';
            $properties{ notation  } = '~';
        }
        # "external" components, so they won't end up in configtool.meta:
        elsif( $dest_ptype =~ s{^([^:/~]+):/}{} ) {
            my $comp = $1;
            $properties{ component } = $comp;
            $properties{ notation } = undef;
        }
        else {
            die "all file paths must start with / or ~ or "
                . "COMPNAME:\ninvalid path: $dest_ptype\n";
        }
        # If we're still here, its value is now the destination path (relative
        # to the component).
        my $dest = $dest_ptype;

        $properties{dest} = $dest;

        return %properties;
    }

    sub why_path {
        my ($self, $path) = @_;

        # $path could be a generated file or an rb3 file

        my $file = $self->get_file_list->get_file($path);
        if (defined($file)) {
            my $rb3s = new RB3::RB3File({path => $file->get_rb3_source});
            my @f = $rb3s->get_path_stack;

            if (@f == 1) {
                $file = $self->rb3_file_by_path($f[0]);
                @f = $file->get_path_stack if $file;
            }
            return ($path, @f);
        }
        
        $file = $self->rb3_file_by_path($path);

        if (defined($file)) {
            return $file->get_path_stack;
        }

        die "don't know about $path\n";
    }

    sub rb3_file_by_path {
        my ($self, $path) = @_;

        return $rb3_files{ident $self}{$path};
    }

    sub register_rb3_file {
        my ($self, $rb3f) = @_;

        $rb3_files{ident $self}{$rb3f->path} = $rb3f;
        return;
    }
}

1;

__END__
