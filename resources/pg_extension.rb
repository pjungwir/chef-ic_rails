resource_name :pg_extension

property :extension, String, name_property: true
property :database, String, required: true
property :schema, String, default: "public"

action :create do
  self.class.send(:include, IcRails::Helper)
  Chef::Resource::Bash.send(:include, IcRails::Helper)
  
  assert_safe_string! new_resource.database, 'database'
  assert_safe_string! new_resource.extension, 'extension'
  assert_safe_string! new_resource.schema, 'schema'

  bash "create-postgres-extension-#{new_resource.extension}" do
    user 'postgres'
    code <<-EOQ
      set -e
      echo 'CREATE EXTENSION "#{new_resource.extension}" WITH SCHEMA "#{new_resource.schema}"' | #{psql} '#{new_resource.database}'
    EOQ
    only_if do
      postgres_is_running? and `echo "COPY (SELECT COUNT(1) FROM pg_extension WHERE extname='#{new_resource.extension}') TO STDOUT WITH CSV" | su - postgres -c "#{psql} '#{new_resource.database}'"`.chomp == '0'
    end
    action :run
  end

end
