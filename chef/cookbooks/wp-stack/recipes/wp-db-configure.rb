node["wp-stack"]["sites"].each do |sitename, data|
  document_root = "/var/www/html/#{sitename}"
  
  template("#{document_root}/wp-config.php") do
  source("wp-config.php.erb")
  variables(
    db_name: node['wp-stack']['db']['name'],
    db_user: node['wp-stack']['db']['user'],
    db_password: node['wp-stack']['db']['pass'],
    db_host: node['wp-stack']['db']['host'],
    db_charset: node['wp-stack']['db']['charset'],
    db_collate: node['wp-stack']['db']['collate'],
    db_prefix: node['wp-stack']['db']['prefix'],
  )
  end
  execute "set_apache_as_owner" do
  command "chown #{node['wp-stack']['install']['user']} -R #{document_root}"
  end

end
