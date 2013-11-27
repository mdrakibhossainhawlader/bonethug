# Todo
# - implement a restore from backup task
# - implement a cleanup task when a deploy fails - its not good if the apache conf gets malformed
# - review directory permissions
# - passenger executes rails as the user that owns evironment.rb - if root owns it it runs as nobody
# - certain parts break if it can't find the config entries - should just check for them and skip if it can't find them
# - we run into problems if there is stuff that needs to be tracked by git in the vendor dirs 
#   -> if we add vendor to the shared paths stuff doesn't get updated properly
#   -> if we dont it means that composer downloads stuff every deployment
#   -> looks like composer breaks if we use symlniked paths

# Requires
# ---------------------------------------------------------------

require 'rubygems'
require 'bonethug/conf'
require 'bonethug/installer'
require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'
require 'mina/whenever'

# Config
# ---------------------------------------------------------------

# load the conf
conf = Bonethug::Conf.new
cnf = conf.to_hash

# pull config from environment vars
env = ENV['to']
raise 'could not find deployment environment' unless conf.get('deploy.environments').has_key? env

# build config
deploy    = conf.node_merge('deploy.common','deploy.environments.'+env)
resources = conf.get('resources','Array') || []
log_dirs  = conf.get('log_dirs','Array') || []
vendor  = conf.get('vendor','Array') || []

# vhost name
vhost = deploy.get('project_slug') + '_' + env

# composer?
use_composer = ['silverstripe','silverstripe3','drupal','drupal6','drupal7','drupal8','php'].include? deploy.get('project_type')

# composer?
use_bower = ['silverstripe','silverstripe3','drupal','drupal6','drupal7','drupal8','php'].include? deploy.get('project_type')

# directories we need to track
resources += ['backups']
# resources.push 'vendor' if use_composer

# logs
log_dirs.push 'log' unless log_dirs.include? 'log'

# other vendor dirs
vendor.push 'public/vendor' if use_bower and !vendor.include? 'public/vendor'

# shared paths
shared = resources + log_dirs + vendor + ['tmp']
shared.push 'composer.phar' if use_composer

# shared config
set :term_mode,     :system
set :keep_releases, deploy.get('keep') || 2
set :deploy_to,     deploy.get('base_dir') + '/' + vhost
set :repository,    deploy.get('repository')
set :branch,        ENV['branch'] || deploy.get('default_branch')
set :domain,        deploy.get('domain')
set :user,          deploy.get('user')
set :port,          deploy.get('port')
set :rails_env,     env
set :shared_paths,  shared
 

# Tasks
# ---------------------------------------------------------------

desc "Load Environment"
task :environment do
  # invoke :'rbenv:load'
end

