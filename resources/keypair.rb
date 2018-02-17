property :network_name, String, name_property: true, required: true
property :host_name, String, required: true

action :generate do
  action_create_config_dirs

  # we use the tinc tool to generate the priv and public key,
  execute "generate-#{new_resource.network_name}-keys" do
    command <<-SHELL
      rm -f /etc/tinc/#{new_resource.network_name}/hosts/#{new_resource.host_name}} && \
      rm -f /etc/tinc/#{new_resource.network_name}/tinc.conf && \
      (yes | tincd  -n #{new_resource.network_name} -K4096)
    SHELL
    creates "/etc/tinc/#{new_resource.network_name}/rsa_key.priv"
  end
end

action :create_config_dirs do
  directory "/etc/tinc/#{new_resource.network_name}"
  directory "/etc/tinc/#{new_resource.network_name}/hosts"
end
