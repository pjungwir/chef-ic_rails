require 'serverspec'

set :backend, :exec

describe 'munin_node LWRP' do

  it "has a configuration file" do
    expect(file("/etc/munin/munin-node.conf")).to exist
    expect(file("/etc/munin/munin-node.conf")).to be_file
    expect(file("/etc/munin/munin-node.conf")).to contain("allow ^192\\.168\\.5\\.5$")
  end

end
