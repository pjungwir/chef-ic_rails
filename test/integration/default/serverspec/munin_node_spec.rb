require 'serverspec'

set :backend, :exec

describe 'munin_node LWRP' do

  it "has a configuration file" do
    expect(file("/etc/munin/munin-node.conf")).to exist
    expect(file("/etc/munin/munin-node.conf")).to be_file
    expect(file("/etc/munin/munin-node.conf")).to contain("allow ^192\\.168\\.5\\.5$")
  end

  it "adds the postgres plugin" do
    expect(file("/etc/munin/plugins/postgres_connections_ALL")).to exist
    expect(file("/etc/munin/plugins/postgres_connections_ALL")).to be_symlink
  end

end
