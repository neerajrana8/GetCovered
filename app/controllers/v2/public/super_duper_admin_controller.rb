
module V2
  module Public
    class SuperDuperAdminController < PublicController
    
      def version_test
        render json: { version: "22.16.00" },
          status: 200
      end
    
      def dump
        if (Rails.env == 'local' || Rails.env == 'awsdev' || Rails.env == 'development') && params[:secret] == "I told a goose a password and that goose said honk honk honk--hey! Dance, everybody!"
          app = Rails.application.class.module_parent_name.underscore
          host = ActiveRecord::Base.connection_config[:host]
          db = ActiveRecord::Base.connection_config[:database]
          user = ActiveRecord::Base.connection_config[:username]
          pass = ActiveRecord::Base.connection_config[:password]
          port = ActiveRecord::Base.connection_config[:port]
          host = 'localhost' if host.blank?
          # using env variable doesn't seem to work... `#{pass.blank? ? "" : "PASSWORD=#{pass} "}pg_dump -F c -v -h #{host} -d #{db} -f #{Rails.root}/tmp/dumpster.dump`
          `pg_dump -O -F c -v --dbname="postgresql://#{user}#{pass.blank? ? "" : ":#{pass}"}@#{host}#{port.blank? ? "" : ":#{port}"}/#{db}" -f #{Rails.root}/tmp/dumpster.dump`
          render plain: `cat #{Rails.root}/tmp/dumpster.dump`,
            status: 200
          return
        end
        render json: { message: "What are you talking about?" },
          status: 404
      end
    
    
    end
  end # module Public
end
