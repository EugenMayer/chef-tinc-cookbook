property :network_name, String, name_property: true, required: true
property :host_name, String, required: true
property :host_port, [Integer, String], required: true
property :network_mode, String, default: 'router'
property :connect_to, Array, default: []

action :create do
  action_create_config_dirs

  template "/etc/tinc/#{new_resouce.network_name}/tinc.conf" do
    source 'tinc.conf.erb'
    variables(
      name: new_resource.host_name,
      port: new_resource.host_port,
      hosts_connect_to: new_resource.connect_to,
      mode: new_resource.network_mode
    )
    notifies :reload, 'service[tinc]'
  end
end

action :create_config_dirs do
  directory "/etc/tinc/#{new_resource.network_name}"
end
