# net-tools contains deprecated ifconfig executable
package %w(tinc bridge-utils net-tools)

service 'tinc' do
  action [ :enable, :start ]
end

# we want to override the options passed to `tincd` and include the --logfile option
template '/etc/default/tinc' do
  source 'tinc.default.erb'
  mode 0644
  notifies :restart, 'service[tinc]'
end
