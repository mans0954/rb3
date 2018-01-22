package RB3::GraphViz;

#
# this is an override for the GraphViz quoting function.
# we will accept mode characters than just space in node names
# and just quote the name (srt#144228)
#

use strict;
use warnings;
use base 'GraphViz';

sub _quote_name {
    my ( $self, $name ) = @_;
    my $realname = $name;

    return $self->{_QUOTE_NAME_CACHE}->{$name}
        if $name && exists $self->{_QUOTE_NAME_CACHE}->{$name};

    if ( $name =~ /^[a-zA-Z]\w*$/ && $name ne "graph" ) {

        # name is fine
    }
    else {

        # name contains spaces or other characters, so quote it
        $name = '"' . $name . '"';
    }

    $self->{_QUOTE_NAME_CACHE}->{$realname} = $name if defined $realname;

    return $name;
}

1;
