# choose your network name, right here default - pick what you want
# you can also define multiple networks, ensure you handle the ports though!
# mode is either router, switch or hub, see https://www.tinc-vpn.org/documentation/tinc.conf.5
default[:tincvpn][:networks]['default'][:network][:mode] = 'router'
default[:tincvpn][:networks]['default'][:network][:port] = 655
# Set interface if needed
default[:tincvpn][:networks][:default][:network][:interface] = nil  # Ex. 'tun'
# that is the virtual network the tinc mesh nodes connect to (not your LAN you will join/offer, see subnets)
default[:tincvpn][:networks]['default'][:network][:tunneladdr] = '172.25.0.1'
default[:tincvpn][:networks]['default'][:network][:tunnelnetmask] = '255.255.255.0'
# mandatory, you need to set this to a name of the host, like node1 or whatever
default[:tincvpn][:networks]['default'][:host][:name] = nil
# which nodes this host should be able to connect to. If you skip, any node in this network will be a connect target
default[:tincvpn][:networks]['default'][:host][:connect_to] = []
# define the subnets you want to share of your networks, like you LAN or whatever
default[:tincvpn][:networks]['default'][:host][:subnets] = []
# will default to fqdn when not set
default[:tincvpn][:networks]['default'][:host][:address] = nil

# use zeroconf with automatic ip and dns management
# see https://www.tinc-vpn.org/examples/zeroconf-ip-and-dns/ for details.
# When using this option network mode always switch and subnets are always empty array
default[:tincvpn][:networks]['default'][:host][:avahi_zeroconf_enabled] = false
