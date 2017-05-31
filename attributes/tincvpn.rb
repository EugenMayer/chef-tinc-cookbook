# network name

# mode is router, switch or hub, see https://www.tinc-vpn.org/documentation/tinc.conf.5
default[:tincvpn][:networks]['default'][:network][:mode] = 'router'
default[:tincvpn][:networks]['default'][:network][:port] = 655
default[:tincvpn][:networks]['default'][:network][:tunneladdr] = '172.25.0.1'
default[:tincvpn][:networks]['default'][:network][:tunnelnetmask] = '255.255.255.0'
default[:tincvpn][:networks]['default'][:host][:name] = nil
#default[:tincvpn][0][:host][:connect_to] = []
default[:tincvpn][:networks]['default'][:host][:subnets] = []
# will default to fqdn when not set
default[:tincvpn][:networks]['default'][:host][:address] = nil
#default[:tincvpn][:networks]['default'][:host][:pubkey] = nil
#default[:tincvpn][:networks]['default'][:host][:pubkey] = nil
