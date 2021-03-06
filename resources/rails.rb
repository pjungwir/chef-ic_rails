resource_name :rails

property :app, String, name_property: true, regex: %r{\A[a-z0-9_]+\z}
property :app_user, String, required: true, regex: %r{\A[a-z0-9_]+\z}
property :postgres_database, String, required: true, regex: %r{\A[a-z0-9_]+\z}
property :postgres_username, String, required: true, regex: %r{\A[a-z0-9_]+\z}
property :postgres_password, String, required: true
property :postgres_host, String, required: true
property :postgres_port, Integer, default: 5432
property :postgres_pool_size, Integer, required: true
property :with_postgis, [TrueClass, FalseClass], default: false
property :rails_env, String, regex: %r{\A[a-z0-9_]+\z}
property :envvars, Hash, default: {}

# If you want unicorn, fill these out:
property :unicorn_workers, Integer, default: 0
property :hostnames, Array
property :ssl_cert, String
property :ssl_key, String

# If you want http basic auth, fill these out:
property :http_auth_username, String
property :http_auth_password, String

# If you want sidekiq, fill these out:
property :sidekiq_processes, Integer, default: 0

# If you want delayed_job, fill these out:
property :delayed_job_processes, Integer, default: 0

action :create do

  the_rails_env = if new_resource.property_is_set?(:rails_env)
                    new_resource.rails_env
                  else
                    node.chef_environment
                  end

  wants_unicorn = new_resource.unicorn_workers > 0
  if wants_unicorn
    %w[hostnames ssl_cert ssl_key].each do |p|
      raise "If you want unicorn you must provide #{p}" unless new_resource.property_is_set?(p.to_sym)
    end
  end

  wants_sidekiq = new_resource.sidekiq_processes > 0
  wants_delayed_job = new_resource.delayed_job_processes > 0

  # A place for the app to live:
  directory '/var/www' do
    owner 'root'
    group 'root'
    mode '0755'
  end

  directory "/var/www/#{new_resource.app}" do
    owner new_resource.app_user
    group new_resource.app_user
    mode '0755'
  end
  %w{releases shared shared/config shared/log shared/tmp shared/tmp/pids shared/tmp/cache shared/tmp/sockets shared/vendor shared/vendor/bundle shared/public shared/public/system}.each do |dir|
    directory "/var/www/#{new_resource.app}/#{dir}" do
      owner new_resource.app_user
      group new_resource.app_user
      mode '0755'
    end
  end

  template "/var/www/#{new_resource.app}/shared/config/database.yml" do
    cookbook 'ic_rails'
    source 'database.yml.erb'
    owner new_resource.app_user
    group new_resource.app_user
    mode "0600"
    variables adapter: (new_resource.with_postgis ? 'postgis' : 'postgresql'),
              envs: [{
                name: the_rails_env,
                postgres_database: new_resource.postgres_database,
                postgres_username: new_resource.postgres_username,
                postgres_password: new_resource.postgres_password,
                postgres_host: new_resource.postgres_host,
                postgres_port: new_resource.postgres_port,
                pool_size: new_resource.postgres_pool_size
              }]
  end

  template "/var/www/#{new_resource.app}/shared/.env" do
    cookbook 'ic_rails'
    source 'dotenv.erb'
    owner new_resource.app_user
    group new_resource.app_user
    mode "0600"
    variables envvars: new_resource.envvars
  end

  # Have to check outside the other resource:
  has_http_auth = (new_resource.property_is_set?(:http_auth_username) and !new_resource.http_auth_username.nil? and new_resource.property_is_set?(:http_auth_password) and !new_resource.http_auth_password.nil?)
  if wants_unicorn
    unicorn new_resource.app do
      app_user new_resource.app_user
      rails_env new_resource.rails_env
      unicorn_workers new_resource.unicorn_workers
      hostnames new_resource.hostnames
      ssl_cert new_resource.ssl_cert
      ssl_key new_resource.ssl_key
      http_auth_username new_resource.http_auth_username if has_http_auth
      http_auth_password new_resource.http_auth_password if has_http_auth
    end
  end

  if wants_sidekiq
    sidekiq new_resource.app do
      app_user new_resource.app_user
      rails_env new_resource.rails_env
      sidekiq_processes new_resource.sidekiq_processes
    end
  end

  if wants_delayed_job
    delayed_job new_resource.app do
      app_user new_resource.app_user
      rails_env new_resource.rails_env
      delayed_job_processes new_resource.delayed_job_processes
    end
  end

end
