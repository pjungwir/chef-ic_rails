resource_name :pg_user

property :username, String, name_property: true
property :password, String, required: true

def assert_safe_string!(str, used_for)
  raise "Invalid #{used_for}: #{str}" unless str =~ %r{\A[a-zA-Z0-9_ -]+\z}
end

def postgres_is_running?
  cmd = case node['platform']
        when 'ubuntu'; "invoke-rc.d postgresql status | grep main"
        when 'centos'; "service postgresql status | grep 'active (running)'"
        else raise "Unknown platform: #{node['platform']}"
        end
  system(cmd)
end

action :create do
  
  assert_safe_string! username, 'username'
  assert_safe_string! password, 'password'

  bash "create-postgres-user-#{username}" do
    user 'postgres'
    code <<-EOQ
      set -eu
      echo "CREATE USER \\"#{username}\\" WITH PASSWORD '#{new_resource.password}'" | psql -v ON_ERROR_STOP=1 --no-psqlrc
    EOQ
    only_if do
      postgres_is_running? and `echo "COPY (SELECT COUNT(1) FROM pg_roles WHERE rolname='#{username}') TO STDOUT WITH CSV" | su - postgres -c "psql -v ON_ERROR_STOP=1 --no-psqlrc"`.chomp == '0'
    end
    action :run
  end

end
