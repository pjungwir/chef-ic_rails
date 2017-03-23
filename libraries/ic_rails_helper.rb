module IcRails
  module Helper

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

    def psql
      "psql -v ON_ERROR_STOP=1 --no-psqlrc"
    end

  end
end