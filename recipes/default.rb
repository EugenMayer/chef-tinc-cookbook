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

# for each tinc network which has been define on that node, create the configuration for each and find all other nodes( peers )
# using chef-search, which do have the same networks, and create hosts files on this node for those with their public key
# so they can actually connect to each other
node['tincvpn']['networks'].each do |network_name, network|
  raise "You need to set the host name for the tinc network #{network_name} in ['tincvpn']['networks'][#{network_name}]['network']['host']['name']" if network['host']['name'].nil?
  raise 'You defined switch as you mode, but also defined subnets - this is now allowed by tinc' if !node['tincvpn']['networks'][network_name]['host']['subnets'].empty? && network['network']['mode'] == 'switch'

  directory "/etc/tinc/#{network_name}"
  directory "/etc/tinc/#{network_name}/hosts"
  local_host_name = node['tincvpn']['networks'][network_name]['host']['name']
  local_host_path = "/etc/tinc/#{network_name}/hosts/#{local_host_name.gsub('-', '_')}"
  priv_key_location = "/etc/tinc/#{network_name}/rsa_key.priv"

  avahi_zeroconf_enabled = node['tincvpn']['networks'][network_name]['host']['avahi_zeroconf_enabled']

  if avahi_zeroconf_enabled
    package %w(avahi-daemon avahi-utils avahi-autoipd)

    service 'avahi-daemon' do
      action [ :enable, :start ]
    end
  end


  # we use the tinc tool to generate the priv and public key, since openssl with public key is kind of complicated with chef
  # we remove the tinc.conf before we generate, since otherwise the public key will not be saved in /etc/tinc/#{network_name}/rsa_key.pub
  # but rather in the hosts/<localname> file - and we do not want that for simplicity of extraction
  execute "generate-#{network_name}-keys" do
    command "rm -f #{local_host_path} && rm -f /etc/tinc/#{network_name}/tinc.conf && (yes | tincd  -n #{network_name} -K4096)"
    creates priv_key_location
    notifies :run, "ruby_block[publish-public-key-#{network_name}]", :immediately
    not_if { File.exist?(priv_key_location) }
  end

  # local host entry in hosts/
  # thats basically "us in the hosts file" - this is needed and mandaory
  host_addr = node['fqdn']
  host_addr = node['tincvpn']['networks'][network_name]['host']['address'] unless node['tincvpn']['networks'][network_name]['host']['address'].nil?
  template local_host_path do
    source 'host.erb'
    variables(
      pub_key: lazy { File.read("/etc/tinc/#{network_name}/rsa_key.pub") },
      address: host_addr,
      port: node['tincvpn']['networks'][network_name]['network']['port'],
      subnets: avahi_zeroconf_enabled ? [] : node['tincvpn']['networks'][network_name]['host']['subnets']
    )
  end

  # a ruby block is used to ensure order of execution - so in the case "generate-#{network_name}-keys" needs to be run first
  ruby_block "publish-public-key-#{network_name}" do
    block do
      node.normal['tincvpn']['networks'][network_name]['host']['pubkey'] = File.read("/etc/tinc/#{network_name}/rsa_key.pub")
    end
    action :nothing
  end

  # tinc up/down - mainly defining our tunnel network and our tunnel network address
  %w{up down}.each do |action|
    template "/etc/tinc/#{network_name}/tinc-#{action}" do
      source "tinc-#{action}.erb"
      mode '0755'
      variables(
        tunnel_address: network['network']['tunneladdr'],
        tunnel_netmask: network['network']['tunnelnetmask'],
        avahi_zeroconf_enabled: avahi_zeroconf_enabled
      )
      notifies :reload, 'service[tinc]', :delayed
    end
  end

  ########################################################################################
  ######## put all the remote hosts in place we can connect to, search for the nodes in chef
  ########################################################################################
  # all the remote hosts
  hosts_connect_to = []
  # any other node having a public key and joined the same network
  peers = search(:node, "tincvpn_networks_#{network_name}_host_pubkey:*")

  peers.each do |peer|
    host_name = peer['tincvpn']['networks'][network_name]['host']['name']
    # skip if the node found is actually then node we run on, since that host file has been written already above
    # and the values in the search would be outdated anyway
    next if host_name == node['tincvpn']['networks'][network_name]['host']['name']

    # check which hosts this peers defined to connect to
    defined_connect_to = node['tincvpn']['networks'][network_name]['host']['connect_to']

    # filter hosts we did not want to connect to on this peer (if the whitelist exists)
    next if !defined_connect_to.empty? && !defined_connect_to.include?(host_name)

    host_addr = peer['fqdn']
    host_addr = peer['tincvpn']['networks'][network_name]['host']['address'] unless peer['tincvpn']['networks'][network_name]['host']['address'].nil?
    host_pubkey = peer['tincvpn']['networks'][network_name]['host']['pubkey']

    template "/etc/tinc/#{network_name}/hosts/#{host_name.gsub('-', '_')}" do
      source 'host.erb'
      variables(
        address: host_addr,
        pub_key: host_pubkey,
        port: peer['tincvpn']['networks'][network_name]['network']['port'],
        subnets: avahi_zeroconf_enabled ? [] : peer['tincvpn']['networks'][network_name]['host']['subnets']
      )
      notifies :reload, 'service[tinc]', :delayed
    end

    # add all hosts to our connectTo list, except ourselfs
    hosts_connect_to << host_name.gsub('-', '_')
  end

  ########################################################################################
  ######## deploy our node network configuration
  ########################################################################################
  template "/etc/tinc/#{network_name}/tinc.conf" do
    source 'tinc.conf.erb'
    variables(
      name: network['host']['name'].gsub('-', '_'),
      port: network['network']['port'],
      interface: network['network']['interface'],
      hosts_connect_to: hosts_connect_to,
      mode: avahi_zeroconf_enabled ? 'switch' : network['network']['mode']
    )
    notifies :reload, 'service[tinc]', :delayed
  end

  # we need this for systemd configuration starting from debian-stretch
  # /etc/tinc/nets.boot are no longer working / is ignored, see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=841052#27
  if node['lsb']['codename'] == 'stretch'
    service "tinc@#{network_name}" do
    action [ :enable, :start ]
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

