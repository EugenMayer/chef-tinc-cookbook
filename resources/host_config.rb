property :host_name, String, name_property: true, required: true
property :network_name, String, required: true
property :host_address, String, required: true
property :host_pubkey, String, required: true
property :host_port, [Integer, String], required: true
property :host_subnets, Array, default: []

action :create do
  action_create_config_dirs

  template "/etc/tinc/#{new_resource.network_name}/hosts/#{new_resource.host_name}" do
    source 'host.erb'
    variables(
      pub_key: new_resource.host_pubkey,
      address: new_resource.host_address,
      port: new_resource.host_port, 
      subnets: new_resource.host_subnets
    )
  end
end

action :create_config_dirs do
  directory "/etc/tinc/#{new_resource.network_name}"
  directory "/etc/tinc/#{new_resource.network_name}/hosts"
end

