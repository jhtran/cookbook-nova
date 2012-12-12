#
# Cookbook Name:: nova
# Recipe:: ceilometer-common
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

#include_recipe "mongodb"
#include_recipe "nova::nova-common"
include_recipe "python::pip"

ceilometer_packages = ['libxslt-dev', 'libxml2-dev']

ceilometer_packages.each do |pkg|
  package pkg do
    action :upgrade
  end
end

api_logdir = '/var/log/ceilometer-api'
#nova_owner = node["nova"]["user"]
#nova_group = node["nova"]["group"]
nova_owner = 'nova'
nova_group = 'nova'

#  Cleanup old installation
python_pip "ceilometer" do
  action :remove
end

bin_names = ['agent-compute', 'agent-central', 'collector', 'dbsync', 'api']
bin_names.each do |bin_name|
  file "ceilometer-#{bin_name}" do
    action :delete
  end
end


directory api_logdir do
  owner nova_owner
  group nova_group
  mode  00755

  action :create
end

tmpdir = Chef::Config[:file_cache_path] + '/ceilometer'

directory tmpdir do
  owner nova_owner
  group nova_group
  mode  00755

  action :create
end

directory "/etc/ceilometer" do
  owner nova_owner
  group nova_group
  mode  00755
  action :create
end

#rabbit_server_role = node["nova"]["rabbit_server_chef_role"]
#rabbit_info = get_settings_by_role rabbit_server_role, "queue"
#
#nova_setup_role = node["nova"]["nova_setup_chef_role"]
#nova_setup_info = get_settings_by_role nova_setup_role, "nova"
#
#db_user = node['nova']['db']['username']
#db_pass = nova_setup_info['db']['password']
#sql_connection = db_uri("compute", db_user, db_pass)
sql_connection = 'mysql://db_user:db_pass@localhost/nova'
#ceilometer_db_user = node['ceilometer']['db']['username']
#ceilometer_db_pass = db_pass
#ceilometer_db_connection = db_uri("ceilometer", ceilometer_db_user, ceilometer_db_pass)
ceilometer_db_connection = 'mysql://ceilometer:mypassword@localhost/ceilometer'

#keystone_service_role = node["nova"]["keystone_service_chef_role"]
#keystone = get_settings_by_role keystone_service_role, "keystone"

# find the node attribute endpoint settings for the server holding a given role
identity_admin_endpoint = endpoint "identity-admin"

#Chef::Log.debug("nova::nova-common:rabbit_info|#{rabbit_info}")
#Chef::Log.debug("nova::nova-common:keystone|#{keystone}")
#Chef::Log.debug("nova::nova-common:identity_admin_endpoint|#{identity_admin_endpoint.to_s}")

conf = "/etc/ceilometer/ceilometer.conf"

template conf do
  source "ceilometer.conf.erb"
  owner  nova_owner
  group  nova_group
  mode   00644
  variables(
    :sql_connection => sql_connection,
    #:rabbit_ipaddress => rabbit_info["host"],
    :rabbit_ipaddress => 'localhost',
    #:rabbit_port => rabbit_info["port"],
    :rabbit_port => 5672,
    #:user => keystone["admin_user"],
    :user => 'admin',
    #:tenant => keystone["users"][keystone["admin_user"]]["default_tenant"],
    :tenant => 'admin',
    #:password => keystone["users"][keystone["admin_user"]]["password"],
    :password => 'none',
    :identity_admin_endpoint => identity_admin_endpoint
    :database_connection => ceilometer_db_connection
  )
end

cookbook_file "/etc/ceilometer/policy.json" do
  source "policy.json"
  mode 0755
  owner nova_owner
  group nova_group
end

git tmpdir do
  repo "git://github.com/openstack/ceilometer.git"
  action :sync
end

python_pip tmpdir do
  action :install
end

bash "migration" do
  cwd tmpdir
  code <<-EOF
    ceilometer-dbsync --config-file=#{conf}
  EOF
end
