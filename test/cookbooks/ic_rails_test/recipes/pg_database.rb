include_recipe 'postgresql::server'
include_recipe 'postgresql::client'

pg_user 'test_user' do
  password 'secret123'
end

pg_database 'test_db' do
  owner 'test_user'
  backup_region 'us-west-1'
  backup_bucket 'example-bucket'
  backup_retention 2
  backup_key 'abcdefgh'
  aws_access_key_id 'foo'
  aws_secret_access_key 'supersecret'
  with_rbenv false
end

pg_extension 'pgcrypto' do
  database 'test_db'
end

