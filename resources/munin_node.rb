resource_name :munin_node

property :server, String, required: true

action :create do

  # We use this source for munin
  # because the standard one interferes with our nginx installation.
  # TODO: Put this in our own apt repository.
  apt_repository "munin" do
    uri "http://ppa.launchpad.net/tuxpoldo/munin/ubuntu/"
    distribution "#{node['lsb']['codename']}"
    components   ["main"]
    cookbook     'ic_rails'
    key          'munin-signing-key'
    action :add
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
