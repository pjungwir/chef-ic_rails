resource_name :unicorn

property :app, String, name_property: true, regex: %r{\A[a-z0-9_]+\z}
property :app_user, String, required: true, regex: %r{\A[a-z0-9_]+\z}
property :rails_env, String, regex: %r{\A[a-z0-9_]+\z}
property :unicorn_workers, Integer, default: 2
property :hostnames, Array, required: true
property :ssl_cert, String, required: true
property :ssl_key, String, required: true

# If you want http basic auth, fill these out:
property :http_auth_username, String
property :http_auth_password, String

action :create do

  # We have to repeat some services here so that we can notify them.
  # https://github.com/chef/chef/issues/3575
  # This is pretty ugly though.
  # The nice would to do would be:
  # - Have *our* god and nginx resources accept a :restart action.
  # - Notify those from here.
  #   It sounds like on recent chef versions that works, otherwise use Poise.
  service 'god' do
    action :nothing
    supports start: true, stop: true, restart: true, reload: true
  end
  service 'nginx' do
    action :nothing
    supports start: true, stop: true, restart: true, reload: true
  end


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

  has_http_auth = (new_resource.property_is_set?(:http_auth_username) and !new_resource.http_auth_username.nil? and new_resource.property_is_set?(:http_auth_password) and !new_resource.http_auth_password.nil?)
  if has_http_auth
    package 'apache2-utils'
    file "htpasswd" do
      path "#{node['nginx']['dir']}/htpasswd.#{app}"
      owner "root"
      group "root"
      mode "0700"
      content lazy { IO.popen(["htpasswd", "-nb", new_resource.http_auth_username, new_resource.http_auth_password]) { |f| f.gets } }
    end
  end

  template "#{node['nginx']['dir']}/sites-available/#{app}" do
    cookbook 'ic_rails'
    source 'nginx-app.conf.erb'
    variables env: rails_env,
              app: app,
              hostnames: hostnames,
              has_http_auth: has_http_auth
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
