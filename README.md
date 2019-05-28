# Description

Installs [tinc vpn](https://www.tinc-vpn.org/) for meshed VPN networks.

  - supports multiple networks per node
  - connect_to can be either configured manually or extracted using node-search
  - you can run router and switch mode, the latter is for unicast/multicast enabled networks
  
All you need is deploying this cookbook on several nodes while using the same network name - the connection between those nodes (hosts)
will be configured automatically (published hosts/ with public keys)

Available on the [chef supermarket](https://supermarket.chef.io/cookbooks/tincvpn)

# Requirements

## Platform:

* debian
* ubuntu

## Cookbooks:

* openssl (= 4.4.0)

# Attributes

See [tincvpn.rb](https://github.com/EugenMayer/chef-tinc-cookbook/blob/master/attributes/tincvpn.rb) for the available attributes and how to use them 

# Recipes

* tincvpn::default

## tincvpn::default

Installs tinc and configure all your hosts and networks. Hosts are actually looked up using a node search, picking all nodes
having the same network deployed

# Tests

You can run the test using kitchen

    # vagrant basesed 
    chef exec bundle exec kitchen test debian-9.9
    
    # dokken based
    chef exec bundle exec kitchen test dokken-debian

    # just the default suite
    chef exec bundle exec kitchen test default-dokken-debian


    # experimental, docker based ( not dokken )
    export KITCHEN_YAML=.kitchen.docker.yml
    chef exec bundle exec kitchen test default-debian            
There are to test suites, `default` for testing anything with router mode and `switch` to ensure we can set the mode properly/

# Contributions

I am very happy to accept this PRs or work on issues to extend the usage of this cookbook.

Just use the [issue queue](https://github.com/EugenMayer/chef-tinc-cookbook/issues) or even better, create pull requests for what you like to improve.

# License and Maintainer

Maintainer:: Eugen Mayer

License:: Apache 2.0
