#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.25/lib/RB3/CLI/UpdateSSHKeys.pm $
# $LastChangedRevision: 16162 $
# $LastChangedDate: 2009-09-11 17:50:45 +0100 (Fri, 11 Sep 2009) $
# $LastChangedBy: tom $
#
package RB3::CLI::UpdateSSHKeys;

use strict;
use warnings FATAL => 'all';

use Digest::MD5 qw( md5_hex );
use File::Spec;
use File::Temp;
use IPC::Run qw( run );
use MIME::Base64 qw( decode_base64 );
use Readonly;
use YAML;

Readonly my @SSH_KEYSCAN  => qw( /usr/bin/ssh-keyscan -4 -T 5 -t );
Readonly my $SVN          => '/usr/bin/svn';
Readonly my $FINGERPRINTS => 'fingerprints.yml';

sub cmd_update_ssh_keys {
    my $class = shift;
    my $app_config = shift;

    my $dir = File::Spec->catdir( 'defaults', 'ssh_keys' );
    chdir( $dir )
        or die "chdir $dir: $!";

    my %is_referenced;

    my $fingerprints = read_fingerprints();

    foreach my $hostname ( keys %{ $fingerprints } ) {
        my $hostkeys = $fingerprints->{ $hostname };
        foreach my $keytype ( keys %{ $hostkeys } ) {
            my $fingerprint = $hostkeys->{ $keytype };
            $is_referenced{ $fingerprint } = 1;
            unless ( -f $fingerprint ) {
                fetch_key( $hostname, $keytype, $fingerprint )
                    and svn_add( $fingerprint );
            }
        }
    }

    foreach my $fingerprint ( glob( '??:??:??:??:??:??:??:??:??:??:??:??:??:??:??:??' ) ) {
        svn_delete( $fingerprint )
            unless $is_referenced{ $fingerprint };
    }
}

sub read_fingerprints {
    my $data = eval { YAML::LoadFile( $FINGERPRINTS ) };
    if ( $@ ) {
        die "error reading $FINGERPRINTS\n$@";
    }
    return $data->{ ssh_key_fingerprints };
}

sub fetch_key {
    my ( $hostname, $keytype, $fingerprint ) = @_;

    my $key = ssh_keyscan( $hostname, $keytype )
        or return;

    unless ( fingerprint_matches( $key, $fingerprint ) ) {
        warn "fingerprint mismatch for $hostname $keytype key\n";
        return;
    };

    my $tmp = File::Temp->new( DIR => '.' );
    $tmp->print( $key . "\n" )
        or die "error writing to temporary file: $!";
    $tmp->close()
        or die "error closing temporary file: $!";

    rename( $tmp->filename, $fingerprint )
        or die "error moving temporary file to $fingerprint";

    return 1;
}

sub ssh_keyscan {
    my ( $hostname, $keytype ) = @_;

    my @cmd = ( @SSH_KEYSCAN, $keytype, $hostname );

    my ( $out, $err );
    unless ( run( \@cmd, \undef, \$out, \$err ) and $out =~ s/^\Q$hostname\E\s+ssh-(rsa|dss)\s+// ) {
        warn "failed to retrieve $keytype key for $hostname: $err\n";
        return;
    }
    chomp( $out );

    return $out;
}

sub fingerprint_matches {
    my ( $base64_encoded_key, $expected_fingerprint ) = @_;
    my $digest = md5_hex( decode_base64( $base64_encoded_key ) );
    my $fingerprint = join( q{:}, unpack( 'a2'x16, $digest ) );
    $fingerprint eq $expected_fingerprint;
}

sub svn_add {
    my ( $path ) = @_;
    system( $SVN, 'add', $path ) == 0
        or die "failed to svn add $path";
}

sub svn_delete {
    my ( $path ) = @_;
    system( $SVN, 'delete', $path ) == 0
        or die "failed to svn delete $path";
}

1;

__END__
