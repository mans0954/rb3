#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.26/lib/RB3/TemplateFunctions.pm $
# $LastChangedRevision: 17888 $
# $LastChangedDate: 2010-12-08 18:32:02 +0000 (Wed, 08 Dec 2010) $
# $LastChangedBy: dom $
#
package RB3::TemplateFunctions;

=head1 NAME

RB3::TemplateFunctions - functions imported into Template Toolkit namespace

=head1 DESCRIPTION

This module defines additional functions which are imported into the
Template Toolkit namespace.

=cut

use strict;
use warnings FATAL => 'all';

use Carp;
use File::Basename;
use List::Util ();
use Math::BigInt;
use Math::Random::ISAAC;
use Net::DNS;
use Net::Netmask;
use Readonly;
use Socket qw(inet_ntoa inet_aton AF_INET);
use Sort::Fields ();
use Data::Dumper;

sub contains {
    my ( $list_ref, $wanted ) = @_;

    scalar grep { $_ eq $wanted } @{ $list_ref };
}

sub fieldsort {
    my $list_ref = shift;
    Sort::Fields::fieldsort( @_, @{ $list_ref } );
}

sub ipaddr {
    my $addr = shift;
    my @res = gethostbyname( $addr )
        or Carp::confess "gethostbyname $addr failed";
    @res == 5
        or die "more than one address for $addr";
    return inet_ntoa( $res[4] );
}

sub ip6addr {
    my $addr = shift;
    my @addresses = dnslookup($addr, 'AAAA');
    die "More than one AAAA returned for ip6addr"
        unless scalar @addresses == 1;
    return $addresses[0];
}

sub ip6addr_eok {
    my $addr = shift;
    my $address = eval {
        ip6addr($addr);
    };
    if ($@) {
        die $@ unless $@ =~ /NOERROR/;
    }
    return $address;
}

# <http://cboard.cprogramming.com/c-programming/109269-hash-function-translated-cplusplus.html>
# Should create a tiny CPAN module with this in?
sub hash {
    my ($str) = @_;

    my $max = 2 ** 32;
    my $hash = 5381;

    while (length(my $chr = substr($str, 0, 1, ""))) {
        $hash = (((($hash << 5) % $max) + $hash) % $max);
        $hash = ($hash + ord($chr)) % $max;
    }

    return $hash & 0x7FFFFFFF;
}

{
    my $resolver;

    sub dnslookup {
        my ( $hostname, $type ) = @_;
        die "no hostname given"
            unless defined $hostname;
        $resolver ||= Net::DNS::Resolver->new();
        if ( not( defined $type ) or $type eq 'A' ) {
            my $query = $resolver->query( $hostname, 'A' )
                or die "Query A records for $hostname: " . $resolver->errorstring;
            my @results;
            foreach my $rr ( $query->answer ) {
                if ( ( my $type = $rr->type ) ne 'A' ) {
                    die "Query A records for $hostname returned unexpected $type record";
                }
                push @results, $rr->address;
            }
            return @results;
        } elsif ( $type eq 'MX' ) {
            my @mx = mx( $resolver, $hostname )
                or die "Query MX records for $hostname: " . $resolver->errorstring;
            map dnslookup($_->exchange), @mx;
        } elsif ( $type eq 'PTR' ) {
            my $query = $resolver->query( $hostname, 'PTR' )
                or die "Query PTR records for $hostname: " . $resolver->errorstring;
            my @results;
            foreach my $rr ( $query->answer ) {
                if ( ( my $type = $rr->type ) ne 'PTR') {
                    die "Query PTR records for $hostname returned unexpected $type record";
                }
                push @results, $rr->ptrdname;
            }
            return @results;
        } elsif ( $type eq 'AAAA' ) {
            my $query = $resolver->query( $hostname, 'AAAA' )
                or die "Query AAAA records for $hostname: " . $resolver->errorstring;
            my @results;
            foreach my $rr ( $query->answer ) {
                if ( ( my $type = $rr->type ) ne 'AAAA' ) {
                    die "Query AAAA records for $hostname returned unexpected $type record";
                }
                push @results, $rr->address;
            }
            return @results;
        } else {
                die "Unrecognized type '$type' for DNS lookup\n";
            }
    }
}

sub store_netmask_in_table {
    my $netmask = shift;
    my $table = shift;
    my $block = Net::Netmask->new($netmask);
    $block->storeNetblock($table);
}

sub find_netmask_in_table {
    my $address = shift;
    my $table = shift;
    Net::Netmask::findNetblock($address, $table);
}

=head1 FUNCTIONS

The following functions are available:

=over 4

=item hostname

Takes an IPv4 address and returns a hostname.

    [% hostname('127.0.0.1') %]

=item dnslookup

Takes a hostname and an optional record type and performs a DNS lookup,
returning the results as a list. Supported record types: A, PTR, AAAA, MX.

    [% dnslookup('www.example.org', 'A').join(',') %]
    [% dnslookup('192.168.1.1', 'PTR').join(',') %]
    [% dnslookup('www.example.org', 'AAAA').join(',') %]

BUG: The MX type is special; it performs a lookup for the IPv4 address
of the names before returning them

    [% dnslookup('example.org', 'MX').join(',') %]

=item store_netmask_in_table

Takes a netmask and a Net::Netmask 'table' hashref and stores the netmask
in the table. See storeNetblock in L<Net::Netmask>.

    [% SET table = {} %]
    [% SET store_result = store_netmask_in_table('192.168.1.0/24') %]

=item find_netmask_in_table

