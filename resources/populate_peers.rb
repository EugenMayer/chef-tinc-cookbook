property :network_name, String, name_property: true, required: true
property :host_name, String, required: true
property :connect_to, Array, default: []

action :populate do

  hosts_connect_to = []
  # any other node having a public key and joined the same network
  peers = search(:node, "tincvpn_networks_#{new_resource.network_name}_host_pubkey:*")

  peers.each do |peer|

    next if peer_name == new_resource.host_name

    # filter hosts we did not want to connect to on this peer (if the whitelist exists)
    if new_resource.connect_to.any?
      next unless new_resource.connect_to.include?(peer_name)
    end

    template "/etc/tinc/#{new_resource.network_name}/hosts/#{peer_name}" do
      source 'host.erb'
      variables(
        address: peer_address,
        pub_key: peer_pubkey,
        port: peer_port,
        subnets: peer_subnets
      )
      notifies :reload, 'service[tinc]'
    end

    # add all hosts to our connectTo list, except ourselfs
    hosts_connect_to << peer_name
  end
end


