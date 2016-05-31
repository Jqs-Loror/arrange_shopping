require 'bundler/capistrano'
require 'rvm/capistrano'
# require 'whenever/capistrano'
require 'capistrano/ext/multistage'
# require 'capistrano-unicorn'

# Whenever setup for application
set(:whenever_command) { "RAILS_ENV=#{rails_env} bundle exec whenever" }
set :whenever_environment, defer { 'production' }


# Application configuration
set :application, 'arrange_shopping'
set :repository,  'git@github.com:Jqs-Loror/arrange_shopping.git'
set :scm, :git

# Server-side system wide settings
default_run_options[:pty] = true
ssh_options[:forward_agent] = true

# Application stages configuration
set :stages, %w(production-frontend production-production production)
set :default_stage, 'production'


# Unicorn environment configuration
set(:unicorn_env) { rails_env }

# Deploy configuration (Unicorn, nginx)
after 'deploy', 'deploy:cleanup'

namespace :deploy do

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end

  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/public/spree #{release_path}/public/spree"
  end

  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
    task :check_revision, roles: :web do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end

  # before "deploy", "deploy:check_revision"

  namespace :figaro do
    desc "SCP transfer figaro configuration to the shared folder"
    task :setup do
      transfer :up, "config/application.yml", "#{shared_path}/application.yml", :via => :scp
    end

    desc "Symlink application.yml to the release path"
    task :symlink do
      run "ln -sf #{shared_path}/application.yml #{release_path}/config/application.yml"
    end
  end

  after  "deploy:started", "figaro:setup"
  after "deploy:symlink:release", "figaro:symlink"
  desc "Restart the application"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && RAILS_ENV=#{stage} bundle exec pumactl -S #{current_path}/tmp/pids/puma-production.state restart"
  end

end