resource_name :munin_server

property :http_auth_password, String
property :ssl_cert, String
property :ssl_key, String

action :create do

  munin_node "node" do
    server '127.0.0.1'
  end
  nginx "nginx"

  package "munin"

  if property_is_set? :http_auth_password
    web_group = node['nginx']['group']
    hashed_password = nil
    require 'open3'
    Open3.popen3("openssl", "passwd", "-apr1", http_auth_password) do |stdin, stdout, stderr, wait_thread|
      hashed_password = stdout.read.chomp
    end
    raise "Expected to get a hashed password" unless hashed_password

    template "/var/cache/munin/htpasswd.users" do
      cookbook 'ic_rails'
      source 'htpasswd.erb'
      owner 'munin'
      group web_group
      mode '0644'
      variables http_auth_password: hashed_password
    end
  end

  if property_is_set?(:ssl_cert) != property_is_set?(:ssl_key)
    raise "Must have neither or both of ssl_cert and ssl_key"
  end

  if property_is_set?(:ssl_cert)
    %w{crt key}.each do |ext|
      file "#{node['nginx']['dir']}/ssl/munin.#{ext}" do
        owner 'root'
        group 'root'
        mode '0600'
        content(ext == 'crt' ? ssl_cert : ssl_key)
      end
    end
  end

  munin_conf = ::File.join(node['nginx']['dir'], 'sites-available', 'munin')
  template munin_conf do
    cookbook 'ic_rails'
    source 'nginx-munin.conf.erb'
    mode '0644'
    notifies :reload, 'service[nginx]' if ::File.symlink?(munin_conf)
  end

  nginx_site 'munin'

  # TODO: Need to list all the nodes in /etc/munin/munin.conf
  # (chef search would be nice here, but at least make it a property!)
end
