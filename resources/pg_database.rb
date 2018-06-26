resource_name :pg_database

property :database, String, name_property: true
property :owner, String, required: true
property :with_postgis, [TrueClass, FalseClass], default: false
property :backup_region, String, required: true
property :backup_bucket, String, required: true
property :backup_retention, Integer, default: 2   # in weeks
property :backup_key, String, required: true
property :aws_access_key_id, String, required: true
property :aws_secret_access_key, String, required: true
property :with_rbenv, [TrueClass, FalseClass], default: true

action :create do
  self.class.send(:include, IcRails::Helper)
  Chef::Resource::Bash.send(:include, IcRails::Helper)
  
  assert_safe_string! new_resource.database, 'database'
  assert_safe_string! new_resource.owner, 'owner'

  bash "create-postgres-database-#{new_resource.database}" do
    user 'postgres'
    code <<-EOQ
      set -eu
      echo 'CREATE DATABASE "#{new_resource.database}" OWNER "#{new_resource.owner}"'               | #{psql}
      echo 'GRANT ALL PRIVILEGES ON DATABASE "#{new_resource.database}" TO "#{new_resource.owner}"' | #{psql}
    EOQ
    only_if do
      postgres_is_running? and `echo "COPY (SELECT COUNT(1) FROM pg_database WHERE datname='#{new_resource.database}') TO STDOUT WITH CSV" | su - postgres -c "#{psql}"`.chomp == '0'
    end
    action :run
  end

  if new_resource.with_postgis
    bash "create-postgis-extension-for-#{new_resource.database}" do
      user 'postgres'
      code <<-EOQ
        set -eu
        echo 'CREATE SCHEMA postgis AUTHORIZATION "#{new_resource.owner}";' | #{psql} '#{new_resource.database}'
        echo 'SET search_path TO postgis; CREATE EXTENSION postgis;' | #{psql} '#{new_resource.database}'
        echo 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA postgis TO "#{new_resource.owner}"' | #{psql} '#{new_resource.database}'
        echo 'GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA postgis TO "#{new_resource.owner}"' | #{psql} '#{new_resource.database}'
        echo 'ALTER VIEW postgis.geometry_columns OWNER TO "#{new_resource.owner}"' | #{psql} '#{new_resource.database}'
        echo 'ALTER VIEW postgis.geography_columns OWNER TO "#{new_resource.owner}"' | #{psql} '#{new_resource.database}'
        echo 'ALTER TABLE postgis.spatial_ref_sys OWNER TO "#{new_resource.owner}"' | #{psql} '#{new_resource.database}'
      EOQ
      only_if do
        postgres_is_running? and `echo "COPY (SELECT COUNT(1) FROM pg_extension WHERE extname='postgis') TO STDOUT WITH CSV" | su - postgres -c "#{psql} '#{new_resource.database}'"`.chomp == '0'
      end
      action :run
    end
  end

  # Backups:

  # Some gems for the backup script:
  %w{aws-s3 aws-sdk-core}.each do |gem|
    bash "install #{gem} gem" do
      user 'root'
      if new_resource.with_rbenv
        code <<-EOQ
          set -eu
          source /etc/profile.d/rbenv.sh && /usr/local/rbenv/shims/gem install #{gem} && rbenv rehash
        EOQ
      else
        code <<-EOQ
          set -eu
          gem install #{gem}
        EOQ
      end
    end
  end

  directory "#{node[:postgresql][:data_dir]}/backups" do
    owner "postgres"
    group "postgres"
    mode "0700"
  end

  template "#{node[:postgresql][:dir]}/backup-postgres-#{new_resource.database}.rb" do
    cookbook 'ic_rails'
    source 'backup-postgres.rb.erb'
    owner "postgres"
    group "postgres"
    mode "0755"
    variables database: new_resource.database,
              backup_region: new_resource.backup_region,
              backup_bucket: new_resource.backup_bucket,
              backup_retention: new_resource.backup_retention,
              access_key_id: new_resource.aws_access_key_id,
              secret_access_key: new_resource.aws_secret_access_key
  end

  file "#{node[:postgresql][:dir]}/backup_key_#{new_resource.database}" do
    owner "postgres"
    group "postgres"
    mode "0700"
    content new_resource.backup_key
  end

  cron "postgres-backup-#{new_resource.database}-cronjob" do
    minute '1'
    hour '3'
    user "postgres"
    command %Q{/bin/bash -c 'source /etc/profile.d/rbenv.sh && #{node[:postgresql][:dir]}/backup-postgres.rb "#{new_resource.database}" #{node.chef_environment}'}
    action :create
  end

end
