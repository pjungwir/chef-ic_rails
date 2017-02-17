resource_name :pg_user

property :username, String, name_property: true
property :password, String, required: true

def assert_safe_string!(str, used_for)
  raise "Invalid #{used_for}: #{str}" unless str =~ %r{\A[a-zA-Z0-9_ -]+\z}
end

action :create do
  
  assert_safe_string! username, 'username'
  assert_safe_string! password, 'password'

  bash "create-postgres-user-#{username}" do
    user 'postgres'
    code <<-EOQ
      set -e
      echo "CREATE USER \\"#{username}\\" WITH PASSWORD '#{password}'" | psql -v ON_ERROR_STOP=1 --no-psqlrc
    EOQ
    only_if do
      system("invoke-rc.d postgresql status | grep main") and 
        `echo "COPY (SELECT COUNT(1) FROM pg_roles WHERE rolname='#{username}') TO STDOUT WITH CSV" | su - postgres -c "psql -v ON_ERROR_STOP=1 --no-psqlrc"`.chomp == '1'
    end
    action :run
  end

end
