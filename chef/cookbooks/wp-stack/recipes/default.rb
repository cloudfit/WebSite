#
# Cookbook Name:: wp-stack
# Recipe:: default
#
# Copyright 2017, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
#
execute "update-upgrade" do
  command "yum update -y"
  action :run
end
