resource_name :pg_user

property :username, String, name_property: true
property :password, String, required: true

action :create do
  self.class.send(:include, IcRails::Helper)
  Chef::Resource::Bash.send(:include, IcRails::Helper)
  
  assert_safe_string! username, 'username'
  assert_safe_string! password, 'password'

  bash "create-postgres-user-#{username}" do
    user 'postgres'
    code <<-EOQ
      set -eu
      echo "CREATE USER \\"#{username}\\" WITH PASSWORD '#{new_resource.password}'" | #{psql}
    EOQ
    only_if do
      postgres_is_running? and `echo "COPY (SELECT COUNT(1) FROM pg_roles WHERE rolname='#{username}') TO STDOUT WITH CSV" | su - postgres -c "#{psql}"`.chomp == '0'
    end
    action :run
  end

end
