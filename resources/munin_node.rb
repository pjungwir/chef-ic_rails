resource_name :munin_node

property :server, String, required: true

action :create do

  # We use this source for munin
  # because the standard one interferes with our nginx installation.
  # TODO: Put this in our own apt repository.
  if node['platform_version'] == "16.04"
    apt_repository "munin" do
      uri "http://ppa.launchpad.net/hawq/munin/ubuntu/"
      distribution "#{node['lsb']['codename']}"
      components   ["main"]
      cookbook     'ic_rails'
      key          'hawq-munin-signing-key'
      action :add
    end
  else
    apt_repository "munin" do
      uri "http://ppa.launchpad.net/tuxpoldo/munin/ubuntu/"
      distribution "#{node['lsb']['codename']}"
      components   ["main"]
      cookbook     'ic_rails'
      key          'tuxpoldo-munin-signing-key'
      action :add
    end
  end

  execute "apt-get-update" do
    command "apt-get update"
  end

  package "munin-node"

  template "/etc/munin/munin-node.conf" do
    cookbook 'ic_rails'
    source 'munin-node.conf.erb'
    owner "root"
    group "root"
    mode "0644"
    variables munin_server: server
  end

  service "munin-node" do
    action :restart
  end

end
