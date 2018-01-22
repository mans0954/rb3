#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.37/lib/RB3/FileList.pm $
# $LastChangedRevision: 11518 $
# $LastChangedDate: 2007-11-19 15:57:23 +0000 (Mon, 19 Nov 2007) $
# $LastChangedBy: ray $
#
package RB3::FileList;

use strict;
use warnings FATAL => 'all';

use Class::Std;
use RB3::File;

{
    my %file_ref_of :ATTR( :get<file_ref> );

    sub BUILD {
        my ( $self, $obj_id, $arg_ref ) = @_;

        $file_ref_of{ $obj_id } = {};
    }

    sub add_file {
        my ( $self, $file ) = @_;

        $file = RB3::File->new( $file )
            unless ref( $file ) eq 'RB3::File';

        $self->get_file_ref->{ $file->get_dest } = $file;
    }

    sub del_file {
        my ( $self, $file ) = @_;

        my $dest = ref( $file ) ? $file->get_dest : $file;

        delete $self->get_file_ref->{ $dest };
    }

    sub get_file {
        my ( $self, $file ) = @_;

        my $dest = ref( $file ) ? $file->get_dest : $file;

        return $self->get_file_ref->{ $dest };
    }

    sub as_array : ARRAYIFY {
        my $self = shift;
        return [
            values %{ $self->get_file_ref }
        ];
    }
}

1;

__END__