desc "Sets up the Project"
task :setup => :environment do

  # make shared resource dirs
  (resources + log_dirs + vendor).each do |path|
    queue! %[mkdir -p "#{deploy_to}/shared/#{path}"]
  end

  # set appropriate permissions on the resource dirs
  resources.each do |path|
    queue! %[chown -R www-data:www-data "#{deploy_to}/shared/#{path}"]
    queue! %[chmod -R 0775 "#{deploy_to}/shared/#{path}"]
  end  

  # set appropriate permissions on the logs
  log_dirs.each do |path|
    queue! %[chown -R www-data:www-data "#{deploy_to}/shared/#{path}"]
    queue! %[chmod -R 0666 "#{deploy_to}/shared/#{path}"]
  end

  # make sure the vhost exists
  queue! %[touch /etc/apache2/sites-available/#{vhost}]

  # set up the tmp dir (rails only?)
  queue! %[mkdir -p "#{deploy_to}/shared/tmp"]
  queue! %[touch "#{deploy_to}/shared/tmp/restart.txt"]
  queue! %[cd #{deploy_to}/shared/tmp && chown -R www-data:www-data . && chmod -R 775 .]
 
  # init composer
  if use_composer
    queue! %[mkdir -p "#{deploy_to}/shared/vendor"]
    queue! %[cd #{deploy_to}/shared && curl -s http://getcomposer.org/installer | php] 
  end

  # create the backup folder
  queue! %[mkdir -p "#{deploy_to}/shared/backups"]

end

desc "Updates bundled dependencies"
task :update_packages => :environment do
  invoke :'bundle:update'
  queue! %[php #{deploy_to}/shared/composer.phar update] if use_composer
  queue! %[php #{deploy_to}/current/public/framework/cli-script.php dev/build] if ['silverstripe','silverstripe3'].include? deploy.get('project_type') 
end

desc "Sets up an environment"
task :setup_env => :environment do
  Bonethug::Installer.get_setup_env_cmds.each do |cmd| 
    queue! %[#{cmd}]
  end
end

desc "add your ssh key to the remote"
task :auth => :environment do
  pub_key = File.read File.expand_path('~/.ssh/id_rsa.pub')
  queue! %[echo "#{pub_key}" >> ~/.ssh/authourized_keys]
end

desc "init a db based on the settings in your cnf file"
task :init_db => :environment do

  conf.get('dbs').each do |name,envs|

    db = envs.get env
    cmd = Bonethug::Installer.init_mysql_db_script db, deploy_to + 'current', ENV['admin_user']
    queue! %[#{cmd}]

  end

end

desc "Initialises the db"
task :init_db => :environment do

  #rails
  queue! %[cd #{deploy_to}/current && bundle exec rake db:reset RAILS_ENV="#{env}"] if deploy.get('project_type') =~ /rails[0-9]?/
  
  # drpual
  if deploy.get('project_type') =~ /drupal[0-9]?/
    conf.get('dbs').each do |name,envs|
      db = envs.get env
      db_url = "mysql://#{db.get('user')}:#{db.get('pass')}@#{db.get('host')}/#{db.get('name')}"
      queue! %[export APPLICATION_ENV=#{env} && cd #{deploy_to}/current/public && ../vendor/bin/drush site-install standard --account-name=admin --account-pass=admin --db-url=#{db_url}"]
    end
  end

end

desc "Restores application state to the most recent backup"
task :backup => :environment do
  queue! %[cd #{deploy_to}/current && export to=#{env} && bundle exec astrails-safe .bonethug/backup.rb]
end

desc "Syncs files to a location"
task :sync_from => :environment do
  if rsync = conf.get('backup.rsync') 
    path = deploy.get('project_slug') + "_" + env + "_sync"
    ssh_pass = rsync.get('pass') ? "sshpass -p #{rsync.get('pass')}" : ""
    queue! %[#{ssh_pass} ssh #{rsync.get('user')}@#{rsync.get('host')} mkdir -p #{path}]
    (resources + log_dirs).each do |item|
      
      queue! %[cd #{deploy_to}/current && rsync -r -a -v -e "#{ssh_pass} ssh -l #{rsync.get('user')}" --delete --copy-dirlinks ./#{item} #{rsync.get('host')}:#{path}/]

    end
  else
    raise 'no rsync conf'
  end  
end

desc "Restores files from a location"
task :sync_to => :environment do
  if rsync = conf.get('backup.rsync')
    path = deploy.get('project_slug') + "_" + env + "_sync"
    ssh_pass = rsync.get('pass') ? "sshpass -p #{rsync.get('pass')}" : ""
    queue! %[#{ssh_pass} ssh #{rsync.get('user')}@#{rsync.get('host')} mkdir -p #{path}]
    (resources + log_dirs).each do |item|

      queue! %[cd #{deploy_to}/current && rsync -r -a -v -e "#{ssh_pass} ssh -l #{rsync.get('user')}" --delete --copy-dirlinks #{rsync.get('host')}:#{path}/#{item} ./]
   
    end
  else
    raise 'no rsync conf'
  end
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do

    # common deployment tasks
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'

    # rails deploy tasks
    if deploy.get('project_type') =~ /rails[0-9]?/
      invoke :'rails:db_migrate'
      invoke :'rails:assets_precompile'
    end

    # build the vhosts
    vh_cnf = conf.get('apache.'+env)

    # server aliases
    server_aliases = ''
    aliases = vh_cnf.get('server_aliases')
    if aliases
      aliases.each do |index, server_alias|
        server_aliases += 'ServerAlias '+server_alias + "\n"
      end
    end

    # environment variables
    env_vars = ''
    vars = vh_cnf.get('env_vars')
    if vars
      vars.each do |k, v|
        env_vars += 'SetEnv ' + k + ' ' + v + "\n"
      end
    end

    # server admin
    admin = vh_cnf.get('server_admin')
    server_admin = admin ? 'ServerAdmin '+admin : ''

    vh = "
<VirtualHost *:80>

  ServerName  #{vh_cnf.get('server_name')}
  #{server_aliases}

  #{server_admin}

  DocumentRoot #{deploy_to}/current/public

  #{env_vars}
  PassEnv PATH

  CustomLog #{deploy_to}/shared/log/bytes.log bytes
  CustomLog #{deploy_to}/shared/log/combined.log combined
  ErrorLog  #{deploy_to}/shared/log/error.log

  <Directory #{deploy_to}/current/public>

    Options Indexes MultiViews FollowSymLinks
    AllowOverride All
    Order allow,deny
    Allow from all
    Require all granted #apache2.4
    
  </Directory>

</VirtualHost>
    "

    # install the vhost
    queue! %[touch /etc/apache2/sites-available/#{vhost}.conf]
    queue! %[rm /etc/apache2/sites-available/#{vhost}.conf]
    queue! %[echo "#{vh}" > /etc/apache2/sites-available/#{vhost}.conf]

    to :launch do

      if deploy.get('project_type') =~ /rails[0-9]?/

        # make sure passenger runs the app as apache
        queue! %[cd #{deploy_to}/current/config && chown -R www-data:www-data environment.rb]
        queue! %[cd #{deploy_to}/current && chown -R www-data:www-data config.ru]

      end

      # ensure that the correct directory permissions are set - public is a bit heavy handed
      queue! %[cd #{deploy_to}/current/public && chown -R www-data:www-data . && chmod -R 775 .]
      queue! %[cd #{deploy_to}/shared/tmp && chown -R www-data:www-data . && chmod -R 775 .]
      
      # set appropriate permissions on the resource dirs - if they just need read / write - should prob be 0666
      resources.each do |path|
        queue! %[chown -R www-data:www-data "#{deploy_to}/shared/#{path}"]
        queue! %[chmod -R 0775 "#{deploy_to}/shared/#{path}"]
      end

      # apply defined permissions
      chowns = conf.get('chown.'+env)
      if chowns
        chowns.each do |index, chown|
          queue! %[cd #{deploy_to}/current/#{chown.get('path')} && chown -R #{chown.get('user')} .]
        end
      end
      
      # apply defined permissions
      chgrps = conf.get('chgrp.'+env)
      if chgrps
        chgrps.each do |index, chgrp|
          queue! %[cd #{deploy_to}/current/#{chgrp.get('path')} && chgrp -R #{chgrp.get('group')} .]
        end
      end      
      
      # apply defined permissions
      chmods = conf.get('chmod.'+env)
      if chmods
        chmods.each do |index, chmod|
          queue! %[cd #{deploy_to}/current/#{chmod.get('path')} && chmod -R #{chmod.get('mode')} .]
        end
      end

      # update composer
      queue! %[php #{deploy_to}/shared/composer.phar install] if use_composer

      # update bower
      queue! %[cd #{deploy_to}/current && bower install --allow-root] if use_bower      

      # trigger a restart on rack based systems   
      queue! %[touch #{deploy_to}/current/tmp/restart.txt]      

      # handle apache and cron
      queue! %[a2ensite #{vhost}.conf]
      queue! %[/etc/init.d/apache2 reload]
      invoke :'whenever:update'

      # run chache flushes / manifest rebuilds
      queue! %[export APPLICATION_ENV=#{env} && php #{deploy_to}/current/public/framework/cli-script.php dev/build] if ['silverstripe','silverstripe3'].include? deploy.get('project_type')
      queue! %[cd #{deploy_to}/current/lib && php flush_drupal_cache.php] if ['drupal','drupal6','drupal7','drupal8'].include? deploy.get('project_type')

      # cleanup!
      invoke :'deploy:cleanup'
      
    end
  end
end