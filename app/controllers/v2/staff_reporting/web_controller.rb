


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
        if "#{params[:file]}.#{params[:format]}" == "index.html"
          # index.html is treated specially because we need to pass request.base_url to the javascript
          render html: (<<~ENDSTR
            <!DOCTYPE html>
            <head>
              <title>Get Covered Reporting</title>
              <link rel="stylesheet" href="style.css">
              <script type="text/javascript">
                var API_ROOT = "#{request.base_url}";
              </script>
            </head>
            <body>
              <script src="js/dialog.js"></script>
              <script src="js/app.js"></script>
              <script src="js/navbar.js"></script>
              <script src="js/page.js"></script>
              <script src="js/pages/home.js"></script>
              <script src="js/views/report_view.js"></script>
              <script src="js/pages/abstract/report.js"></script>
              <script src="js/pages/coverage_report.js"></script>
              <script src="js/pages/policy_report.js"></script>
              <script type="text/javascript">
                new App(API_ROOT);
                App.current.show();
              </script>
            </body>
            </html>
          ENDSTR
          ).html_safe, status: :ok
        elsif file.nil?
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
