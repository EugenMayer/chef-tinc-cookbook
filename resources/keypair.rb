property :network_name, String, name_property: true, required: true

action :generate do
  action_create_config_dirs

  # we use the tinc tool to generate the priv and public key,
  execute "generate-#{new_resource.network_name}-keys" do
    command <<-SHELL
      rm -f #{local_host_path} && \
      rm -f /etc/tinc/#{new_resource.network_name}/tinc.conf && \
      (yes | tincd  -n #{new_resource.network_name} -K4096)
    SHELL

    creates "/etc/tinc/#{new_resource.network_name}/rsa_key.priv"
  end

  action_publish_public_key
end

action :publish_public_key do
  ruby_block "publish-public-key-for-#{new_resource.network_name}" do
    block do
      node.normal['tincvpn']['networks'][new_resource.network_name]['host']['pubkey'] =
        File.read("/etc/tinc/#{network_name}/rsa_key.pub")
    end
    action :nothing
  end
end

action :create_config_dirs do
  directory "/etc/tinc/#{new_resource.network_name}"
  directory "/etc/tinc/#{new_resource.network_name}/hosts"
end
