resource_name :unicorn

property :app, String, name_property: true, regex: %r{\A[a-z0-9_]+\z}
property :app_user, String, required: true, regex: %r{\A[a-z0-9_]+\z}
property :rails_env, String, regex: %r{\A[a-z0-9_]+\z}
property :unicorn_workers, Integer, default: 2
property :hostnames, Array, required: true
property :ssl_cert, String, required: true
property :ssl_key, String, required: true

action :create do

  the_rails_env = if property_is_set?(:rails_env)
                    rails_env
                  else
                    node.chef_environment
                  end

	service "#{app}-unicorn" do
		action :nothing
		start_command   "bash -c 'PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH god start #{app}-unicorn'"
		stop_command    "bash -c 'PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH god stop #{app}-unicorn'"
		restart_command "bash -c 'PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH god restart #{app}-unicorn'"
	end

	bash "#{app_user}-in-sudoers" do
		code <<-EOS
			echo "#{app_user}\tALL=NOPASSWD:/usr/local/rbenv/shims/god" >> /etc/sudoers
		EOS
		not_if do
			system("grep '/usr/local/rbenv/shims/god' /etc/sudoers | grep '#{app_user}'")
		end
	end

  template "/etc/god/conf.d/#{app}-unicorn.god" do
    cookbook 'ic_rails'
    source "unicorn.god.erb"
    variables app: app,
              app_user: app_user,
              env: the_rails_env,
              unicorn_workers: unicorn_workers
    owner "root"
    group "root"
    mode "0775"
    notifies :restart, "service[god]"
  end

  bash "enable-nginx-site-#{app}" do
    action :nothing
    code <<-EOF
      /usr/sbin/nxensite #{app}
    EOF
  end

  %w[crt key].each do |ext|
    file "#{node['nginx']['dir']}/ssl/#{app}.#{ext}" do
      owner 'root'
      group 'root'
      mode '0600'
			content(ext == 'crt' ? ssl_cert : ssl_key)
    end
  end

  template "#{node['nginx']['dir']}/sites-available/#{app}" do
    cookbook 'ic_rails'
    source 'nginx-app.conf.erb'
    variables env: rails_env,
              app: app,
              hostnames: hostnames
    owner "root"
    group "root"
    mode "0755"
    notifies :run, "bash[enable-nginx-site-#{app}]"
    notifies :restart, "service[nginx]"
  end

	template "/etc/logrotate.d/#{app}" do
    cookbook 'ic_rails'
		source 'logrotate-app.erb'
		owner "root"
		group "root"
		mode "0644"
		variables app: app,
              app_user: app_user
	end

end
