#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.42/lib/RB3/CLI/Graph.pm $
# $LastChangedRevision: 26284 $
# $LastChangedDate: 2015-05-13 09:51:40 +0100 (Wed, 13 May 2015) $
# $LastChangedBy: ouit0139 $
#
package RB3::CLI::Graph;

use strict;

use warnings FATAL => 'all';

use File::Basename qw( basename dirname fileparse );
use File::Path qw( make_path );
use File::Spec;
use File::Spec::Functions;    # imports catfile
use IO::File;
use IO::Pipe;
use POSIX qw( SIGINT WIFSIGNALED WTERMSIG WIFEXITED WEXITSTATUS );
use RB3::Config;
use RB3::File;
use RB3::FileGenerator;
use YAML;
use List::MoreUtils qw/ uniq /;
use RB3::GraphViz;

my $rb3_colour        = 'blue';
my $copied_colour     = 'green';
my $yaml_colour       = 'red';
my $template_colour   = 'black';
my $suppressed_colour = 'gray';
my $rb3_shape         = 'ellipse';
my $copied_shape      = 'box';
my $yaml_shape        = 'box';
my $template_shape    = 'box';
my $suppressed_shape  = 'box';

sub cmd_graph {
    my $class           = shift;
    my $app_config      = shift;
    my $template_source = 1;
    my $copied          = 1;
    my $deep            = 0;
    my $params          = 1;
    if ( $app_config->graph_no_copied_files ) {
        $copied = 0;
    }
    if ( $app_config->graph_no_template_source ) {
        $template_source = 0;
    }
    if ( $app_config->graph_deep ) {
        $deep            = 1;
        $template_source = 1;
        $copied          = 1;
    }
    if ( $app_config->graph_no_params ) {
        $params = 0;
    }
    foreach my $name (@_) {
        my $OUTPUT;
        if ( substr( $name, -1 ) eq '/' ) {
            $name = substr( $name, 0, -1 );
        }
        my $config_file = "$name/config.rb3";
        unless ( -f $config_file ) {
            warn "No config.rb3 in $name (is it a system directory?)\n";
            next;
        }
        my $directory = $name . "/export/";
        if ( $app_config->graph_output_directory ) {
            $directory = $app_config->graph_output_directory;
        }
        my $filename = "system_graph.dot";
        if ( $app_config->graph_output_filename ) {
            $filename = $app_config->graph_output_filename;
        }
        my $full_path = $directory . $filename;
        my ( $file, $directories ) = fileparse $full_path;
        if ( !-d $directories ) {
            make_path $directories
                or die "Failed to create path: $directories";
        }
        warn "Building tree for $name\n" unless $app_config->silent;
        my $graph_name = basename($name);
        $graph_name =~ s/\..*//;
        $graph_name =~ s/-/_/g;
        my $graph = RB3::GraphViz->new(
            name        => "$graph_name",
            layout      => 'dot',
            rankdir     => 1,
            concentrate => 1,
            graph => { splines => 'ortho', nodestep => 0.3, mclimit => 24 },
            node => { fontname => "Courier-Bold", fontsize => 14 }
        );
        process_file( $config_file, $graph, $copied, $params,
            $template_source, $deep );
        open( $OUTPUT, ">$full_path" );
        print $OUTPUT $graph->as_debug;
        close($OUTPUT);
    }
}

sub add_node_and_edge {
    my $graph  = shift;
    my $target = shift;
    my $source = shift;
    my $colour = shift;
    my $shape  = shift;
    my $invert = shift;
    my $rank   = shift;
    if ($rank) {
        $graph->add_node( $target, color => $colour, shape => $shape, rank => $rank );
    }
    else {
        $graph->add_node( $target, color => $colour, shape => $shape );
    }
    if ($invert == 1) {
        $graph->add_edge( $target => $source, color => $colour );
    }
    else {
        $graph->add_edge( $source => $target, color => $colour );
    }
}

