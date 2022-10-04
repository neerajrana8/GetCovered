module V2
  module Insurables
    class InsurablesController < ApiController
      before_action :check_permissions

      def upload
        if file_correct?
          file = insurable_upload_params
          filename = "#{file.original_filename.split('.').first}-#{DateTime.now.to_i}.csv"
          file_path = Rails.root.join('tmp', filename)

          Rails.logger.info 'Put insurables.csv to aws::s3'
          obj = s3_bucket.object(filename)
          obj.put(body: file.read)

          ::Insurables::UploadJob.perform_later(object_name: filename, file: file_path.to_s, email: current_staff.email)

          resp = {
            title: 'Insurables File Uploaded',
            message: 'File scheduled for import. Insurables will be available soon.'
          }
          status = :ok
        else
          resp = {
            title: 'Insurables File Upload Failed',
            message: 'File could not be scheduled for import'
          }
          status = 422
        end

        render json: resp, status: status
      end

      private

      def s3_bucket
        env = Rails.env.to_sym
        Rails.logger.info "#DEBUG #{Rails.application.credentials.aws}"
        aws_bucket_name = Rails.application.credentials.aws[env][:bucket]
        Aws::S3::Resource.new.bucket(aws_bucket_name)
      end

      # TODO: Basic file validation
      def file_correct?
        true
      end

      def insurable_upload_params
        params.require(:file)
      end

      def check_permissions
        if current_staff && %(super_admin, staff, agent).include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied' }, status: 403
        end
      end

    end
  end
end
