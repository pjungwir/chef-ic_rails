resource_name :pg_user

property :username, String, name_property: true
property :password, String, required: true

action :create do
  self.class.send(:include, IcRails::Helper)
  Chef::Resource::Bash.send(:include, IcRails::Helper)
  
  assert_safe_string! new_resource.username, 'username'
  assert_safe_string! new_resource.password, 'password'

  bash "create-postgres-user-#{new_resource.username}" do
    user 'postgres'
    code <<-EOQ
      set -eu
      echo "CREATE USER \\"#{new_resource.username}\\" WITH PASSWORD '#{new_resource.password}'" | #{psql}
    EOQ
    only_if do
      postgres_is_running? and `echo "COPY (SELECT COUNT(1) FROM pg_roles WHERE rolname='#{new_resource.username}') TO STDOUT WITH CSV" | su - postgres -c "#{psql}"`.chomp == '0'
    end
    action :run
  end

end