sub process_file {
    my $parent   = shift;
    my $graph    = shift;
    my $copied   = shift;
    my $yaml     = shift;
    my $template = shift;
    my $deep     = shift;

    $graph->add_node( $parent, color => $rb3_colour, shape => $rb3_shape, rank => $parent );
    my $PARENT;
    open( $PARENT, "<", $parent );
    while (my $line = <$PARENT>) {
        next if $line =~ /^#/;

        #  handle line splicing in rb3 files
        while ($line =~ s/\\\s*$//) {
            $line .= <$PARENT>;
        }

        chomp($line);
        if ( ( substr( $line, 0, 1 ) eq "+" ) && ( $copied == 1 ) ) {
            $line = substr( $line, 1 );
            $line =~ s/\t/ /g;
            my @words = split( / /, $line );
            my $file = $words[0];
            if ( $template == 1 ) {
                shift @words;
                while (@words) {
                    if ( $words[0] =~ /\// ) {
                        last;
                    }
                    else {
                        shift @words;
                    }
                }
                if ( substr( $words[0], 0, 1 ) eq "!" ) {
                    $words[0] = substr( $words[0], 1 );
                    add_node_and_edge( $graph, $words[0], $file, $yaml_colour,
                        $yaml_shape, 0 );
                }
                else {
                    process_template( $words[0], $parent, $graph, $deep );
                }
                add_node_and_edge( $graph, $file, $words[0], $copied_colour,
                    $copied_shape, 0, "output" );
                add_node_and_edge( $graph, $file, $parent, $copied_colour,
                    $copied_shape, 0, "output" );
            }
	    else {
                add_node_and_edge( $graph, $file, $parent, $copied_colour,
                    $copied_shape, 0, "output" );
            }
        }
        elsif ( ( substr( $line, 0, 1 ) eq "-" ) && ( $copied == 1 ) ) {
            $line = substr( $line, 1 );
            add_node_and_edge( $graph, $line, $parent, $suppressed_colour,
                $suppressed_shape, 0, "output" );
        }
        elsif ( ( substr( $line, 0, 1 ) eq "!" ) && ( $yaml == 1 ) ) {
            $line = substr( $line, 1 );
            add_node_and_edge( $graph, $line, $parent, $yaml_colour,
                $yaml_shape, 0, $parent );
        }
        elsif ( substr( $line, 0, 1 ) eq "=" ) {
            $line = substr( $line, 1 );
            $graph->add_edge( $parent => $line, color => $rb3_colour );
            process_file( $line, $graph, $copied, $yaml, $template, $deep );
        }
    }
}

sub process_template {
    my $template = shift;
    my $parent   = shift;
    my $graph    = shift;
    my $deep     = shift;
    my $process  = shift;
    if ($process) {
      add_node_and_edge( $graph, $template, $parent, $template_colour,
          $template_shape, 0, "PROCESS" );
    }
    else {
      add_node_and_edge( $graph, $template, $parent, $template_colour,
          $template_shape, 0, "SRC" );
    }
    if ( !$deep ) {
        return;
    }
    my $TEMPLATE;
    open( $TEMPLATE, "<", $template );
    while (my $tline = <$TEMPLATE>) {
        next if $tline =~ /^#/;
        next if $tline !~ /PROCESS\s+/;
        next if $tline !~ /\//;
        next if $tline =~ /\$/;
        my @line   = split(/PROCESS\s+/, $tline);
        my @tmp    = split( /;/, $line[1] );
        my @string = split( / /, $tmp[0] );
        my $filename;

        if ( substr( $string[0], 0, 1 ) eq '"' ) {
            my @file = split( /"/, $string[0] );
            $filename = $file[1];
        }
        elsif ( substr( $string[0], 0, 1 ) eq "'" ) {
            my @file = split( /'/, $string[0] );
            $filename = $file[1];
        }
        else {
            $filename = $string[0];
        }
        chomp($filename);
        next if ( $filename eq $template );
        process_template( $filename, $template, $graph, $deep, 1 );
    }
}

1;

__END__
