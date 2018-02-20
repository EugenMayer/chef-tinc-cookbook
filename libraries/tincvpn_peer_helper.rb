require 'ostruct'

module TincVpn
  module PeerHelper
    def extract_peer_data(peer, network_name)
      OpenStruct.new(
        name:    peer[:tincvpn][:networks][network_name][:host][:name],
        address: peer[:tincvpn][:networks][network_name][:host][:address],
        pubkey:  peer[:tincvpn][:networks][network_name][:host][:pubkey],
        port:    peer[:tincvpn][:networks][network_name][:network][:port],
        subnets: peer[:tincvpn][:networks][network_name][:host][:subnets]
      )
    end

    def peer_valid?(peer_data, network_data)
      return false if peer_data.name == network_data[:host][:name]
      return true if network_data[:host][:connect_to].empty?
      network_data['host']['connect_to'].include?(peer_data.name)
    end
  end
end

Chef::Recipe.include(TincVpn::PeerHelper)
