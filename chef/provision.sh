#!/bin/bash
#
# A simple provisioning script that is run on both the app and lb nodes.

# Piping curl to bash is always an interesting idea.
# We'll, however, trust this now for installing Chef.

curl -L https://www.opscode.com/chef/install.sh | sudo bash
echo "Provisioning an application node"
sudo chef-solo -c chef/solo.rb -j chef/wp-stack.json

