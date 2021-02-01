# frozen_string_literal: true

require 'ipaddress'
require 'openssl'

package %w(tinc bridge-utils)
# prepared for later multi-network per host deployments, not implemented yet

service 'tinc' do
  action %i[enable start]
end

# As this cookbook is updating the node's network (adding a new network
# interface), in order to allow other coobooks, running after this one, to know
# about this new network interface, the following `ohai` block will refresh its
# `network` part on notifing it.
#
# (This means that this block is not executed immediately but when executing the
# following: `notifies :reload, 'ohai[reload network]', :immediately`)
ohai 'reload network' do
  action :reload
  plugin 'network'
end

# Fetches the node attributes from the right place.
#
# When using Chef's environments or Policyfiles and policy groups,
# this cookbook takes them, otherwise it look at the default attributes.
env_attributes = if node.environment == '_default'
                   node
                 else
                   if node[node.environment]
                     node[node.environment]
                   else
                     Chef::Log.warn 'tinc: The node has no Tinc attribute ' \
                                    "for the #{node.environment.inspect} " \
                                    'environment/policy group, therefore ' \
                                    'this cookbook will not do anything.'

                     {}
                   end
                 end

# Converts in a separated Hash (no more belonging to the node) so that
# we can modify it later.
env_attributes = env_attributes&.to_h['tincvpn'] || {}
Chef::Log.debug "tinc: env_attributes: #{env_attributes.inspect}"

# Avoids creating the `default` network from default attributes when using a
# custom network instead.
# The "default" network alone should not be deleted at all.
if Array(env_attributes['networks']).size > 1
  default_network = env_attributes['networks']['default']
  if default_network # If there is a "default" network in the attributes
    avahi_enabled = default_network['host'] && \
                    default_network['host']['avahi_zeroconf_enabled'] \
                    || false
    default_host_subnets = Array(default_network['host']['subnets'])
    # Removes the "default" network if it exists, is not alone, and
    # has the Avahi to false and the subnets is empty
    if avahi_enabled == false && default_host_subnets.empty?
      Chef::Log.warn 'tinc: Removing the "default" network from attributes ' \
                     "has it doesn't seem to be used."
      node.rm('tincvpn', 'networks', 'default')
      env_attributes['networks'].delete('default')
    end
  end
end

# Updates the network tunneladdr and tunnelnetmask node attributes from iprange
# attribute if tunneladdr and tunnelnetmask aren't already set.
Array(env_attributes['networks']).detect do |network_name, network|
  # Ignore all networks where the iprange attribute is not defined
  unless network['network'] && network['network']['iprange']
    Chef::Log.warn "tinc: Network #{network_name} doesn't have defined " \
                   'iprange, skip it.'

    next
  end

  # Load the cookbook data from the node's JSON file, from the chef repo.
  # See https://docs.chef.io/attributes/#attribute-persistence to know more
  # about `node.normal`.
  local_network = node.normal['tincvpn']['networks'][network_name]

  # Do not overrides the tunneladdr and tunnelnetmask attributes if already
  # defined locally on the node.
  if local_network['network']['tunneladdr'].empty? ||
     local_network['network']['tunnelnetmask'].empty?
    Chef::Log.warn "tinc: Network #{network_name} has no tunneladdr, nor " \
                   'tunnelnetmask, generating a new IP address ...'
  else
    Chef::Log.warn "tinc: Network #{network_name} already have a tunneladdr " \
                   'and/or tunnelnetmask, skip it.'
    next
  end

  # Parse the given iprange attribute. Could raise an ArgumentError in the case
  # the given value is not a valid IP Address
  ip_addresses = IPAddress(network['network']['iprange']).hosts
  # Also load all the network's peers
  peers = search(:node, "tincvpn_networks_#{network_name}_host_pubkey:* " \
                        "AND chef_environment:#{node.environment}")
  Chef::Log.warn "tinc: #{peers.size} nodes found from the " \
                 "#{node.environment} environment."

  unique_ip_address = nil
  iterations = 0

  # Search for a free IP address
  while unique_ip_address.to_s == ''
    already_in_use = false
    iterations += 1

    # Just in case of ...
    if iterations >= 200
      Chef::Log.warn 'tinc: Unable to find a free IP address after 200 ' \
                     'iterations.'
      break
    end

    # Taking randomly an IP address from the range
    new_ip_address = nil
    until new_ip_address
      new_ip_address = ip_addresses[rand(0..ip_addresses.size - 1)]
    end

    # Checking if that IP address is free
    peers.each do |peer|
      peer_network = peer['tincvpn']['networks'][network_name]['network']
      if peer_network['tunneladdr'] == new_ip_address
        already_in_use = true
        break
      end
    end

    # Leave the loop
    unique_ip_address = new_ip_address unless already_in_use
  end

  Chef::Log.warn "tinc: Generated free IP address: #{unique_ip_address}"

  # If a free IP address has been found, update the node network's tunneladdr
  # and tunnelnetmask attributes so that they'll be used later in this recipe.
  # They'll be saved in the node's JSON file so that on the next converge this
  # block will be ignored and the IP address will remain the same.
  #
  # Using `node.normal` stores the data in a JSON file with then node's name
  # in your chef repository.
  if unique_ip_address
    Chef::Log.warn "tinc: Saving IP address #{unique_ip_address} and " \
                   "mask #{unique_ip_address.netmask.inspect} to " \
                   "the #{network_name} data ..."

    node.normal['tincvpn']['networks'][network_name]['network']['tunneladdr'] = unique_ip_address.to_s
    node.normal['tincvpn']['networks'][network_name]['network']['tunnelnetmask'] = unique_ip_address.netmask

    subnets = []

    if env_attributes['networks'][network_name]['host']
      subnets = Array(env_attributes['networks'][network_name]['host']['subnets'])
    end
    node.normal['tincvpn']['networks'][network_name]['host']['subnets'] = begin
      subnets + ["#{unique_ip_address}/32"]
    end
  end
