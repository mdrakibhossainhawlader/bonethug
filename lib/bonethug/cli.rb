require 'rbconfig'

module Bonethug
  class CLI

    def self.handle(bin_name = 'thug')

      # what are we doing?
      task = ARGV[0] || 'help'

      case task

      when 'help'

        display_help

      when 'version'

        puts 'bonethug v' + VERSION + ' - build date: ' + BUILD_DATE
        exit

      when 'auth'

        # handle args
        env = ARGV[1]

        # validate
        unless env
          puts 'Usage: ' + bin_name + ' auth [environment]'
          return
        end

        exec "export to=#{env} && bundle exec mina -f .bonethug/deploy.rb auth --verbose"

      when 'install'

        # handle args
        type = ARGV[1]
        location = ARGV[2] || '.'

        # validate
        unless type
          puts 'Usage: ' + bin_name + ' install [type] [location]'
          return
        end

        # run the installer
        Installer.install type, location

      when 'init-db', 'init-local-db', 'setup-db'

        # handle args
        env = ARGV.last
        admin_user = ARGV.length == 3 ? ARGV[1] : 'root'

        # validate
        unless env
          puts 'Usage: ' + bin_name + ' ' + task + ' [admin_user] [environment]'
          return
        end

        if task == 'init-local-db'
          Installer.execute_init_mysql_db_script env, admin_user
        elsif task == 'setup-db'
          exec "export to=#{env} && export admin_user=#{admin_user} && bundle exec mina -f .bonethug/deploy.rb setup_db --verbose"
        else
          exec "export to=#{env} && export admin_user=#{admin_user} && bundle exec mina -f .bonethug/deploy.rb init_db --verbose"
        end

      when 'setup-env'

        # handle args
        env = ARGV.last

        # validate
        unless env
          puts 'Usage: ' + bin_name + ' setup-env [environment]'
          return
        end

        # find the file
        gem_dir = File.expand_path File.dirname(__FILE__) + '/../..'
        script = gem_dir + '/scripts/ubuntu_setup.sh'

        if env == 'show'

          puts "---------------"
          puts "Pre"
          puts "---------------\n"
          puts File.read script

          puts "\n---------------"
          puts "Parsed"
          puts "---------------"
          puts Installer.parse_sh File.read(script)

        elsif env == 'local'
          exec 'sudo bash ' + script

        else
          exec "export to=#{env} && bundle exec mina -f .bonethug/deploy.rb setup_env --verbose"

        end

      when 'init', 'update'

        # handle args
        location = ARGV[1] || '.'

        # validate
        unless location
          puts 'Usage: ' + bin_name + ' #{task} [location]'
          return
        end

        # run the initaliser
        Installer.bonethugise(location, task.to_sym)

      when  'run',
            'rake',
            'drush',
            'drush-local',
            'sake'

        # get env
        environment = ARGV.last

        # handle args
        if task == 'run'
          cmd_task = ARGV[1]
          args = ARGV[2..(ARGV.length-2)]
        else
          case task
          when 'rake'
            cmd_task = 'rake'
          when 'drush', 'drush-local'
            cmd_task = File.expand_path('./vendor/drush/drush/drush') + ' -r ' + File.expand_path('./public')
          when 'sake'
            cmd_task = 'public/framework/sake'
          end
          args = ARGV[1..(ARGV.length-2)]
        end

        if task == 'drush-local'

          env_cmd = RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i ? 'set' : 'export'
          cmd = env_cmd + " APPLICATION_ENV=#{environment} && #{cmd_task} #{args.join(' ')}"
          puts
          exec cmd

        else

          # build command
          run = "\"run[#{cmd_task} #{args.join(' ')}]\""

          # do it!
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb #{run} --verbose"

        end

      when  'sync-local-to',
            'sync-local-from'

        # args
        env_local  = ARGV[1]
        env_remote = ARGV[0]

        # validate
        unless env_local and env_remote
          puts 'Usage: thug #{task} [local_environment] [remote_environment]'
          return
        end

        # run the script
        exec "ruby .bonethug/syncer.rb #{task} #{env_local} #{env_remote}"

      end

      when  'deploy',
            'setup',
            'remote-backup',
            'local-backup',
            'sync-backup-to',
            'sync-backup-from',
            'force-unlock',
            'cleanup'

        # handle args
        environment = ARGV[1]

        # validate
        unless environment
          puts 'Usage: thug #{task} [environment]'
          return
        end

        case task

        # Setup and Deploy
        when 'deploy'
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb deploy --verbose"
        when 'setup'
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb setup --verbose"

        # remote mina scripts
        when 'force-unlock'
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb deploy:force_unlock --verbose"
        when 'cleanup'
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb deploy:cleanup --verbose"

        # Snapshot Backup
        when 'remote-backup'
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb backup --verbose"
        when 'local-backup'
          exec "export to=#{environment} && bundle exec astrails-safe .bonethug/backup.rb"

        # Synchronised backup
        when 'sync-backup-to'
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb sync_to --verbose"
        when 'sync-backup-from'
          exec "export to=#{environment} && bundle exec mina -f .bonethug/deploy.rb sync_from --verbose"

        end

      when 'watch'

        # handle args
        type = ARGV[1] || 'coffee_sass'
        location = ARGV[2] || '.'
        watch_only = ARGV[3] || nil

        # run the installer
        Watcher.watch type, location, watch_only

      when 'clean'

        location = ARGV[1] || '.'
        Installer.clean location   

      else

        # We didn't find a task
        puts 'Task not found'

      end

    end

    def self.display_help(bin_name = 'thug')
      puts 'Usage:  ' + bin_name + '  task [argument]...'
    end

  end
end