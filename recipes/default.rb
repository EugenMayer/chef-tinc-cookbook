include_recipe 'tincvpn::install'

# for each tinc network which has been define on that node
# create the configuration for each and find all other nodes( peers )
# using chef-search, which do have the same networks,
# and create hosts files on this node for those with their public key
# so they can actually connect to each other

node['tincvpn']['networks'].each do |network_name, network|

  network_mode = network['network']['mode']

  if network['host']['avahi_zeroconf_enabled']
    network_mode = 'switch'
    include_recipe 'tincvpn::install_avahi'

    tincvpn_interface_up_down_avahi_zeroconf network_name do
      action :create
    end
  else
    tincvpn_interface_up_down network_name do
      tunnel_address network['network']['tunneladdr']
      tunnel_netmask network['network']['tunnelnetmask']
    end
  end

  tincvpn_keypair network_name do
    host_name network['host']['name']
    action [:generate, :publish_public_key]
  end

  # current node configuration
  tincvpn_host_config network['host']['name'] do
    network_name network_name
    host_address network['host']['address'] || node['fqdn']
    host_port    network['network']['port']

    # key was generated by tincvpn_keypair
    host_pubkey lazy { File.read("/etc/tinc/#{network_name}/rsa_key.pub") }

    # subnets allowed only in router mode
    if network_mode == 'router' && network['host']['subnets'].any?
      host_subnets network['host']['subnets']
    end

    action :create
  end

  # put all the remote hosts in place we can connect to, search for the nodes in chef
  peers = search(
    :node, "tincvpn_networks_#{network_name}_host_pubkey:*"
  ).map do |peer|
    peer_data = extract_peer_data(peer, network_name)

    next unless peer_valid?(peer_data, network)

    tincvpn_host_config peer_data.name do
      network_name network_name
      host_address peer_data.address || node['fqdn']
      host_port    peer_data.port
      host_pubkey  peer_data.pubkey
      host_subnets peer_data.subnets if network_mode == 'router'
    end 

    peer_data.name

  end.compact

  tincvpn_main_config network_name do
    host_name    network['host']['name']
    host_port    network['network']['port']
    network_mode network_mode
    connect_to   peers
  end



  # we need this for systemd configuration starting from debian-stretch
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
