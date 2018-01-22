#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/trunk/lib/RB3/File.pm $
# $LastChangedRevision: 13833 $
# $LastChangedDate: 2008-05-22 14:47:16 +0100 (Thu, 22 May 2008) $
# $LastChangedBy: dom $
#
package RB3::File;

use strict;
use warnings FATAL => 'all';

use base 'Class::Data::Inheritable';

__PACKAGE__->mk_classdata( DefaultOwner => 'root' );
__PACKAGE__->mk_classdata( DefaultGroup => 'root' );
__PACKAGE__->mk_classdata( DefaultMode  => '0444' );

use Class::Std;
use RB3::ParameterList;

{
    my %dest_of       :ATTR( :get<dest>    :init_arg<dest> );
    my %source_of     :ATTR( :name<source> :default<>      );
    my %rb3_source_of :ATTR( :name<rb3_source> :default<>  );
    my %owner_of      :ATTR( :get<owner>                   );
    my %group_of      :ATTR( :get<group>                   );
    my %mode_of       :ATTR( :get<mode>                    );
    my %params_of     :ATTR( :get<parameter_list>          );

    sub BUILD {
        my ( $self, $obj_id, $arg_ref ) = @_;

        $params_of{ $obj_id } = defined( $arg_ref->{ params } ) ? $arg_ref->{ params }
                                                                : RB3::ParameterList->new();

        $owner_of{ $obj_id } = defined( $arg_ref->{ owner } ) ? $arg_ref->{ owner }
                                                              : __PACKAGE__->DefaultOwner();

        $group_of{ $obj_id } = defined( $arg_ref->{ group } ) ? $arg_ref->{ group }
                                                              : __PACKAGE__->DefaultGroup();

        $mode_of{ $obj_id } = defined( $arg_ref->{ mode } ) ? $arg_ref->{ mode }
                                                            : __PACKAGE__->DefaultMode();
    }

    sub as_hash : HASHIFY {
        my $self = shift;
        my %h;
        foreach my $k ( qw( dest source owner group mode rb3_source ) ) {
            my $accessor = "get_$k";
            $h{ $k } = $self->$accessor();
        }
        my $params = $self->get_parameter_list;
        if ( @$params ) {
            $h{ params } = { map { $_->get_name => $_->as_hash } @$params };
        }
        return \%h;
    }
}

1;

__END__