Takes a test address and a Net::Netmask 'table' hashref and returns
true if the test address is enclosed by the table, and false otherwise.

    [% SET is_in_table = netmask('192.168.0.1', table) %]

=item ipaddr

Takes a hostname and returns an IPv4 address

    [% ipaddr('localhost') %]

=item ip6addr

Takes a hostname and returns an IPv6 address. Throws an exception if
none exists.

    [% ip6addr('dual-stack.example.org') %]

=item ip6addr_eok

Takes a hostname and returns an IPv6 address. Does not throw an exception
if none exists.

    [% ip6addr_eok('legacy-host.example.org') %]

=item netblock

Takes a hostname or IPv4 address and returns the IPv4 CIDR netblock
representing it. Returns the special value 'any' unaltered.

    [% netblock('myhost.example.org') %]
    # returns '192.168.1.1/32'

=item netmask

Takes a hostname or IPv4 address and returns the IPv4 network number
and netmask in the standard notation. 

    [% netmask('myhost.example.org') %]
    # returns '192.168.1.1/255.255.255.255'

=item dirname

Returns the name of the directory containing a file. See L<File::Basename>.

    [% dirname('/etc/fstab') %]
    # returns '/etc'

=item basename

Returns the name of a file after stripping the directory component.
See L<File::Basename>.

    [% basename('/etc/init.d/sshd') %]
    # returns 'sshd'

=item iface_parent

Takes a pair of colon-separated values and returns the first only

    [% iface_parent('eth0:www') %]
    # returns 'eth0'

BUG: this function is badly named.

=item is_member

Takes a scalar and a list ref and returns true if the scalar is 
contained in the list and false otherwise.

    [% SET mylist = ['foo', 'bar', 'wibble'] %]
    [% is_member('baz', mylist) %]

=item difference

Takes two sets (lists) and returns the differences between them

    [% SET list1 = ['foo', 'bar', 'baz'] %]
    [% SET list2 = ['bar', 'foo'] %]
    [% difference(list1, list2) %]
    # returns 'baz'

=item keyorder_sort_on_subhashes_num

Takes a hash and a sort key, and returns a list of keys sorted numerically
on the named subhash sort key

    [% SET myhash = {
        person1 => { name => 'jill',
                     id => 1 },
        person2 => { name => 'bob',
                     id => 2 } } %]

    [% keyorder_sort_on_subhashes_num(myhash, 'id').join(',') %]
    # returns person1,person2

=item keyorder_sort_on_subhashes_string

Takes a hash and a sort key, and returns a list of keys sorted alphanumerically
on the named subhash sort key

    [% keyorder_sort_on_subhashes_string(myhash, 'name').join(',') %]
    # returns person2,person1

=item shuffle

Takes a list and a string to be used as a constant for a shuffle function
and returns the shuffle list

    [% SET myns = [ '192.168.1.1', '192.168.1.2', '192.168.1.3' ] %]
    [% FOREACH ns IN shuffle(myns, params.hostname) -%]
    nameserver [% ns %]
    [% END -%]

=back

=cut

our %functions = (
    hostname => sub {
        my $addr = inet_aton(shift);
        scalar gethostbyaddr( $addr, AF_INET );
    },

    dnslookup => \&dnslookup,
    store_netmask_in_table => \&store_netmask_in_table,
    find_netmask_in_table => \&find_netmask_in_table,

    ipaddr => sub { ipaddr( shift ) },
    ip6addr => sub { ip6addr( shift ) },
    ip6addr_eok => sub { ip6addr_eok( shift ) },

    netblock => sub {
        my $netblock = shift;
        if ($netblock eq 'any') {
            return $netblock;
        }
        if ($netblock !~ /^(\d+)\./) { 
            $netblock = ipaddr($netblock);
        }
        return ''.Net::Netmask->new($netblock);
    },

    netmask => sub {
        my $netmask = shift;
        if ($netmask !~ /^(\d+)\./) { 
            $netmask = ipaddr($netmask);
        }
        my $block= Net::Netmask->new($netmask);
        return ''.$block->base().'/'.$block->mask();
    },

    dirname => sub {
        my $path = shift;
        return File::Basename::dirname( $path );
    },

    basename => sub {
        my $path = shift;
        return File::Basename::basename( $path );
    },

    iface_parent => sub {
        my ($parent, $alias) = split /:/, shift;
        return $parent;
    },

    is_member => sub {
        my ($item, $list_ref) = @_;
        grep { $item eq $_ } @$list_ref;
    },

    difference => sub {
        my ($set_a, $set_b) = @_;
        my %set_hash = map { ($_ => 1) } @$set_a;
        delete $set_hash{$_} for @$set_b;
        return sort keys %set_hash;
    },

    keyorder_sort_on_subhashes_num => sub {
        my ($hash, $sortkey) = @_;

        return sort {
            $hash->{$a}->{$sortkey} <=> $hash->{$b}->{$sortkey}
        } keys %$hash;
    },

    keyorder_sort_on_subhashes_string => sub {
        my ($hash, $sortkey) = @_;

       return sort {
            $hash->{$a}->{$sortkey} cmp $hash->{$b}->{$sortkey}
       } keys %$hash;
    },

    shuffle => sub {
        my ($list_ref, $hash_input) = @_;

        my @input_list = @$list_ref;

        my $hash = hash($hash_input);

        my $prng = Math::Random::ISAAC->new(hash($hash_input));

        my @output;
        while (@input_list) {
            my $idx = $prng->irand % scalar(@input_list);
            push @output, splice(@input_list, $idx, 1);
        }

        return @output;
    },
);

1;

=head1 SEE ALSO

L<rb3(1)>

=cut

__END__
