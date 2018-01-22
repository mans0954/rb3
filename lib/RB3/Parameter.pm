#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.30/lib/RB3/Parameter.pm $
# $LastChangedRevision: 11514 $
# $LastChangedDate: 2007-11-19 13:31:17 +0000 (Mon, 19 Nov 2007) $
# $LastChangedBy: ray $
#
package RB3::Parameter;

use strict;
use warnings FATAL => 'all';

use Class::Std;
{
    my %name_of   :ATTR( :name<name>   );
    my %value_of  :ATTR( :name<value>  );
    my %source_of :ATTR( :name<source> );

    sub as_hash : HASHIFY {
        my $self = shift;
        my %h;
        foreach my $k ( qw( name value source ) ) {
            my $accessor = "get_$k";
            $h{ $k } = $self->$accessor;
        }
        return \%h;
    }
}

1;

__END__
