# Description

Installs [tinc vpn](https://www.tinc-vpn.org/) for meshed VPN networks.

  - supports multiple networks per node
  - connect_to can be either configured manually or extracted using node-search
  - you can run router and switch mode, the latter is for unicast/multicast enabled networks
  
All you need is deploying this cookbook on several nodes while using the same network name - the connection between those nodes (hosts)
will be configured automatically (published hosts/ with public keys)

Available on the [chef supermarket](https://supermarket.chef.io/cookbooks/tincvpn)

## Requirements

- chef-client 13 or later


## Platform:
tested with following platforms:

- debian 9
- ubuntu 16

## Dependencies:

This cookbook has no dependencies on other cookbooks

## Attributes

See [default attributes](attributes/tincvpn.rb) for the available attributes and how to use them 

## Recipes

- tincvpn::default

### tincvpn::default

Installs tinc and configure all your hosts and networks. Hosts are actually looked up using a node
search, picking all nodes having the same network deployed.

As a bare minimum you can include this recipe in your own recipes or add in runlist,
it will configure tinc with network named 'default', in 'router' mode, with tunnel address '172.25.0.1/24'.
Node address and name will be equal to `node[:fqdn]`. Nodes must be reachable to each other with
fqdns for network to work, otherwise define custom host address:

```ruby
default[:tincvpn][:networks][:default][:host][:address] = node[:ipaddress]
```

You likely want to have distinct tunnel address, redefine like that:

```ruby
default[:tincvpn][:networks][:default][:network][:tunneladdr] = '172.25.0.2'
default[:tincvpn][:networks][:default][:network][:tunnelnetmask] = '255.255.255.0'
```

If you want define you own network and disable default one define attributes as follow:

```ruby

node.default[:tincvpn][:networks][:default][:disable] = true

node.default[:tincvpn][:networks][:mynet][:network][:port] = 655
node.default[:tincvpn][:networks][:mynet][:network][:mode] = 'router'
node.default[:tincvpn][:networks][:mynet][:network][:tunneladdr] = '172.25.0.2'
node.default[:tincvpn][:networks][:mynet][:network][:tunnelnetmask] = '255.255.255.0'

node.default[:tincvpn][:networks][:mynet][:host][:name] = node.name
node.default[:tincvpn][:networks][:mynet][:host][:address] = node[:ipaddress]

node.default[:tincvpn][:networks][:mynet][:host][:subnets] = [] # optional
node.default[:tincvpn][:networks][:mynet][:host][:connect_to] = [] # optional
```

This recipe has support to zeroconf, it means ip addresess in network and dns resolution can be managed
without any configuration, using this [approach](https://www.tinc-vpn.org/examples/zeroconf-ip-and-dns/).
All needed additional packages will be installed automatically. In this case you don't need to
specify network mode, tunnel address, netmask.

```ruby
node.default[:tincvpn][:networks][:default][:disable] = true
node.default[:tincvpn][:networks][:mynet][:host][:avahi_zeroconf_enabled] = true

node.default[:tincvpn][:networks][:mynet][:network][:port] = 655
node.default[:tincvpn][:networks][:mynet][:host][:name] = node.name

node.default[:tincvpn][:networks][:aads][:host][:address] = node[:ipaddress]
```

## ToDo
- add rubocop and foodcritic for code quality check
- add centOS support
- add description of custom resources

## Tests

You can run the test using kitchen

    kitchen test

## Contributions

I am very happy to accept this PRs or work on issues to extend the usage of this cookbook.

Just use the [issue queue](https://github.com/EugenMayer/chef-tinc-cookbook/issues) or even better, create pull requests for what you like to improve.

# License and Maintainer

Maintainer:: Eugen Mayer

License:: Apache 2.0
