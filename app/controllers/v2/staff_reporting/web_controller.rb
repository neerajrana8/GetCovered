


module V2
  module StaffReporting
    class WebController < StaffReportingController
      skip_before_action :authenticate_staff!
      skip_before_action :set_organizable
      
      def serve
        # we pull up only the filenames in the appropriate directory and require an exact string match,
        # so the user can't do any magic with .. or whatever
        file = Dir.glob("app/views/v2/shared/reporting/web/**/*")
                  .reject{|f| File.directory?(f) }
                  .find{|f| f == "app/views/v2/shared/reporting/web/#{params[:file]}.#{params[:format]}" }
        if file.nil?
          render plain: "404",
            status: 404
        else
          render file: file,
            layout: false,
            status: :ok
        end
      end
      
    end
  end
end