end

# We want to override the options passed to `tincd` and include the --logfile
# option
template '/etc/default/tinc' do
  source 'tinc.default.erb'
  mode '0644'
  notifies :restart, 'service[tinc]', :delayed
end

# For each tinc network which has been define on that node,
# create the configuration for each and find all other nodes( peers ) using
# chef-search, which do have the same networks, and create hosts files
# on this node for those with their public key so they can actually connect
# to each other
Array(env_attributes['networks']).each do |network_name, network|
  Chef::Log.debug "tinc: Processing network #{network_name} with " \
                  "config: #{network.inspect} ..."

  network_mode = network['network'] && network['network']['mode']
  network_mode ||= 'router' # Default tinc mode value

  network_host_subnets = Array(network['host'] && network['host']['subnets'])

  if !network_host_subnets.empty? && network_mode == 'switch'
    Chef::Log.fatal 'tinc: You defined switch as your mode, but also defined ' \
                    'subnets - this is now allowed by tinc'

    raise
  end

  directory "/etc/tinc/#{network_name}"
  directory "/etc/tinc/#{network_name}/hosts"

  if network['host'] && network['host']['name'] &&
     network['host']['name'] != node['hostname']
    Chef::Log.warn(
      "tinc: The hostname #{network['host']['name'].inspect} from tincvpn " \
      "attributes differs with node's hostname " \
      "(#{node['hostname'].inspect})."
    )
  end

  local_host_name = (network['host'] && network['host']['name'])
  local_host_name ||= node['hostname']
  local_host_name = local_host_name.gsub('-', '_')

  local_host_path = "/etc/tinc/#{network_name}/hosts/#{local_host_name}"
  priv_key_location = "/etc/tinc/#{network_name}/rsa_key.priv"

  avahi_zeroconf_enabled = network['host'] && network['host']['avahi_zeroconf_enabled']

  if avahi_zeroconf_enabled
    package %w(avahi-daemon avahi-utils avahi-autoipd)

    service 'avahi-daemon' do
      action %i[enable start]
    end

    if network_name.size >= 15
      Chef::Log.warn "tinc: The network name #{network_name} is too long " \
                     '(Avahi has a 15 characters limitation) which will ' \
                     'surely makes Avahi not starting correctly. ' \
                     'Please concider reducing the network name length to ' \
                     '15 characters at most.'
    end
  end

  # we use the tinc tool to generate the priv and public key, since openssl
  # with public key is kind of complicated with chef we remove the tinc.conf
  # before we generate, since otherwise the public key will not be saved in
  # /etc/tinc/#{network_name}/rsa_key.pub but rather in
  # the hosts/<localname> file - and we do not want that for
  # simplicity of extraction
  execute "generate-#{network_name}-keys" do
    command "rm -f #{local_host_path} " \
            "&& rm -f /etc/tinc/#{network_name}/tinc.conf " \
            "&& (yes | tincd  -n #{network_name} -K4096)"
    creates priv_key_location
    not_if { ::File.exist?(priv_key_location) }
  end

  # local host entry in hosts/
  # thats basically "us in the hosts file" - this is needed and mandaory
  # Takes the host address from the attributes if defined, otherwise takes
  # the automatic ipaddress attribute (ohai)
  host_addr = network['host'] && network['host']['address'] || node['ipaddress']
  template local_host_path do
    source 'host.erb'
    variables(
      pub_key: lazy { File.read("/etc/tinc/#{network_name}/rsa_key.pub") },
      address: host_addr,
      port: network['network'] && network['network']['port'] || 655,
      subnets: avahi_zeroconf_enabled ? [] : network_host_subnets
    )
  end

  # a ruby block is used to ensure order of execution - so in the case
  # "generate-#{network_name}-keys" needs to be run first
  ruby_block "publish-public-key-#{network_name}" do
    action :run
    block do
      node.normal['tincvpn']['networks'][network_name]['host']['pubkey'] = begin
        File.read("/etc/tinc/#{network_name}/rsa_key.pub")
      end
    end
  end

  # tinc up/down - mainly defining our tunnel network and our tunnel network
  # address
  node_network = node.normal['tincvpn']['networks'][network_name]
  if node_network && node_network['network']
    tunnel_address = node_network['network']['tunneladdr']
    tunnel_netmask = node_network['network']['tunnelnetmask']
  end

  %w[up down].each do |action|
    template "/etc/tinc/#{network_name}/tinc-#{action}" do
      source "tinc-#{action}.erb"
      mode '0755'
      variables(
        tunnel_address: tunnel_address,
        tunnel_netmask: tunnel_netmask,
        avahi_zeroconf_enabled: avahi_zeroconf_enabled
      )
      notifies :restart, 'service[tinc]', :immediately
      notifies :reload, 'ohai[reload network]', :immediately
    end
  end

  ##########################################################################
  # put all the remote hosts in place we can connect to,
  # search for the nodes in chef
  ##########################################################################
  # all the remote hosts
  hosts_connect_to = []

  query = "tincvpn_networks_#{network_name}_host_pubkey:* " \
          "AND chef_environment:#{node.environment}"
  # any other node having a public key and joined the same network
  Chef::Log.debug "tinc: Searching query: #{query.inspect}"
  peers = search(:node, query)
  Chef::Log.debug "tinc: #{peers.size} nodes found. " \
                  "(#{peers.map(&:name).sort.join(', ')})"

  Chef::Log.debug "local hostname: #{local_host_name.inspect}"
  peers.each do |peer|
    host_name = peer['hostname']
    Chef::Log.debug "tinc: Current hostname: #{host_name.inspect}"

    # Skip if the node found is actually the node we run on,
    # since that host file has been written already above
    # and the values in the search would be outdated anyway
    next if host_name == local_host_name

    Chef::Log.debug "tinc: Not this node's hostname, continuing ..."

    # check which hosts this peers defined to connect to
    defined_connect_to = network['host'] && network['host']['connect_to']
    Chef::Log.debug 'tinc: That hostname is defined to be connected to ' \
                    "#{defined_connect_to.inspect}"

    # Filter hosts we did not want to connect to on this peer
    # (if the whitelist exists)
    if !Array(defined_connect_to).empty? &&
       !Array(defined_connect_to).include?(host_name)
      next
    end

    host_addr = peer['ipaddress']
    unless peer['tincvpn']['networks'][network_name]['host']['address'].nil?
      host_addr = peer['tincvpn']['networks'][network_name]['host']['address']
    end
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
      notifies :restart, 'service[tinc]', :delayed
      notifies :reload, 'ohai[reload network]', :delayed
    end

    Chef::Log.debug 'tinc: Adding host_name ' \
                    "(#{host_name.gsub('-', '_').inspect}) to " \
                    'hosts_connect_to ...'

    # add all hosts to our connectTo list, except ourselfs
    hosts_connect_to << host_name.gsub('-', '_')
  end

  Chef::Log.debug "tinc: hosts_connect_to: #{hosts_connect_to.inspect}"

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
    notifies :restart, 'service[tinc]', :immediately
  end

  # We need this for systemd configuration
  # /etc/tinc/nets.boot are no longer working / is ignored,
  # see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=841052#27
  service "tinc@#{network_name}" do
    action %i[enable start]
    only_if { node.normal['tincvpn']['allow_service_restart'] }
    only_if { ::File.exist?('/bin/systemd') }
  end
end

# finally let our networks boot
template '/etc/tinc/nets.boot' do
  source 'nets.boot.erb'
  variables(
    networks: env_attributes['networks'].keys
  )
  notifies :restart, 'service[tinc]', :delayed
  notifies :reload, 'ohai[reload network]', :delayed
end
