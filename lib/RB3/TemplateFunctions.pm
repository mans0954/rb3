#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.25/lib/RB3/TemplateFunctions.pm $
# $LastChangedRevision: 17157 $
# $LastChangedDate: 2010-04-20 14:29:26 +0100 (Tue, 20 Apr 2010) $
# $LastChangedBy: dom $
#
package RB3::TemplateFunctions;

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
            return @results
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

our %functions = (
    hostname => sub {
        my $addr = inet_aton(shift);
        scalar gethostbyaddr( $addr, AF_INET );
    },

    dnslookup => \&dnslookup,
    store_netmask_in_table => \&store_netmask_in_table,
    find_netmask_in_table => \&find_netmask_in_table,

    ipaddr => sub { ipaddr( shift ) },

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

__END__
