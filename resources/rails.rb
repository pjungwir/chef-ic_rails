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

# If you want sidekiq, fill these out:
property :sidekiq_processes, Integer, default: 0

action :create do

  the_rails_env = if property_is_set?(:rails_env)
                    rails_env
                  else
                    node.chef_environment
                  end

  wants_unicorn = unicorn_workers > 0
  if wants_unicorn
    %w[hostnames ssl_cert ssl_key].each do |p|
      raise "If you want unicorn you must provide #{p}" unless property_is_set?(p.to_sym)
    end
  end

  wants_sidekiq = sidekiq_processes > 0

  # A place for the app to live:
  directory '/var/www' do
    owner 'root'
    group 'root'
    mode '0755'
  end

  directory "/var/www/#{app}" do
    owner app_user
    group app_user
    mode '0755'
  end
  %w{releases shared shared/config shared/log shared/tmp shared/tmp/pids shared/tmp/cache shared/tmp/sockets shared/vendor shared/vendor/bundle shared/public shared/public/system}.each do |dir|
    directory "/var/www/#{app}/#{dir}" do
      owner app_user
      group app_user
      mode '0755'
    end
  end

  template "/var/www/#{app}/shared/config/database.yml" do
    cookbook 'ic_rails'
    source 'database.yml.erb'
    owner app_user
    group app_user
    mode "0600"
    variables adapter: (with_postgis ? 'postgis' : 'postgresql'),
              envs: [{
                name: the_rails_env,
                postgres_database: postgres_database,
                postgres_username: postgres_username,
                postgres_password: postgres_password,
                postgres_host: postgres_host,
                postgres_port: postgres_port,
                pool_size: postgres_pool_size
              }]
  end

  template "/var/www/#{app}/shared/.env" do
    cookbook 'ic_rails'
    source 'dotenv.erb'
    owner app_user
    group app_user
    mode "0600"
    variables envvars: envvars
  end

  if wants_unicorn
    unicorn app do
      app_user new_resource.app_user
      rails_env new_resource.rails_env
      unicorn_workers new_resource.unicorn_workers
      hostnames new_resource.hostnames
      ssl_cert new_resource.ssl_cert
      ssl_key new_resource.ssl_key
    end
  end

  if wants_sidekiq
    sidekiq app do
      app_user new_resource.app_user
      rails_env new_resource.rails_env
      sidekiq_processes new_resource.unicorn_workers
    end
  end

end
