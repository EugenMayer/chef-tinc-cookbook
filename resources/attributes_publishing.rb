property :network_name, String, name_property: true, required: true
property :host_name, String, required: true
property :host_address, String, required: true
property :host_pubkey, String, required: true
property :host_subnets, Array, default: []
property :network_port, [String, Integer], required: true

action :publish do
  ruby_block "publish-attributes-for-#{new_resource.network_name}" do
    block do
      node.normal[:tincvpn][:networks][new_resource.network_name][:host][:name] =
        new_resource.host_name

      node.normal[:tincvpn][:networks][new_resource.network_name][:host][:address] =
        new_resource.host_address

      node.normal[:tincvpn][:networks][new_resource.network_name][:host][:pubkey] =
        new_resource.host_pubkey

      node.normal[:tincvpn][:networks][new_resource.network_name][:host][:subnets] =
        new_resource.host_subnets

      node.normal[:tincvpn][:networks][new_resource.network_name][:network][:port] =
        new_resource.network_port
    end
  end
end

