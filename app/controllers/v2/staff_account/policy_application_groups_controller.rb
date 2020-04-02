module V2
  module StaffAccount
    class PolicyApplicationGroupsController < StaffAccountController
      def upload_xlsx
        if params[:source_file].present?
          file = params[:source_file].read
          parsed_file = ::PolicyApplicationGroups::SourceXlsxParser.run!(xlsx_file_content: file)
          render json: { parsed_data: parsed_file }, status: 200
        else
          render json: { error: 'Need source_file' }, status: :unprocessable_entity
        end
      end
    end
  end
end
