#
# Cookbook Name:: nova
# Recipe:: ceilometer-agent-central
#
# Copyright 2012, AT&T
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

class ::Chef::Recipe
  include ::Openstack
end

include_recipe "nova::ceilometer-common"

case node['platform']
when 'ubuntu'
  cookbook_file "/etc/init/ceilometer-agent-central.conf" do
    source "init_ceilometer-agent-central.conf"
    mode 0644
    owner node["nova"]["user"]
    group node["nova"]["group"]
  end
  
  link "/etc/init.d/ceilometer-agent-central" do
    to '/lib/init/upstart-job'
    action :create
  end
else
  # need to implement
end

bindir = '/usr/local/bin'
conf_switch = '--config-file /etc/ceilometer/ceilometer.conf'

service "ceilometer-agent-central" do
  case  node['platform']
  when 'ubuntu'
    service_name "ceilometer-agent-central"
    action [:enable, :start]
  else
    start_command "nohup #{bindir}/ceilometer-agent-central #{conf_switch} &"
  end
end
