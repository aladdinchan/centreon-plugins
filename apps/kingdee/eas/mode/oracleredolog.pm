#
# Copyright 2019 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure      application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions     
# limitations under the License.
#
# Author : CHEN JUN , aladdin.china@gmail.com

package apps::kingdee::eas::mode::oracleredolog;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments =>
            {
            "urlpath:s"         => { name => 'url_path', default => "/easportal/tools/nagios/checkoracleredolog.jsp" },
            "datasource:s"      => { name => 'datasource' },
            "warning:s"         => { name => 'warning' },
            "critical:s"        => { name => 'critical' },
            });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{datasource}) || $self->{option_results}->{datasource} eq "") {
        $self->{output}->add_option_msg(short_msg => "Missing datasource name.");
        $self->{output}->option_exit();
    }
    $self->{option_results}->{url_path} .= "?ds=" . $self->{option_results}->{datasource};

    if (($self->{perfdata}->threshold_validate(label => 'warning', value => $self->{option_results}->{warning})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical', value => $self->{option_results}->{critical})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
        
    my $webcontent = $options{custom}->request(path => $self->{option_results}->{url_path});
	if ($webcontent !~ /^STATUS=CURRENT/mi) {
		$self->{output}->output_add(
			severity  => 'UNKNOWN',
			short_msg => "Cannot find oracle redolog status."
		);
		$self->{output}->option_exit();
	}
		
    my ($activecount, $inactivecount, $currentcount) = (0, 0, 0);
    $activecount = $1 if $webcontent =~ /^STATUS=ACTIVE\sCOUNT=(\d+)/mi ;
    $inactivecount = $1 if $webcontent =~ /^STATUS=INACTIVE\sCOUNT=(\d+)/mi ;
    $currentcount = $1 if $webcontent =~ /^STATUS=CURRENT\sCOUNT=(\d+)/mi ;
 
    my $exit = $self->{perfdata}->threshold_check(value => $inactivecount, threshold => [ 
                                                  { label => 'critical', 'exit_litteral' => 'critical' }, 
                                                  { label => 'warning', exit_litteral => 'warning' } ]);
    $self->{output}->output_add(severity => $exit, short_msg => sprintf("InactiveCount: %d", $inactivecount));
    $self->{output}->output_add(severity => "ok", short_msg => sprintf("ActiveCount: %d", $activecount));
    $self->{output}->output_add(severity => "ok", short_msg => sprintf("CurrentCount: %d", $currentcount));

    $self->{output}->perfdata_add(label => "InactiveCount", unit => '',
                                  value => sprintf("%d", $inactivecount),
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning'),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical'),
                                  );
    $self->{output}->perfdata_add(label => "ActiveCount", unit => '',
                                  value => sprintf("%d", $activecount));
    $self->{output}->perfdata_add(label => "CurrentCount", unit => '',
                                  value => sprintf("%d", $currentcount));

    $self->{output}->display();
    $self->{output}->exit();

}

1;

__END__

=head1 MODE

Check oracle redolog status .

=over 8

=item B<--urlpath>

Set path to get status page. (Default: '/easportal/tools/nagios/checkoracleredolog.jsp')

=item B<--datasource>

Specify the datasource name.

=item B<--warning>

Warning Threshold for INACTIVE count. 

=item B<--critical>

Critical Threshold for INACTIVE count. 

=back

=cut
