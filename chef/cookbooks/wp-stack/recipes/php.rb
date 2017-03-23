package "php" do
  action :install
end

package "php-pear" do
  action :install
end

package "php-mysql" do
  action :install
  notifies :restart, "service[httpd]"
end
