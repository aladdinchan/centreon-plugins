#
# Copyright 2019 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
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
# See the License for the specific language governing permissions and
# limitations under the License.
#

package centreon::common::cisco::smallbusiness::snmp::mode::components::temperature;

use strict;
use warnings;

my $mapping = {
    rlPhdUnitEnvParamTempSensorValue                  => { oid => '.1.3.6.1.4.1.9.6.1.101.53.15.1.10' },
    rlPhdUnitEnvParamTempSensorWarningThresholdValue  => { oid => '.1.3.6.1.4.1.9.6.1.101.53.15.1.12' },
    rlPhdUnitEnvParamTempSensorCriticalThresholdValue => { oid => '.1.3.6.1.4.1.9.6.1.101.53.15.1.13' },
};
my $oid_rlPhdUnitEnvParamEntry = '.1.3.6.1.4.1.9.6.1.101.53.15.1';

sub load {
    my ($self) = @_;
    
    push @{$self->{request}}, {
        oid => $oid_rlPhdUnitEnvParamEntry,
        start => $mapping->{rlPhdUnitEnvParamTempSensorValue}->{oid},
        end => $mapping->{rlPhdUnitEnvParamTempSensorCriticalThresholdValue}->{oid},
    };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking temperatures");
    $self->{components}->{temperature} = {name => 'temperatures', total => 0, skip => 0};
    return if ($self->check_filter(section => 'temperature'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_rlPhdUnitEnvParamEntry}})) {
        next if ($oid !~ /^$mapping->{rlPhdUnitEnvParamTempSensorValue}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_rlPhdUnitEnvParamEntry}, instance => $instance);
        
        next if ($self->check_filter(section => 'temperature', instance => $instance));
        $self->{components}->{temperature}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "temperature '%s' is %s degree centigrade [instance = %s]",
                $instance, $result->{rlPhdUnitEnvParamTempSensorValue}, $instance, 
            )
        );

        my ($exit, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'temperature', instance => $instance, value => $result->{rlPhdUnitEnvParamTempSensorValue});
        if ($checked == 0) {
            my $warn_th = ':' . $result->{rlPhdUnitEnvParamTempSensorWarningThresholdValue};
            my $crit_th = ':' . $result->{rlPhdUnitEnvParamTempSensorCriticalThresholdValue};
            $self->{perfdata}->threshold_validate(label => 'warning-temperature-instance-' . $instance, value => $warn_th);
            $self->{perfdata}->threshold_validate(label => 'critical-temperature-instance-' . $instance, value => $crit_th);

            $exit = $self->{perfdata}->threshold_check(
                value => $result->{rlPhdUnitEnvParamTempSensorValue}, 
                threshold => [
                    { label => 'critical-temperature-instance-' . $instance, exit_litteral => 'critical' },
                    { label => 'warning-temperature-instance-' . $instance, exit_litteral => 'warning' }
                ]
            );
            $warn = $self->{perfdata}->get_perfdata_for_output(label => 'warning-temperature-instance-' . $instance);
            $crit = $self->{perfdata}->get_perfdata_for_output(label => 'critical-temperature-instance-' . $instance);
        }
        
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Temperature '%s' is %s degree centigrade", $instance, $result->{rlPhdUnitEnvParamTempSensorValue}));
        }
        $self->{output}->perfdata_add(
            label => 'temp', unit => 'C',
            nlabel => 'hardware.temperature.celsius',
            instances => $instance,
            value => $result->{rlPhdUnitEnvParamTempSensorValue},
            warning => $warn,
            critical => $crit,
        );
    }
}

1;
