#
# $HeadURL: https://svn.oucs.ox.ac.uk/sysdev/src/packages/r/rb3/tags/1.42/lib/RB3/Desc.pm $
# $LastChangedRevision: 11642 $
# $LastChangedDate: 2007-11-29 13:40:39 +0000 (Thu, 29 Nov 2007) $
# $LastChangedBy: ray $
#
package RB3::Desc;

use strict;
use warnings FATAL => 'all';

use Carp qw( croak );
use Class::Std;
use File::Spec;
use YAML;

{
    my %control_of        :ATTR( :name<control>        :default<> );
    my %cpu_of            :ATTR( :name<cpu>            :default<> );
    my %debian_version_of :ATTR( :name<debian_version> :default<> );
    my %description_of    :ATTR( :name<description>    :default<> );
    my %hostname_of       :ATTR( :name<hostname>       :default<> );
    my %hwinfo_of         :ATTR( :name<hwinfo>         :default<> );
    my %memory_of         :ATTR( :name<memory>         :default<> );
    my %interfaces_of     :ATTR( :name<interfaces>     :default<> );
    my %uname_of          :ATTR( :name<uname>          :default<> );
    my %vmstatlog_of      :ATTR( :name<vmstatlog>      :default<> );

    sub is_active {
        my $self = shift;
        my $control = $self->get_control;
        return 1
            if $control->{ active } and $control->{ active } eq 'true';
        return;
    }

    sub is_autoupdate {
        my $self = shift;
        my $control = $self->get_control;
        return 1
            if $control->{ autoupdate } and $control->{ autoupdate } eq 'true';
        return;
    }
}

1;

__END__
