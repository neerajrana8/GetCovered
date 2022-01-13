namespace :db do


    desc "Dumps a DB backup"
    task :dump, [:file, :dataonly, :verbose] => :environment do |task,args|
        return if !['local', 'awsdev', 'development', 'test', 'test_container'].include?(Rails.env)
        cmd = nil
        with_config do |app, host, db, user|
          where = args.file.present? ? "#{args.file}" : "#{Rails.root}/tmp/dumpster.dump"
          argz = [
            args.dataonly.present? && args.dataonly ? '-a' : nil,
            '-O', '-F c',
            !args.verbose.present? || args.verbose ? '-v' : nil,
            "-h  #{host}",
            "-d #{db}",
            "-f #{where}"
          ].compact
          cmd = "pg_dump #{argz.join(" ")}#{args.verbose == false ? ' &>/dev/null' : ''}"
        end
        puts cmd
        `#{cmd}`
    end

    desc "Restores the DB from a backup"
    task :restore, [:file, :dataonly, :verbose] => :environment do |task,args|
        return if !['local', 'awsdev', 'development', 'test', 'test_container'].include?(Rails.env)
        if args.file.present?
            cmd = nil
            with_config do |app, host, db, user|
                argz = [
                  args.dataonly.present? && args.dataonly ? '-a' : nil,
                  '-O', '-x', '-F c',
                  !args.verbose.present? || args.verbose ? '-v' : nil,
                  "-h  #{host}",
                  "-d #{db}",
                  "-c #{args.file}"
                ].compact
                cmd = "pg_restore #{argz.join(" ")}#{args.verbose == false ? ' &>/dev/null' : ''}"
            end
            Rake::Task["db:drop"].invoke
            Rake::Task["db:create"].invoke
            puts cmd
            `#{cmd}`
        else
            puts 'Please provide a filename from which to restore'
        end
    end

    private

    def with_config
      yield Rails.application.class.module_parent.name.underscore,
      ActiveRecord::Base.connection_config[:host] || 'localhost',
      ActiveRecord::Base.connection_config[:database],
      ActiveRecord::Base.connection_config[:username]
    end

end
