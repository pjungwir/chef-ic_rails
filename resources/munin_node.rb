def initialize(*args)
  super
  @action = :create

  # Trick to make sure we run this recipe:
  # https://tickets.opscode.com/browse/CHEF-611?page=com.atlassian.jira.plugin.system.issuetabpanels:all-tabpanel
  # https://github.com/chef/chef/issues/4260
  @run_context.include_recipe 'yum-epel'
end

resource_name :munin_node

property :server, String, required: true

action :create do

  case node['platform_family']
  when 'debian'
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
      only_if { File.exists? "/usr/bin/apt-get" }
    end

  when 'rhel'
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
