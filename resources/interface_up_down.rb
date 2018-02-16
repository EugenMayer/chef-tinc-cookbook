property :network_name, String, name_property: true, required: true
property :tunnel_address, String, required: true
property :tunnel_netmask, String, required: true


action :create do
  action_create_config_dirs

  # tinc up/down - mainly defining our tunnel network and our tunnel network address
  %w{up down}.each do |action|
    template "/etc/tinc/#{new_resource.network_name}/tinc-#{action}" do
      source "tinc-#{action}.erb"
      mode '0755'
      variables(
        tunnel_address: new_resource.tunnel_address
        tunnel_netmask: new_resource.tunnel_netmask
      )
      notifies :reload, 'service[tinc]'
    end
  end
end

action :create_config_dirs do
  directory "/etc/tinc/#{new_resource.network_name}"
end
