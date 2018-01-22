#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.40/lib/RB3/RB3File.pm $
# $LastChangedRevision: 19037 $
# $LastChangedDate: 2011-10-08 19:30:06 +0100 (Sat, 08 Oct 2011) $
# $LastChangedBy: tom $
#
package RB3::RB3File;

use strict;
use warnings FATAL => 'all';

use Class::Std;

use File::Spec;

{
    my %path_of       :ATTR( :init_arg<path> );
    my %parent_of     :ATTR( :name<parent> :default<>      );

    sub path {
        my ($self) = @_;

        return File::Spec->abs2rel($path_of{ident $self}, '.');
    }

    sub get_path_stack {
        my ($self) = @_;

        if (defined($self->get_parent)) {
            return ($self->path, $self->get_parent->get_path_stack);
        }
        else {
            return $self->path;
        }
    }

    sub stringify :STRINGIFY {
        my ($self) = @_;

        return $path_of{ident $self};
    }
}

1;

__END__
