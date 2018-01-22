#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/trunk/lib/RB3/TemplateFunctions.pm $
# $LastChangedRevision: 15214 $
# $LastChangedDate: 2009-03-30 11:44:41 +0100 (Mon, 30 Mar 2009) $
# $LastChangedBy: tom $
#
package RB3::TemplateFunctions;

use strict;
use warnings FATAL => 'all';

use Carp;
use File::Basename;
use List::Util ();
use Net::DNS;
use Net::Netmask;
use Readonly;
use Socket qw(inet_ntoa inet_aton AF_INET);
use Sort::Fields ();

sub shuffle {
    List::Util::shuffle( @{ $_[0] } );
}

sub die_shuffle {
    die "Shuffle not enabled\n";
}

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
        }
        elsif ( $type eq 'MX' ) {
            my @mx = mx( $resolver, $hostname )
                or die "Query MX records for $hostname: " . $resolver->errorstring;
            map dnslookup($_->exchange), @mx;
        }
            else {
                die "Unrecognized type '$type' for DNS lookup\n";
            }
    }
}

our %functions =
    (
        hostname => sub {
            my $addr = inet_aton(shift);
            scalar gethostbyaddr( $addr, AF_INET );
        },

        dnslookup => \&dnslookup,

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
    );

1;

__END__
