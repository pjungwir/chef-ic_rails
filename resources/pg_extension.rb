resource_name :pg_extension

property :extension, String, name_property: true
property :database, String, required: true
property :schema, String, default: "public"

action :create do
  self.class.send(:include, IcRails::Helper)
  Chef::Resource::Bash.send(:include, IcRails::Helper)
  
  assert_safe_string! database, 'database'
  assert_safe_string! extension, 'extension'
  assert_safe_string! schema, 'schema'

  bash "create-postgres-extension-#{extension}" do
    user 'postgres'
    code <<-EOQ
      set -e
      echo 'CREATE EXTENSION "#{extension}" WITH SCHEMA "#{schema}"' | #{psql} '#{database}'
    EOQ
    only_if do
      postgres_is_running? and `echo "COPY (SELECT COUNT(1) FROM pg_extension WHERE extname='#{extension}') TO STDOUT WITH CSV" | su - postgres -c "#{psql} '#{database}'"`.chomp == '0'
    end
    action :run
  end

end
