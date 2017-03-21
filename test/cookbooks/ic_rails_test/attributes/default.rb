case node['platform']
when 'ubuntu'
  default['postgresql']['version'] = '9.5'
  # Sadly the postgresql cookbook doesn't infer all this stuff from the version automatically:
  default['postgresql']['dir'] = '/etc/postgresql/9.5/main'
  default['postgresql']['data_dir'] = '/var/lib/postgresql/9.5/main'
  default['postgresql']['client']['packages'] = %w[postgresql-client-9.5 libpq-dev]
  default['postgresql']['server']['packages'] = %w[postgresql-9.5 postgresql-contrib-9.5 postgresql-server-dev-9.5 libpq-dev]


when 'centos'
  default['postgresql']['version'] = '9.2'
  default['postgresql']['client']['packages'] = %w[postgresql-devel]
  default['postgresql']['server']['packages'] = %w[postgresql-server postgresql-contrib]


else
  raise "Unknown platform: #{node['platform']}"
end

default['postgresql']['assign_postgres_password'] = false
default['postgresql']['password']['postgres'] = 'ignored'

