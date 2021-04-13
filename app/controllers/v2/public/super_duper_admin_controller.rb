
module V2
  module Public
    class SuperDuperAdminController < PublicController
    
    
    
      def dump
        if (Rails.env == 'local' || Rails.env == 'awsdev' || Rails.env == 'development') && params[:secret] == "I told a goose a password and that goose said honk honk honk--hey! Dance, everybody!"
          app = Rails.application.class.parent_name.underscore
          host = ActiveRecord::Base.connection_config[:host]
          db = ActiveRecord::Base.connection_config[:database]
          user = ActiveRecord::Base.connection_config[:username]
          host = 'localhost' if host.blank?
          `pg_dump -F c -v -h #{host} -d #{db} -f #{Rails.root}/tmp/#{app}.dump`
          render plain: `cat #{Rails.root}/tmp/#{app}.dump`,
            status: 200
          return
        end
        render json: { message: "What are you talking about?" },
          status: 404
      end
    
    
    end
  end # module Public
end
