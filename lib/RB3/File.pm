#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.30/lib/RB3/File.pm $
# $LastChangedRevision: 19204 $
# $LastChangedDate: 2012-01-05 16:21:03 +0000 (Thu, 05 Jan 2012) $
# $LastChangedBy: worc2070 $
#
package RB3::File;

use strict;
use warnings FATAL => 'all';

use base 'Class::Data::Inheritable';

__PACKAGE__->mk_classdata( DefaultOwner => 'root' );
__PACKAGE__->mk_classdata( DefaultGroup => 'root' );
__PACKAGE__->mk_classdata( DefaultMode  => '0444' );
__PACKAGE__->mk_classdata( DefaultComponent => 'root' );
__PACKAGE__->mk_classdata( DefaultNotation  => '/' );

use Class::Std;
use RB3::ParameterList;

{
    my %dest_of       :ATTR( :get<dest>    :init_arg<dest> );
    my %source_of     :ATTR( :name<source> :default<>      );
    my %rb3_source_of :ATTR( :init_arg<rb3_source> :set<rb3_source> :default<>  );
    my %owner_of      :ATTR( :get<owner>                   );
    my %group_of      :ATTR( :get<group>                   );
    my %mode_of       :ATTR( :get<mode>                    );
    my %extras_of      :ATTR( :get<extras>                   );
    my %params_of     :ATTR( :get<parameter_list>          );
    my %component_of  :ATTR( :get<component>               );
    my %notation_of   :ATTR( :get<notation>                );
    my %owner_explicitly_set_of :ATTR( :get<owner_explicitly_set> );
    my %group_explicitly_set_of :ATTR( :get<group_explicitly_set> );
    my %mode_explicitly_set_of  :ATTR( :get<mode_explicitly_set>  );

    sub BUILD {
        my ( $self, $obj_id, $arg_ref ) = @_;

        $params_of{ $obj_id } = defined( $arg_ref->{ params } )
                              ? $arg_ref->{ params }
                              : RB3::ParameterList->new();

        if (defined($arg_ref->{ owner })) {
            $owner_of{ $obj_id } = $arg_ref->{ owner };
            $owner_explicitly_set_of{ $obj_id } = 1;
        }
        else {
            $owner_of{ $obj_id } = __PACKAGE__->DefaultOwner();
        }

        if (defined( $arg_ref->{ group } )) {
            $group_of{ $obj_id } = $arg_ref->{ group };
            $group_explicitly_set_of{ $obj_id } = 1;
        }
        else {
            $group_of{ $obj_id } = __PACKAGE__->DefaultGroup();
        }

        if (defined( $arg_ref->{ mode } )) {
            $mode_of{ $obj_id } = $arg_ref->{ mode };
            $mode_explicitly_set_of{ $obj_id } = 1;
        }
        else {
            $mode_of{ $obj_id } = __PACKAGE__->DefaultMode();
        }

        $extras_of{ $obj_id } = defined( $arg_ref->{ extras } )
                              ? $arg_ref->{ extras }
                              : {};

        $component_of{ $obj_id } = defined( $arg_ref->{ component } )
                                 ? $arg_ref->{ component }
                                 : __PACKAGE__->DefaultComponent();

        $notation_of{ $obj_id } = defined( $arg_ref->{ notation } )
                                ? $arg_ref->{ notation }
                                : __PACKAGE__->DefaultNotation();
    }

    sub as_hash : HASHIFY {
        my $self = shift;
        my %h;
        foreach my $k ( qw( dest source owner group mode rb3_source component ) ) {
            my $accessor = "get_$k";
            $h{ $k } = $self->$accessor();
        }
        my $params = $self->get_parameter_list;
        if ( @$params ) {
            $h{ params } = { map { $_->get_name => $_->as_hash } @$params };
        }
        return \%h;
    }

    sub get_ctmeta_path {
        my $self = shift;
        return File::Spec->catdir($self->get_notation, $self->get_dest);
    }

    sub get_rb3_source {
        my ($self) = @_;

        return $rb3_source_of{ident $self};
    }
}

1;

__END__
