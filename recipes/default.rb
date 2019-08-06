# frozen_string_literal: true

require 'openssl'

package %w(tinc bridge-utils)
# prepared for later multi-network per host deployments, not implemented yet

service 'tinc' do
  action [ :enable, :start ]
end

# We want to override the options passed to `tincd` and include the --logfile
# option
template '/etc/default/tinc' do
  source 'tinc.default.erb'
  mode '0644'
  notifies :restart, 'service[tinc]'
end

# Avoids creating the `default` network from default attributes when using a
# custom network instead.
# The "default" network alone should not be deleted at all.
if Array(node['tincvpn']['networks']).size > 1
  default_network = node['tincvpn']['networks']['default']
  if default_network # If there is a "default" network in the attributes
    avahi_enabled = default_network['host'] && \
                    default_network['host']['avahi_zeroconf_enabled'] \
                    || false
    default_host_subnets = Array(default_network['host']['subnets'])
    # Removes the "default" network if it exists, is not alone, and
    # has the Avahi to false and the subnets is empty
    if avahi_enabled == false && default_host_subnets.empty?
      Chef::Log.warn 'Removing the "default" network from attributes has ' \
                     "it doesn't seem to be used."
      node.rm('tincvpn', 'networks', 'default')
    end
  end
end

# For each tinc network which has been define on that node,
# create the configuration for each and find all other nodes( peers ) using
# chef-search, which do have the same networks, and create hosts files
# on this node for those with their public key so they can actually connect
# to each other
node['tincvpn']['networks'].each do |network_name, network|
  network_mode = network['network'] && network['network']['mode']
  network_mode ||= 'router' # Default tinc mode value

  if !Array(network['host']['subnets']).empty? && network_mode == 'switch'
    raise 'You defined switch as your mode, but also defined subnets - ' \
          'this is now allowed by tinc'
  end

  directory "/etc/tinc/#{network_name}"
  directory "/etc/tinc/#{network_name}/hosts"

  if network['host']['name'] && network['host']['name'] != node['hostname']
    Chef::Log.warn(
      "The hostname #{network['host']['name'].inspect} from tincvpn " \
      "attributes differs with node's hostname " \
      "(#{node['hostname'].inspect})."
    )
  end

  local_host_name = network['host']['name'] || node['hostname']
  local_host_name = local_host_name.gsub('-', '_')

  local_host_path = "/etc/tinc/#{network_name}/hosts/#{local_host_name}"
  priv_key_location = "/etc/tinc/#{network_name}/rsa_key.priv"

  avahi_zeroconf_enabled = network['host']['avahi_zeroconf_enabled']

  if avahi_zeroconf_enabled
    package %w(avahi-daemon avahi-utils avahi-autoipd)

    service 'avahi-daemon' do
      action [ :enable, :start ]
    end
  end

  # we use the tinc tool to generate the priv and public key, since openssl
  # with public key is kind of complicated with chef we remove the tinc.conf
  # before we generate, since otherwise the public key will not be saved in
  # /etc/tinc/#{network_name}/rsa_key.pub but rather in
  # the hosts/<localname> file - and we do not want that for
  # simplicity of extraction
  execute "generate-#{network_name}-keys" do
    command "rm -f #{local_host_path} && rm -f /etc/tinc/#{network_name}/tinc.conf && (yes | tincd  -n #{network_name} -K4096)"
    creates priv_key_location
    notifies :run, "ruby_block[publish-public-key-#{network_name}]", :immediately
    not_if { File.exist?(priv_key_location) }
  end

  # local host entry in hosts/
  # thats basically "us in the hosts file" - this is needed and mandaory
  # Takes the host address from the attributes if defined, otherwise takes
  # the automatic fqdn attribute (ohai)
  host_addr = network['host']['address'] || node['fqdn']
  template local_host_path do
    source 'host.erb'
    variables(
      pub_key: lazy { File.read("/etc/tinc/#{network_name}/rsa_key.pub") },
      address: host_addr,
      port: network['network'] && network['network']['port'] || 655,
      subnets: avahi_zeroconf_enabled ? [] : network['host']['subnets']
    )
  end

  # a ruby block is used to ensure order of execution - so in the case
  # "generate-#{network_name}-keys" needs to be run first
  ruby_block "publish-public-key-#{network_name}" do
    block do
      node.normal['tincvpn']['networks'][network_name]['host']['pubkey'] = File.read("/etc/tinc/#{network_name}/rsa_key.pub")
    end
    action :nothing
  end

  # tinc up/down - mainly defining our tunnel network and our tunnel network
  # address
  %w[up down].each do |action|
    template "/etc/tinc/#{network_name}/tinc-#{action}" do
      source "tinc-#{action}.erb"
      mode '0755'
      variables(
        tunnel_address: network['network'] && network['network']['tunneladdr'],
        tunnel_netmask: network['network'] && network['network']['tunnelnetmask'],
        avahi_zeroconf_enabled: avahi_zeroconf_enabled
      )
      notifies :reload, 'service[tinc]', :delayed
    end
  end

  ##########################################################################
  # put all the remote hosts in place we can connect to,
  # search for the nodes in chef
  ##########################################################################
  # all the remote hosts
  hosts_connect_to = []
  # any other node having a public key and joined the same network
  peers = search(:node, "tincvpn_networks_#{network_name}_host_pubkey:*")

  peers.each do |peer|
    host_name = peer['hostname']

    # Skip if the node found is actually the node we run on,
    # since that host file has been written already above
    # and the values in the search would be outdated anyway
    next if host_name == local_host_name

    # check which hosts this peers defined to connect to
    defined_connect_to = network['host']['connect_to']

    # Filter hosts we did not want to connect to on this peer
    # (if the whitelist exists)
    next if !Array(defined_connect_to).empty? && !Array(defined_connect_to).include?(host_name)

    host_addr = peer['fqdn']
    host_addr = peer['tincvpn']['networks'][network_name]['host']['address'] unless peer['tincvpn']['networks'][network_name]['host']['address'].nil?
    host_pubkey = peer['tincvpn']['networks'][network_name]['host']['pubkey']

    host_port = peer['tincvpn']['networks'][network_name]['network'] && peer['tincvpn']['networks'][network_name]['network']['port'] || 655
    template "/etc/tinc/#{network_name}/hosts/#{host_name.gsub('-', '_')}" do
      source 'host.erb'
      variables(
        address: host_addr,
        pub_key: host_pubkey,
        port: host_port,
        subnets: avahi_zeroconf_enabled ? [] : peer['tincvpn']['networks'][network_name]['host']['subnets']
      )
      notifies :reload, 'service[tinc]', :delayed
    end

    # add all hosts to our connectTo list, except ourselfs
    hosts_connect_to << host_name.gsub('-', '_')
  end

  ##########################################################################
  # deploy our node network configuration
  ##########################################################################
  template "/etc/tinc/#{network_name}/tinc.conf" do
    source 'tinc.conf.erb'
    variables(
      name: local_host_name,
      port: network['network'] && network['network']['port'] || 655,
      interface: network['network'] && network['network']['interface'],
      hosts_connect_to: hosts_connect_to,
      mode: avahi_zeroconf_enabled ? 'switch' : network_mode
    )
    notifies :reload, 'service[tinc]', :delayed
  end

  # We need this for systemd configuration starting from debian-stretch
  # /etc/tinc/nets.boot are no longer working / is ignored, see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=841052#27
  if node['platform'] == 'debian'
    version = shell_out('cat /etc/os-release | grep "VERSION="').stdout
    codename = version.scan(/\d+\s\(([a-z]+)\)/).flatten.first

    if codename == 'stretch'
      service "tinc@#{network_name}" do
        action [ :enable, :start ]
      end
    end
  end
end

# finally let our networks boot
template '/etc/tinc/nets.boot' do
  source 'nets.boot.erb'
  variables(
    networks: node['tincvpn']['networks'].keys
  )
  notifies :restart, 'service[tinc]', :immediately
end
