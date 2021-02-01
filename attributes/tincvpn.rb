# choose your network name, right here default - pick what you want
# you can also define multiple networks, ensure you handle the ports though!
# mode is either router, switch or hub, see https://www.tinc-vpn.org/documentation/tinc.conf.5
default[:tincvpn][:networks]['default'][:network][:mode] = 'router'
default[:tincvpn][:networks]['default'][:network][:port] = 655
# Set interface if needed
default[:tincvpn][:networks]['default'][:network][:interface] = nil # Ex. 'tun'
# That is the virtual network the tinc mesh nodes connect to
# (not your LAN you will join/offer, see subnets)
# IP address (For example 172.25.0.1)
default[:tincvpn][:networks]['default'][:network][:tunneladdr] = nil
# Netmask (For example 255.255.255.0)
default[:tincvpn][:networks]['default'][:network][:tunnelnetmask] = nil
# IP range to be used in order to auto-set the tunneladdr and tunnelnetmask
# attributes.
# This has no effect if tunneladdr and tunnelnetmask are already set.
# The value should be something like 10.0.0.0/24.
default[:tincvpn][:networks]['default'][:network][:iprange] = nil
# optional, you can to set this to a name of the host, like node1 or whatever
default[:tincvpn][:networks]['default'][:host][:name] = nil
# which nodes this host should be able to connect to.
# If you skip, any node in this network will be a connect target
default[:tincvpn][:networks]['default'][:host][:connect_to] = []
# define the subnets you want to share of your networks, like you LAN or whatever
default[:tincvpn][:networks]['default'][:host][:subnets] = []
# will default to the node ipaddress when not set
default[:tincvpn][:networks]['default'][:host][:address] = nil

# use zeroconf with automatic ip and dns management
# see https://www.tinc-vpn.org/examples/zeroconf-ip-and-dns/ for details.
# When using this option network mode always switch
# and subnets are always empty array.
# Avahi will automatically assign a Link-local address to your nodes.
# (https://en.wikipedia.org/wiki/Link-local_address)
default[:tincvpn][:networks]['default'][:host][:avahi_zeroconf_enabled] = false

# In the case you're experiencing issues when the service is restarted, you can
# prevent the cookbook from restarting by setting this attribute to `false`.
default[:tincvpn][:allow_service_restart] = true
