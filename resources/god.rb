resource_name :god

# TODO: Consider having multiple gods, one for each ruby.

action :create do

  %w{god bundler}.each do |gem|
    bash "install #{gem} gem" do
      user 'root'
      code "source /etc/profile.d/rbenv.sh && gem install #{gem} && rbenv rehash"
    end
  end

  directory '/etc/god' do
    owner 'root'
    group 'root'
    mode '0755'
  end

  directory '/etc/god/conf.d' do
    owner 'root'
    group 'root'
    mode '0755'
  end

  cookbook_file '/etc/god/master.god' do
    owner 'root'
    group 'root'
    mode '0755'
  end

  service 'god' do
    action :nothing
    supports start: true, stop: true, restart: true, reload: true
  end

  template "/etc/init.d/god" do
    cookbook 'ic_rails'
    source 'god_initd.sh.erb'
    owner "root"
    group "root"
    mode "0755"
    notifies :enable, "service[god]"
    notifies :start, "service[god]"
  end

end
