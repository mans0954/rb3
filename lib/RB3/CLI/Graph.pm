#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.40/lib/RB3/CLI/Graph.pm $
# $LastChangedRevision: 22774 $
# $LastChangedDate: 2014-01-20 16:38:35 +0000 (Mon, 20 Jan 2014) $
# $LastChangedBy: ouit0139 $
#
package RB3::CLI::Graph;

use strict;

use warnings FATAL => 'all';

use File::Basename qw( basename dirname fileparse );
use File::Path qw( make_path );
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
use List::MoreUtils qw/ uniq /;

sub cmd_graph_complete
{
    my $class = shift;
    my $app_config = shift;
    foreach my $name (@_)
    {
        my $OUTPUT;
        my @DATA;
        if ( substr($name, -1) eq '/')
	{
	    $name = substr($name, 0, -1);
	}
        my $config_file = "$name/config.rb3";
        die "No config.rb3 in $name (is it a system directory?)\n"
            unless( -f $config_file );

        my $full_path=$name . "/export/system_complete_graph.dot";
        my ( $file, $directories ) = fileparse $full_path;
        if ( !-d $directories )
        {
            make_path $directories
                or die "Failed to create path: $directories";
        }
        open($OUTPUT, ">$full_path");
        print "complete tree for $name\n" unless $app_config->quiet;
        print $OUTPUT 'digraph "' . $name . '"' . " {\n";
        print $OUTPUT 'node[fontname="Courier-Bold", fontsize=14]' . "\n";
        print $OUTPUT "rankdir = LR\n";
        print $OUTPUT "mclimit=24\n";
        process_file($config_file, \@DATA, 1, 1);
        my @unique = uniq @DATA;
        foreach (@unique)
        {
            print $OUTPUT $_;
        }
        print $OUTPUT "}\n";
        close($OUTPUT);
    }
}

sub cmd_graph_rb3_only
{
    my $class = shift;
    my $app_config = shift;
    foreach my $name (@_)
    {
        my $OUTPUT;
        my @DATA;
        my $config_file = "$name/config.rb3";
        die "No config.rb3 in $name (is it a system directory?)\n"
            unless( -f $config_file );

        my $full_path=$name . "/export/system_rb3_only_graph.dot";
        my ( $file, $directories ) = fileparse $full_path;
        if ( !-d $directories )
        {
            make_path $directories
                or die "Failed to create path: $directories";
        }
        open($OUTPUT, ">$full_path");
        print "rb3 tree for $name\n" unless $app_config->quiet;
        print $OUTPUT 'digraph "' . $name . '"' . " {\n";
        print $OUTPUT 'node[fontname="Courier-Bold", fontsize=14]' . "\n";
        print $OUTPUT "rankdir = LR\n";
        print $OUTPUT "mclimit=24\n";
        process_file($config_file, \@DATA, 0, 0);
        my @unique = uniq @DATA;
        foreach (@unique)
        {
            print $OUTPUT $_;
        }
        print $OUTPUT "}\n";
        close($OUTPUT);
    }
}

sub cmd_graph_copied_files
{
    my $class = shift;
    my $app_config = shift;
    foreach my $name (@_)
    {
        my $OUTPUT;
        my @DATA;
        my $config_file = "$name/config.rb3";
        die "No config.rb3 in $name (is it a system directory?)\n"
            unless( -f $config_file );

        my $full_path=$name . "/export/system_copied_files_graph.dot";
        my ( $file, $directories ) = fileparse $full_path;
        if ( !-d $directories )
        {
            make_path $directories
                or die "Failed to create path: $directories";
        }
        open($OUTPUT, ">$full_path");
        print "copied files tree for $name\n" unless $app_config->quiet;
        print $OUTPUT 'digraph "' . $name . '"' . " {\n";
        print $OUTPUT 'node[fontname="Courier-Bold", fontsize=14]' . "\n";
        print $OUTPUT "rankdir = LR\n";
        print $OUTPUT "mclimit=24\n";
        process_file($config_file, \@DATA, 1, 0);
        my @unique = uniq @DATA;
        foreach (@unique)
        {
            print $OUTPUT $_;
        }
        print $OUTPUT "}\n";
        close($OUTPUT);
    }
}

sub cmd_graph_params
{
    my $class = shift;
    my $app_config = shift;
    foreach my $name (@_)
    {
        my $OUTPUT;
        my @DATA;
        my $config_file = "$name/config.rb3";
        die "No config.rb3 in $name (is it a system directory?)\n"
            unless( -f $config_file );

        my $full_path=$name . "/export/system_params_graph.dot";
        my ( $file, $directories ) = fileparse $full_path;
        if ( !-d $directories )
        {
            make_path $directories
                or die "Failed to create path: $directories";
        }
        open($OUTPUT, ">$full_path");
        print "yml file tree for $name\n" unless $app_config->quiet;
        print $OUTPUT 'digraph "' . $name . '"' . " {\n";
        print $OUTPUT 'node[fontname="Courier-Bold", fontsize=14]' . "\n";
        print $OUTPUT "rankdir = LR\n";
        print $OUTPUT "mclimit=24\n";
        process_file($config_file, \@DATA, 0, 1);
        my @unique = uniq @DATA;
        foreach (@unique)
        {
            print $OUTPUT $_;
        }
        print $OUTPUT "}\n";
        close($OUTPUT);
    }
}

sub process_file
{
    my $parent = shift;
    my $DATA_REF = shift;
    my $c = shift;
    my $y = shift;
    push(@$DATA_REF, '"' . $parent . '" [color=blue]' . "\n");
    my $PARENT;
    open($PARENT, "<", $parent);
    while(<$PARENT>)
    {
        next if /^#/;
        $_ .= <$PARENT> while s/\\\n// and not eof;
        my $line = $_;
        chomp($line);
        if ((substr($line, 0, 1) eq "+") && ($c == 1))
        {
            $line = substr($line, 1);
            push(@$DATA_REF, '"' . $line . '" [shape=box color=green]' . "\n");
            push(@$DATA_REF, '"' . $parent . '" -> "' . $line . '"' . "\n");
        }
        elsif ((substr($line, 0, 1) eq "!") && ($y == 1))
        {
            $line = substr($line, 1);
            push(@$DATA_REF, '"' . $line . '" [shape=box color=red]' . "\n");
            push(@$DATA_REF, '"' . $parent . '" -> "' . $line . '"' . "\n");
        }
        elsif (substr($line, 0, 1) eq "=")
        {
            $line = substr($line, 1);
            push(@$DATA_REF, '"' . $parent . '" -> "' . $line . '"' . "\n");
            process_file($line, $DATA_REF, $c, $y);
        }
    }
}


1;

__END__
