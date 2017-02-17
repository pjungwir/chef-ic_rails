def initialize(*args)
  super
  @action = :create

  # Trick to make sure we run this recipe:
  # https://tickets.opscode.com/browse/CHEF-611?page=com.atlassian.jira.plugin.system.issuetabpanels:all-tabpanel
  # https://github.com/chef/chef/issues/4260
  @run_context.include_recipe 'nginx::source'
end

resource_name :nginx

action :create do
  
  directory "#{node['nginx']['dir']}/ssl" do
    owner 'root'
    group 'root'
    mode '0700'
  end

  template 'logrotate-nginx' do
    cookbook 'ic_rails'
    source 'logrotate-nginx.erb'
    path "/etc/logrotate.d/nginx"
    owner "root"
    group "root"
    mode "0644"
  end

end
