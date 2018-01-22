#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.37/lib/RB3/CLI/Build.pm $
# $LastChangedRevision: 21931 $
# $LastChangedDate: 2013-09-17 11:40:44 +0100 (Tue, 17 Sep 2013) $
# $LastChangedBy: dom $
#
package RB3::CLI::Build;

use strict;

use warnings FATAL => 'all';

use File::Basename qw( basename dirname );
use File::Path;
use File::Spec;
use File::Spec::Functions; # imports catfile
use IO::File;
use IO::Pipe;
#use List::MoreUtils qw(uniq);
use POSIX qw( SIGINT WIFSIGNALED WTERMSIG WIFEXITED WEXITSTATUS );
use RB3::Config;
use RB3::File;
use RB3::FileGenerator;
use YAML;

sub cmd_build {
    my $class = shift;
    my $app_config = shift;

    RB3::FileGenerator->DryRun( 1 )
          if $app_config->get( "dry-run" );

    RB3::FileGenerator->Quiet( 1 )
          if $app_config->quiet;

    RB3::FileGenerator->Silent( 1 )
          if $app_config->silent;

    RB3::FileGenerator->Strict( 1 )
          if $app_config->strict;

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

    unless ( -d $hostdir ) {
        warn "Skipping $hostdir (not a directory)\n";
        return;
    }

    my $rb3 = RB3::Config->new( { system_dir => $hostdir } );

    unless ( -r $rb3->get_rb3_path ) {
        warn "Skipping $hostdir (no config.rb3)\n";
        return;
    }

    $rb3->read_config();

    my $u_outbase = $rb3->get_repovars_list->template_vars->{"output_base"};
    my $u_outdir = $rb3->get_repovars_list->template_vars->{"output_dir"};

    my $outdir = defined($u_outdir) ? $u_outdir :
      defined($u_outbase)
      ? File::Spec->catfile($u_outbase, basename($rb3->get_system_dir))
      : $rb3->get_system_dir;


    my $fg = RB3::FileGenerator->new( { params     => $rb3->get_parameter_list,
                                        system_dir => $outdir,
    } );

    my $u_hostname = $rb3->get_repovars_list->template_vars->{"hostname"};
    my $hostname = defined($u_hostname)
      ? $u_hostname
      : basename($rb3->get_system_dir);

    foreach my $file ( @{ $rb3->get_file_list } ) {
        my $source = $file->get_source
            or next;

        eval {
            $fg->generate( 
                $source, $file->get_dest, $file->get_ctmeta_path, 
                $file->get_parameter_list, $file->get_component, $app_config,
                $hostname,
            );
        };
        if ($@) {
            die "Error generating file.\n"
                . "  source: $source\n"
                . "  dest:   " . $file->get_dest . "\n"
                . "  system: $hostdir\n"
                . "  err:    $@"
                ;
       }
    }

    write_configtool_meta($rb3, $fg, $app_config);
    write_configtool_manifests($rb3, $fg, $app_config);
}

sub write_configtool_meta {
    my ($rb3, $filegen, $app_config) = @_;

    my @metapaths;

    SET_METAPATHS: {
        my $metapaths
            = $rb3->get_repovars_list->template_vars->{"configtool.meta"};

        if (defined($metapaths)) {
            ref($metapaths) eq 'ARRAY' 
                or die "template var 'configtool.meta' must be a list\n";

            for my $mp (@$metapaths) {
                my %props = RB3::Config::decode_path_notation($mp);
                push @metapaths, $filegen->repopath(
                    $props{component}, $props{dest}
                );
            }      
        }
        else {
            @metapaths = (
                File::Spec->catfile($rb3->get_root_dir, 'etc', 'configtool.meta')
            );
        }
    }

    for my $path (@metapaths) {
        mkpath(dirname($path), !$app_config->silent, 0755);

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

sub write_configtool_manifests {
    my ($rb3, $filegen, $app_config) = @_;

    my @mfpaths;

    SET_MANIFESTPATHS: {
        my $mfpaths
            = $rb3->get_repovars_list->template_vars->{"configtool.manifest"};

        if (defined($mfpaths)) {
            ref($mfpaths) eq 'ARRAY' 
                or die "template var 'configtool.manifest' must be a list\n";

            for my $mp (@$mfpaths) {
                my %props = RB3::Config::decode_path_notation($mp);
                push @mfpaths, $filegen->repopath(
                    $props{component}, $props{dest}
                );
            }
        }

        # If we want to generate the manifest in a default location for common
        # setups in future, the logic would go something like this (but
        # with proper component handling).

        # Reasoning: if there's a home component, manifest consumer
        # can probably write to their home directory but not /etc.  If
        # the only component is root, common case will be that the consumer 
        # of the manifest is running as root.
#       else {
             # Would need to uncomment "use List::MoreUtils" to get uniq.
#            my @comps = uniq(map { $_->get_component } @{$rb3->get_file_list};
#            if (grep { $_ eq 'home' } @comps) {
#                push @mfpaths, catfile(
#                    $rb3->get_root_dir, 'home/.configtool.manifest'
#                );
#            }
#            elsif (@comps == 1 and $comps[0] eq 'root') {
#                push @mfpaths, catfile(
#                    $rb3->get_root_dir, 'root/etc/configtool.manifest'
#                );
#            }
#        }
    }

    return unless @mfpaths;

    my @manifest_data;

    my @files = map { $_->[ 0 ] } sort { $a->[1] cmp $b->[1] }
            map { [ $_, $_->get_dest ] } @{ $rb3->get_file_list };

    foreach my $file ( @files ) {
        next if !$file->get_owner_explicitly_set
            and !$file->get_group_explicitly_set
            and !$file->get_mode_explicitly_set
            and !scalar(%{$file->get_extras});

        my %mfentry = (path => $file->get_ctmeta_path);
        $file->get_owner_explicitly_set and $mfentry{owner} = $file->get_owner;
        $file->get_group_explicitly_set and $mfentry{group} = $file->get_group;
        $file->get_mode_explicitly_set and $mfentry{mode} = $file->get_mode;

        %mfentry = (%mfentry, %{$file->get_extras});

        push @manifest_data, \%mfentry;
    }
    
    for my $path ( @mfpaths ) {
        mkpath(dirname($path), !$app_config->silent, 0755);

        my $ofh = IO::File->new( $path, O_RDWR|O_CREAT|O_TRUNC, 0644 )
            or die "open $path for writing: $!";

        print $ofh YAML::Dump(\@manifest_data);
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
