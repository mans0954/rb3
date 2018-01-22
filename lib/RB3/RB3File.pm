#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.28/lib/RB3/RB3File.pm $
# $LastChangedRevision: 17648 $
# $LastChangedDate: 2010-10-05 23:12:33 +0100 (Tue, 05 Oct 2010) $
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
}

1;

__END__
