ic\_rails Cookbook
===================

Has various recipes and LWRPs that work together to install simple Rails apps.

Includes support for:

- Postgres
- Redis
- Munin node and server
- Nginx
- God
- Unicorn
- Sidekiq
- Delayed Job

This is all based on how I like to set up my systems,
so it comes with database backups, logrotate configs, etc.
It assumes you are using rbenv, god, and nginx, and deploying with Capistrano.
It drops a `database.yml` and `.env` into cap's `shared` section
so you can symlink to them.
It's opinioned to cut down on how much I have to re-write every time I deploy a new Rails app.



Platforms
---------

Only Ubuntu is supported right now.


Recipes
-------

There are no recipes! Instead you should use the LWRPs inside your own recipes.


LWRPs
-----

### god

Installs god with a master config file that sources anything in `/etc/god/conf.d`.
That way Rails apps can add their own stuff there, e.g. for unicorn, sidekiq, or whatever they need.
Also installs an init.d script for god.

### Parameters:

none!

TODO: Eventually I'd like this to support multiple ruby versions.

### nginx

This expects you to use the regular `nginx::source` recipe to install nginx,
but it will add an `ssl` subdirectory and a logrotate config.
So it doesn't do much really, but it does help me DRY up my own projects.

### Parameters:

none!

### munin\_server

Installs the munin server.
Configures an nginx site with HTTP Basic Auth and SSL,
so you can access the munin results on port 7778.
You can use this LWRP and the `unicorn` one together on the same server,
and they will share the same nginx compatibly.

### Parameters:

* `http_auth_password` - If you want munin to be protected, give a value here.
  What you give should be plaintext; the recipe will automatically hash it for the `htpasswd` file.

* `ssl_cert` - The SSL certificate in PEM format.

* `ssl_key` - The SSL key in PEM format.

TODO: Probably need to take a list of nodes too.

### munin\_node

Installs a munin node.

### Parameters

* `server` - The IP of the server. This is used to ensure no one else can connect.

### pg\_user

Creates a (non-superuser) Postgres role.

### Parameters

* `username` - Defaults to the resource name.

* `password`

### pg\_database

Creates a database and also sets up regular backups to S3.

### Parameters

* `database` - Defaults to the resource name.

* `owner`

* `backup_region` - S3 region for backups.

* `backup_bucket` - S3 bucket for backups.

* `backup_retention` - Number of weeks to keep backkups.

* `backup_key` - A key used for symmetric encryption of backups, before storing on S3.

* `aws_access_key_id` - Must have S3 permissions. TODO: If this is missing, use instance metadata.

* `aws_secret_access_key`

### pg\_extension

Adds an extension to a database.

### Parameters

* `extension` - Defaults to the resource name.

* `database`

* `schema` - Defaults to `public`.



