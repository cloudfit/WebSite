
package "httpd" do
  action :install
end

service "httpd" do
  action [:enable, :start]
end

node["wp-stack"]["sites"].each do |sitename, data|
  document_root = "/var/www/html/#{sitename}"

  directory document_root do
    mode "0755"
    recursive true
  end

  ruby_block "install_wordpress" do

  block do
      require 'fileutils'
      FileUtils.cd document_root
      system 'wget https://wordpress.org/latest.tar.gz'
      system 'tar -xzf latest.tar.gz --strip-components=1 && rm latest.tar.gz'
      system 'aws s3 cp --recursive /var/www/html/mghali.com/ s3://wpmghali2017'
      end
      not_if { ::File.exist?(File.join( document_root , 'wp-settings.php')) }
      action :create
  end
  
  cron 'wp_site_sync' do
  minute '*/2'
  command 'aws s3 sync  /var/www/html/mghali.com/ s3://wpmghali2017'
  end
  
  cron 'wp_bucket_sync' do
  minute '*/3'
  command 'aws s3 sync  s3://wpmghali2017/  /var/www/html/mghali.com && chown -R apache:apache /var/www/html/mghali.com'
  end
  
  cookbook_file "#{document_root}/healthcheck.html" do
  source "healthcheck.html"
  mode "0644"
  end
    
  execute "set_apache_as_owner" do
  command "chown #{node['wp-stack']['install']['user']} -R #{document_root}"
  end  
 
  directory "/var/www/html/#{sitename}/logs" do
    action :create
  end
  
  template "/etc/httpd/conf.d/#{sitename}.conf" do
    source "virtualhosts.erb"
    mode "0644"
    variables(
      :document_root => document_root,
      :port => data["port"],
      :serveradmin => data["serveradmin"],
      :servername => data["servername"]
    )
    notifies :restart, "service[httpd]"
  end
  
  execute "chownlog" do
  command "chown apache /var/www/html/mghali.com"
  action :nothing
  end

end

execute "keepalive" do
  command "sed -i 's/KeepAlive On/KeepAlive Off/g' /etc/httpd/conf/httpd.conf"
  action :run
end
