namespace :db do


    desc "Dumps a DB backup"
    task :dump, [:file] => :environment do |task,args|
        return if !['local', 'awsdev', 'development'].include?(Rails.env)
        cmd = nil
        with_config do |app, host, db, user|
          where = args.file.present? ? "#{args.file}" : "#{Rails.root}/tmp/dumpster.dump"
          cmd = "pg_dump -O -F c -v -h #{host} -d #{db} -f #{where}"
        end
        puts cmd
        exec cmd
    end

    desc "Restores the DB from a backup"
    task :restore, [:file] => :environment do |task,args|
        return if !['local', 'awsdev', 'development'].include?(Rails.env)
        if args.file.present?
            cmd = nil
            with_config do |app, host, db, user|
                cmd = "pg_restore -O -x -F c -v -h #{host} -d #{db} -c #{args.file}"
            end
            Rake::Task["db:drop"].invoke
            Rake::Task["db:create"].invoke
            puts cmd
            exec cmd
        else
            puts 'Please provide a filename from which to restore'
        end
    end

    private

    def with_config
      yield Rails.application.class.parent_name.underscore,
      ActiveRecord::Base.connection_config[:host] || 'localhost',
      ActiveRecord::Base.connection_config[:database],
      ActiveRecord::Base.connection_config[:username]
    end

end
