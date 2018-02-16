property :network_name, String, name_property: true, required: true

action :create do
  action_create_config_dirs

  %w{up down}.each do |action|
    template "/etc/tinc/#{new_resource.network_name}/tinc-#{action}" do
      source "tinc-#{action}-avahi_zeroconf.erb"
      mode '0755'
      notifies :reload, 'service[tinc]'
    end
  end
end

action :create_config_dirs do
  directory "/etc/tinc/#{new_resource.network_name}"
end
