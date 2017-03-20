resource_name :pg_extension

property :extension, String, name_property: true
property :database, String, required: true
property :schema, String, default: "public"

def assert_safe_string!(str, used_for)
  raise "Invalid #{used_for}: #{str}" unless str =~ %r{\A[a-zA-Z0-9_ -]+\z}
end

action :create do
  
  assert_safe_string! database, 'database'
  assert_safe_string! extension, 'extension'
  assert_safe_string! schema, 'schema'

  bash "create-postgres-extension-#{extension}" do
    user 'postgres'
    code <<-EOQ
      set -e
      echo 'CREATE EXTENSION "#{extension}" WITH SCHEMA "#{schema}"' | psql -v ON_ERROR_STOP=1 --no-psqlrc '#{database}'
    EOQ
    only_if do
      system("invoke-rc.d postgresql status | grep main") and 
        `echo "COPY (SELECT COUNT(1) FROM pg_extension WHERE extname='#{extension}') TO STDOUT WITH CSV" | su - postgres -c "psql -v ON_ERROR_STOP=1 --no-psqlrc '#{database}'"`.chomp == '0'
    end
    action :run
  end

end
