require 'serverspec'

set :backend, :exec

describe 'pg_database LWRP' do

  it "is listening on port 5432" do
    expect(port(5432)).to be_listening
  end

  it "has a running postgres service" do
    expect(service("postgresql")).to be_running
  end

  it "lets the new user run queries" do
    cmd = "echo 'COPY (SELECT 111 + 222) TO STDOUT WITH CSV' | PGPASSWORD=secret123 psql -U test_user -h localhost test_db"
    expect(command(cmd).stdout.chomp).to eq '333'
  end

end

describe 'pg_extension LWRP' do

  it "has the pgcrypto extension" do
    cmd = %q{echo "COPY (SELECT encode(digest('foo', 'sha1'), 'hex')) TO STDOUT WITH CSV" | PGPASSWORD=secret123 psql -U test_user -h localhost test_db}
    expect(command(cmd).stdout.chomp).to eq '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33'
  end

end
