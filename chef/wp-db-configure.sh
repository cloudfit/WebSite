#!/bin/bash

# Piping curl to bash is always an interesting idea.
# We'll, however, trust this now for installing Chef.

echo "Configure wordpress db access"
sed -i 's/localhost/'$1'/g' /home/ec2-user/chef/cookbooks/wp-stack/attributes/default.rb
cat /home/ec2-user/chef/cookbooks/wp-stack/attributes/default.rb
sudo chef-solo -c chef/solo.rb -j chef/wp-db-configure.json

