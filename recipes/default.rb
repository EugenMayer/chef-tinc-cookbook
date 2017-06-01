require 'openssl'

package %w(tinc bridge-utils)
# prepared for later multi-network per host deployments, not implemented yet

service 'tinc' do
  action [ :enable, :start ]
end

# we want to override the options passed to `tincd` and include the --logfile option
template '/etc/default/tinc' do
  source 'tinc.default.erb'
  mode 0644
  notifies :restart, 'service[tinc]'
end


node['tincvpn']['networks'].each do |network_name, network|
  raise "You need to set the host name for the tinc network #{network_name} in ['tincvpn']['networks'][#{network_name}]['network']['host'][:name]" if network['host']['name'].nil?

  directory "/etc/tinc/#{network_name}"
  directory "/etc/tinc/#{network_name}/hosts"
  local_host_name = node['tincvpn']['networks'][network_name]['host'][:name]
  local_host_path = "/etc/tinc/#{network_name}/hosts/#{local_host_name}"
  priv_key_location = "/etc/tinc/#{network_name}/rsa_key.priv"

  execute "generate-#{network_name}-keys" do
    command "rm -f #{local_host_path} && rm -f /etc/tinc/#{network_name}/tinc.conf && (yes | tincd  -n #{network_name} -K4096)"
    creates priv_key_location
    notifies :run, "ruby_block[publish-public-key-#{network_name}]", :immediately
    not_if { File.exist?(priv_key_location) }
  end

  # local host entry in hosts/
  host_addr = node['fqdn']
  host_addr = node['tincvpn']['networks'][network_name]['host']['address'] unless node['tincvpn']['networks'][network_name]['host']['address'].nil?
  template local_host_path do
    source 'host.erb'
    variables(
      pub_key: lazy { File.read("/etc/tinc/#{network_name}/rsa_key.pub") },
      address: host_addr,
      port: node['tincvpn']['networks'][network_name]['network']['port'],
      subnets: node['tincvpn']['networks'][network_name]['host']['subnets']
    )
  end

  ruby_block "publish-public-key-#{network_name}" do
    block do
      node.set['tincvpn']['networks'][network_name]['host']['pubkey'] = File.read("/etc/tinc/#{network_name}/rsa_key.pub")
    end
    action :nothing
  end

  # tinc up/down
  %w{up down}.each do |action|
    template "/etc/tinc/#{network_name}/tinc-#{action}" do
      source "tinc-#{action}.erb"
      mode '0755'
      variables(
        tunnel_address: network['network']['tunneladdr'],
        tunnel_netmask: network['network']['tunnelnetmask'],
      )
      notifies :reload, 'service[tinc]', :delayed
    end
  end

  ########################################################################################
  ######## put all the hosts in place we can connect to, search for the nodes in chef
  ########################################################################################
  # all the remote ones
  hosts_connect_to = []
  peers = search(:node, "tincvpn_networks_#{network_name}_host_pubkey:*")

  peers.each do |peer|
    host_name = peer['tincvpn']['networks'][network_name]['host'][:name]
    defined_connect_to = node['tincvpn']['networks'][network_name]['host']['connect_to']

    # should we connect to the host
    next if defined_connect_to.length && !defined_connect_to.include?(host_name)

    host_addr = peer['fqdn']
    host_addr = peer['tincvpn']['networks'][network_name]['host']['address'] unless peer['tincvpn']['networks'][network_name]['host']['address'].nil?
    host_pubkey = peer['tincvpn']['networks'][network_name]['host']['pubkey']

    template "/etc/tinc/#{network_name}/hosts/#{host_name}" do
      source 'host.erb'
      variables(
        address: host_addr,
        pub_key: host_pubkey,
        port: peer['tincvpn']['networks'][network_name]['network']['port'],
        subnets: peer['tincvpn']['networks'][network_name]['host']['subnets']
      )
      notifies :reload, 'service[tinc]', :delayed
    end

    hosts_connect_to << host_name
  end

  ########################################################################################
  ######## put all the hosts in place we can connect to, search for the nodes in chef deploy our network configs
  ########################################################################################
  template "/etc/tinc/#{network_name}/tinc.conf" do
    source 'tinc.conf.erb'
    variables(
      name: network['host']['name'],
      port: network['network']['port'],
      hosts_connect_to: hosts_connect_to,
      mode: network['network']['mode'],
    )
    notifies :reload, 'service[tinc]', :delayed
  end
end

# finally let our networks boot
template '/etc/tinc/nets.boot' do
  source 'nets.boot.erb'
  variables(
    networks: node['tincvpn']['networks'].keys
  )
  notifies :restart, 'service[tinc]', :delayed
end

