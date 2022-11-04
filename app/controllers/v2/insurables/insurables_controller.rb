module V2
  module Insurables
    class InsurablesController < ApiController
      include ActionController::Caching

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


      def top_available
        filter = {}
        filter = params[:filter] if params[:filter]

        if params[:pagination].present?
          per = params[:pagination][:per] if params[:pagination][:per].present?
          page = params[:pagination][:page] if params[:pagination][:page].present?
        end

        insurable_types = InsurableType::COMMUNITIES_IDS + InsurableType::BUILDINGS_IDS
        insurable_types = InsurableType::COMMUNITIES_IDS if filter[:insurable_type_string] == :community.to_s
        insurable_types = InsurableType::BUILDINGS_IDS if filter[:insurable_type_string] == :buildings.to_s

        return params_error('master_policy_id is required') if filter[:master_policy_id].nil?

        if filter[:master_policy_id]
          master_policy_id = filter[:master_policy_id] if filter[:master_policy_id]
          master_policy = Policy.find(master_policy_id)
          return not_found_error("Master policy with id=#{master_policy_id} not found") unless master_policy
        end

        # Fetch active policies statuses
        active_statuses = Policy.statuses.values_at('BOUND', 'BOUND_WITH_WARNING').join(', ')

        # Fetch insurables with policies
        insurables_with_active_policies_ids =
          Insurable.joins(:policies)
            .where(insurable_type_id: insurable_types)
            .where("policies.policy_type_id = #{master_policy.policy_type_id}
                AND policies.status IN (#{active_statuses})
                AND policies.expiration_date > '#{Time.zone.now}'")
            .where(insurables: { account_id: master_policy.account })
            .select('insurables.id')

        # Fetch top available insurables
        insurables_query =
          Insurable
            .left_joins(:policy_insurables)
            .where(insurable_type_id: insurable_types)
            .where(insurables: { account_id: master_policy.account })
            .where(
              'policy_insurables.policy_id IS NULL ' \
              "OR insurables.id NOT IN (#{insurables_with_active_policies_ids.to_sql})"
            )

        if filter[:title].present?
          insurables_query = insurables_query.where('title LIKE ?', "%#{filter[:title][:like]}%") if filter[:title][:like].present?
        end

        insurables = insurables_query.page(page).per(per)

        @insurables = insurables
        @meta = {
          total: insurables.total_count,
          page: insurables.current_page,
          per: per
        }
        render 'v2/insurables/top_available'
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
