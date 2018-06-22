resource_name :delayed_job

property :app, String, name_property: true, regex: %r{\A[a-z0-9_]+\z}
property :app_user, String, required: true, regex: %r{\A[a-z0-9_]+\z}
property :rails_env, String, regex: %r{\A[a-z0-9_]+\z}
property :delayed_job_processes, Integer, default: 1

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

  service "#{app}-delayed_job" do 
    action :nothing
    start_command   "bash -c 'PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH god start #{app}-delayed_job'"
    stop_command    "bash -c 'PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH god stop #{app}-delayed_job'"
    restart_command "bash -c 'PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH god restart #{app}-delayed_job'"
  end   

	bash "#{app_user}-in-sudoers" do
		code <<-EOS
			echo "#{app_user}\tALL=NOPASSWD:/usr/local/rbenv/shims/god" >> /etc/sudoers
		EOS
		not_if do
			system("grep '/usr/local/rbenv/shims/god' /etc/sudoers | grep '#{app_user}'")
		end
	end

  template "/etc/god/conf.d/#{app}-delayed_job.god" do
    cookbook 'ic_rails'
    source "delayed_job.god.erb"
    variables app: app,
              app_user: app_user,
              env: node.chef_environment,
              delayed_job_processes: delayed_job_processes
    owner "root"
    group "root"
    mode "0775"
    notifies :restart, "service[god]"
  end
end
