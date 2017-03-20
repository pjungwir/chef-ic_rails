resource_name :pg_database

property :database, String, name_property: true
property :owner, String, required: true
property :password, String, required: true
property :with_postgis, :boolean, required: true
property :backup_region, String, required: true
property :backup_bucket, String, required: true
property :backup_retention, Integer, default: 2   # in weeks
property :backup_key, String, required: true
property :aws_access_key_id, String, required: true
property :aws_secret_access_key, String, required: true

def assert_safe_string!(str, used_for)
  raise "Invalid #{used_for}: #{str}" unless str =~ %r{\A[a-zA-Z0-9_ -]+\z}
end

action :create do
  
  assert_safe_string! database, 'database'
  assert_safe_string! owner, 'owner'

  psql = "psql -v ON_ERROR_STOP=1 --no-psqlrc"

  bash "create-postgres-database-#{database}" do
    user 'postgres'
    code <<-EOQ
      set -eu
      echo 'CREATE USER "#{owner}" WITH PASSWORD "#{password}"'           | #{psql}
      echo 'CREATE DATABASE "#{database}" OWNER "#{owner}"'               | #{psql}
      echo 'GRANT ALL PRIVILEGES ON DATABASE "#{database}" TO "#{owner}"' | #{psql}
    EOQ
    only_if do
      system("invoke-rc.d postgresql status | grep main") and 
        `echo "COPY (SELECT COUNT(1) FROM pg_database WHERE datname='#{database}') TO STDOUT WITH CSV" | su - postgres -c "#{psql}"`.chomp == '0'
    end
    action :run
  end

  if with_postgis
    bash "create-postgis-extension-for-#{database}" do
      user 'postgres'
      code <<-EOQ
        set -eu
        echo 'CREATE SCHEMA postgis AUTHORIZATION "#{owner}";' | #{psql} '#{database}'
        echo 'SET search_path TO postgis; CREATE EXTENSION postgis;' | #{psql} '#{database}'
        echo 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA postgis TO "#{owner}"' | #{psql} '#{database}'
        echo 'GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA postgis TO "#{owner}"' | #{psql} '#{database}'
        echo 'ALTER VIEW postgis.geometry_columns OWNER TO "#{owner}"' | #{psql} '#{database}'
        echo 'ALTER VIEW postgis.geography_columns OWNER TO "#{owner}"' | #{psql} '#{database}'
        echo 'ALTER TABLE postgis.spatial_ref_sys OWNER TO "#{owner}"' | #{psql} '#{database}'
      EOQ
      only_if do
        system("invoke-rc.d postgresql status | grep main") and
          `echo "COPY (SELECT COUNT(1) FROM pg_extension WHERE extname='postgis') TO STDOUT WITH CSV" | su - postgres -c "#{psql} '#{database}'"`.chomp == '0'
      end
      action :run
    end
  end

  # Backups:

  # Some gems for the backup script:
  %w{aws-s3 aws-sdk-core}.each do |gem|
    bash "install #{gem} gem" do
      user 'root'
      code <<-EOQ
        set -e
        source /etc/profile.d/rbenv.sh && /usr/local/rbenv/shims/gem install #{gem} && rbenv rehash
      EOQ
    end
  end

  directory "#{node[:postgresql][:data_dir]}/backups" do
    owner "postgres"
    group "postgres"
    mode "0700"
  end

  template "#{node[:postgresql][:dir]}/backup-postgres-#{database}.rb" do
    cookbook 'ic_rails'
    source 'backup-postgres.rb.erb'
    owner "postgres"
    group "postgres"
    mode "0755"
    variables database: database,
              backup_region: backup_region,
              backup_bucket: backup_bucket,
              backup_retention: backup_retention,
              access_key_id: aws_access_key_id,
              secret_access_key: aws_secret_access_key
  end

  file "#{node[:postgresql][:dir]}/backup_key_#{database}" do
    owner "postgres"
    group "postgres"
    mode "0700"
    content backup_key
  end

  cron "postgres-backup-#{database}-cronjob" do
    minute '1'
    hour '3'
    user "postgres"
    command %Q{/bin/bash -c 'source /etc/profile.d/rbenv.sh && #{node[:postgresql][:dir]}/backup-postgres.rb "#{database}" #{node.chef_environment}'}
    action :create
  end

end
