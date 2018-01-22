#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.26/lib/RB3/ParameterList.pm $
# $LastChangedRevision: 11523 $
# $LastChangedDate: 2007-11-20 14:29:06 +0000 (Tue, 20 Nov 2007) $
# $LastChangedBy: ray $
#
package RB3::ParameterList;

use strict;
use warnings FATAL => 'all';

use Carp qw( croak );
use Class::Std;
use RB3::Parameter;
use YAML;

{
    my %param_ref_of :ATTR( :get<param_ref> );

    sub BUILD {
        my ( $self, $obj_id, $arg_ref ) = @_;

        $param_ref_of{ $obj_id } = $arg_ref->{ params } || {};
    }

    sub add_param {
        my ( $self, $param ) = @_;
        $self->get_param_ref->{ $param->get_name } = $param;
    }

    sub load_from_yaml {
        my ( $self, $yaml_path ) = @_;

        my $yaml_data = eval { YAML::LoadFile( $yaml_path ) };
        croak( "Failed to load data from $yaml_path: $@" )
            if $@;

        while ( my ( $key, $value ) = each %$yaml_data ) {
            $self->add_param( RB3::Parameter->new( { name   => $key,
                                                     value  => $value,
                                                     source => $yaml_path } ) );
        }
    }

    sub as_array : ARRAYIFY {
        my $self = shift;
        return [ values %{ $self->get_param_ref } ];
    }

    sub template_vars {
        my $self = shift;
        return { map { $_->get_name => $_->get_value } @$self };
    }

    sub merge {
        my ( $self, $other ) = @_;
        my %params = ( %{ $self->get_param_ref }, %{ $other->get_param_ref } );
        return RB3::ParameterList->new( { params => \%params } );
    }
}

1;

__END__
