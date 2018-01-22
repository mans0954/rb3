#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.27/lib/RB3/CLI/Build.pm $
# $LastChangedRevision: 17167 $
# $LastChangedDate: 2010-04-20 17:45:17 +0100 (Tue, 20 Apr 2010) $
# $LastChangedBy: tom $
#
package RB3::CLI::Build;

use strict;
use warnings FATAL => 'all';

use File::Basename qw( basename dirname );
use File::Path;
use File::Spec;
use IO::File;
use IO::Pipe;
use POSIX qw( SIGINT WIFSIGNALED WTERMSIG WIFEXITED WEXITSTATUS );
use RB3::Config;
use RB3::File;
use RB3::FileGenerator;

sub cmd_build {
    my $class = shift;
    my $app_config = shift;

    RB3::FileGenerator->DryRun( 1 )
          if $app_config->get( "dry-run" );

    RB3::FileGenerator->Quiet( 1 )
          if $app_config->quiet;

    RB3::FileGenerator->Silent( 1 )
          if $app_config->silent;

    my $max_jobno = $app_config->jobs - 1;

    # We'll rely on autovivification of arrayrefs inside @bkts later.
    my @bkts;
    my @children;

    for ( my $i = 0; $i < @_; $i++ ) {
        push @{ $bkts[ $i % $app_config->jobs ] }, $_[$i];
    }
    
    my $bkt;
    my @failhandles;

    FORK: for ( $bkt = 0; $bkt < $app_config->jobs; $bkt++ ) {

        my $failpipe = IO::Pipe->new;

        my $pid = fork;

        if( $pid ) {
            push @children, $pid;
            $failpipe->reader;
            push @failhandles, $failpipe;
            next FORK;
        }
        elsif( $pid == 0 ) {
            $failpipe->writer;

            $SIG{INT} = sub {
                File::Temp::cleanup();
                exit(1);
            };

            foreach my $sys ( @{ $bkts[$bkt] } ) {
                warn "Building configuration for $sys\n"
                    unless $app_config->silent;

                eval { build_host_config( $app_config, $sys ) } ;
                if( $@ ) {
                    print STDERR $@;
                    print $failpipe $sys . chr(0);
                }
            }
            exit 0;
        }
        elsif( not defined $pid ) {
            my $err = $!;
            reap_children([@failhandles]);
            die "fork failed: $err\n";
        }
    }

    reap_children([@failhandles]);
}

sub build_host_config {
    my ( $app_config, $hostdir ) = @_;

    my $rb3 = RB3::Config->new( { system_dir => $hostdir } );

    unless ( -r $rb3->get_rb3_path ) {
        warn "Skipping $hostdir (no config.rb3)\n";
        return;
    }

    $rb3->read_config();

    my $fg = RB3::FileGenerator->new( { params     => $rb3->get_parameter_list,
                                        system_dir => $rb3->get_system_dir } );

    foreach my $file ( @{ $rb3->get_file_list } ) {
        my $source = $file->get_source
            or next;
        $fg->generate( $source, $file->get_dest, $file->get_ctmeta_path, $file->get_parameter_list, $file->get_component );
    }

    write_configtool_meta( $rb3 );
}

sub write_configtool_meta {
    my $rb3 = shift;

    my @metapaths;

    SET_METAPATHS: {
        my $metapaths
            = $rb3->get_repovars_list->template_vars->{"configtool.meta"};
        if (defined($metapaths)) {
            ref($metapaths) eq 'ARRAY' 
                or die "template var 'configtool.meta' must be a list\n";

            @metapaths = @$metapaths;
        }
        else {
            @metapaths = (
                File::Spec->catfile($rb3->get_root_dir, 'etc', 'configtool.meta')
            );
        }
    }

    for my $path (@metapaths) {
        mkpath(dirname($path), 1, 0755);

        my $ofh = IO::File->new( $path, O_RDWR|O_CREAT|O_TRUNC, 0644 )
            or die "open $path for writing: $!";


        my @files = map { $_->[ 0 ] } sort { $a->[1] cmp $b->[1] }
            map { [ $_, $_->get_dest ] } @{ $rb3->get_file_list };

        foreach my $file ( @files ) {
            next if $file->get_owner eq RB3::File->DefaultOwner
                and $file->get_group eq RB3::File->DefaultGroup
                    and oct( $file->get_mode ) == oct( RB3::File->DefaultMode );
            $ofh->printf(
                "%s %s %s 0%o\n",
                (map { $file->$_ } qw( get_ctmeta_path get_owner get_group )), 
                oct( $file->get_mode )
            );
        }
    }
}

sub reap_children {
    my ($failpipes) = @_;

    my $ex = 0;

    my @failed_systems;

    # unfortunately not settable on a per-filehandle scope
    $/ = chr(0);

    for my $failpipe ( @$failpipes ) {
        while( my $fail = <$failpipe> ) {
            chomp $fail;
            push @failed_systems, $fail;
        }
    }

    $/ = "\n";

    if( @failed_systems ) {
        warn(
            "system dirs failing to build:\n"
                . join("", map { "$_\n" } @failed_systems)
        );
        $ex = 1;
    }

    my $errors = 0;

    CHILD: while( my $child = wait ) {
        $child == -1 and last CHILD;

        if( WIFSIGNALED( $? ) ) {
            warn "child $child died with signal " . WTERMSIG( $? ) . "\n";
            $errors++;
        }
        elsif( WIFEXITED( $? ) and WEXITSTATUS( $? ) != 0 ) {
            warn "child $child exited with value " . WEXITSTATUS( $? ) . "\n";
            $errors++;
        }
    }

    if( $errors ) {
        warn "children not exiting successfully: $errors\n";
        $ex = 1;
    }

    $ex and exit( $ex );
}

1;

__END__
