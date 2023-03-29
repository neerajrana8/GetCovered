##
# V2 StaffAccount Insurables Controller
# File: app/controllers/v2/staff_account/insurables_controller.rb

module V2
  module StaffAccount
    class InsurablesController < StaffAccountController
      alias super_index index

      before_action :set_insurable,
                    only: %i[update destroy show coverage_report policies
                             sync_address get_property_info related_insurables]
      before_action :set_master_policies, only: :show

      def index
        # NOTE: show only assigned insurables for property managers (communities, units and buildings)
        assigned_communities_ids = Insurable.where(id: current_staff.assignments.where(assignable_type: 'Insurable').pluck(:assignable_id)).pluck(:id)
        assigned_units_and_buildings_ids = Insurable.where(insurable_id: assigned_communities_ids).pluck(:id)
        assigned_units_ids = Insurable.where(insurable_id: assigned_units_and_buildings_ids).pluck(:id)
        assigned_ids = (assigned_communities_ids + assigned_units_and_buildings_ids + assigned_units_ids).uniq.compact

        # NOTE: in case there are no assigned insurables, show all of them
        query =
          if assigned_ids.any?
            Insurable.where(id: assigned_ids)
          else
            current_staff.organizable.insurables
          end

        super_index(:@insurables, query)
      end

      def communities
        if params[:search].presence
          account = current_staff.organizable
          @insurables = Insurable.where(account_id: account.id).communities.where(
            "title ILIKE '%#{ params[:search] }%'"
          )

          @response = V2::StaffSuperAdmin::Insurables.new(
            @insurables
          ).response

          render json: @response.to_json,
                 status: :ok
        else
          render json: [].to_json,
                 status: :ok
        end
      end

      def show; end

      def create
        if create_allowed?
          @insurable = current_staff.organizable.insurables.new(insurable_params)
          @insurable.confirmed = true
          if @insurable.errors.none? && @insurable.save_as(current_staff)
            render :show,
                   status: :created
          else
            render json: @insurable.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def bulk_create
        already_created_insurables =
          Insurable.where(insurable_id: bulk_create_params[:common_attributes][:insurable_id],
                          insurable_type_id: bulk_create_params[:common_attributes][:insurable_type_id],
                          title: insurables_titles).pluck(:title)
        new_insurables_titles = insurables_titles - already_created_insurables
        new_insurables_params = new_insurables_titles.reduce([]) do |result, title|
          result << bulk_create_params[:common_attributes].merge(title: title)
        end

        @insurables = current_staff.organizable.insurables.create(new_insurables_params)

        errors = @insurables.
          reject(&:valid?).
          map { |insurable| { title: insurable.title, errors: insurable.errors.full_messages } }

        render json: {
          created: @insurables.select(&:valid?),
          already_created: already_created_insurables,
          errors: errors
        }
      end

      def update
        if update_allowed?
          if @insurable.update_as(current_staff, update_params)
            render :show,
                   status: :ok
          else
            render json: @insurable.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def destroy
        if destroy_allowed?
          if @insurable.destroy
            render json: { success: true },
                   status: :ok
          else
            render json: { success: false },
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def policies
        insurable_units_ids =
          if InsurableType::UNITS_IDS.include?(@insurable.insurable_type_id)
            @insurable.id
          else
            [@insurable.units&.pluck(:id), @insurable.id, @insurable.insurables.ids].flatten.uniq.compact
          end

        policies_query = Policy.joins(:insurables).where(insurables: { id: insurable_units_ids }).order(created_at: :desc)

        @policies = paginator(policies_query)

        render :policies, status: :ok
      end

      def related_insurables
        @insurables = super_index(:@insurables, @insurable.insurables)
        render :index, status: :ok
      end

      def coverage_report
        render json: @insurable.coverage_report
      end

      def sync_residential_address
        if @insurable.get_qbe_zip_code
          render json: {
            title: 'Property Address Synced',
            message: "#{@insurable.title} property info successfuly synced to carrier"
          }.to_json,
                 status: :ok
        else
          render json: {
            title: 'Property Address Sync Failed',
            message: "#{@insurable.title} property info could not be synced to carrier"
          }.to_json,
                 status: 422
        end
      end

      def get_residential_property_info
        if @insurable.get_qbe_property_info
          render json: {
            title: 'Property Address Synced',
            message: "#{@insurable.title} property info successfuly synced to carrier"
          }.to_json,
                 status: :ok
        else
          render json: {
            title: 'Property Address Sync Failed',
            message: "#{@insurable.title} property info could not be synced to carrier"
          }.to_json,
                 status: 422
        end
      end

      def upload
        if file_correct?
          file = insurable_upload_params
          filename = "#{file.original_filename.split('.').first}-#{DateTime.now.to_i}.csv"
          file_path = Rails.root.join("tmp", filename)
          File.open(file_path, 'wb') do |tmp_file|
            tmp_file << file.read
          end
          ::Insurables::UploadJob.perform_later(file: file_path.to_s, email: current_staff.email)
          render json: {
              title: "Insurables File Uploaded",
              message: "File scheduled for import. Insurables will be available soon."
          }.to_json,
                 status: :ok
        else
          render json: {
              title: "Insurables File Upload Failed",
              message: "File could not be scheduled for import"
          }.to_json,
                 status: 422
        end
      end

      private

      def insurable_upload_params
        params.require(:file)
      end

      def view_path
        super + '/insurables'
      end

      def create_allowed?
        true
      end

      def update_allowed?
        true
      end

      def destroy_allowed?
        true
      end

      #TO DO: better to add validation for headers and amount of rows during parsing in background job to prevent double reading of file
      def file_correct?
        true
      end

      def set_insurable
        @insurable = current_staff.organizable.insurables.find(params[:id])
      end

      def set_master_policies
        if @insurable.unit?
          @master_policy_coverage =
            @insurable.policies.current.where(policy_type_id: PolicyType::MASTER_COVERAGES_IDS).take
          @master_policy = @master_policy_coverage&.policy
        else
          @master_policy =
            @insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
          @master_policy_coverage = nil
        end
      end

      def insurables_titles
        bulk_create_params[:ranges].reduce([]) do |result, range_string|
          result | Range.new(*range_string.split('..')).to_a
        end
      end

      def bulk_create_params
        params.require(:insurables).permit(
          common_attributes: [
            :category, :covered, :enabled, :insurable_id, :occupied,
            :insurable_type_id, :additional_interest_name, :additional_interest,
            addresses_attributes: %i[
              city country county id latitude longitude
              plus_four state street_name street_number
              street_two timezone zip_code
            ]
          ],
          ranges: []
        )
      end

      def insurable_params
        return({}) if params[:insurable].blank?

        to_return = params.require(:insurable).permit(
          :category, :covered, :enabled, :insurable_id, :occupied,
          :insurable_type_id, :title, :additional_interest_name, :additional_interest,
          addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
          ]
        )

        existed_ids = to_return[:addresses_attributes]&.map { |addr| addr[:id] }

        unless @insurable.blank? || existed_ids.nil? || existed_ids.compact.blank?
          (@insurable.addresses.pluck(:id) - existed_ids).each do |id|
            to_return[:addresses_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
        to_return
      end

      def update_params
        return({}) if params[:insurable].blank?

        to_return = params.require(:insurable).permit(
          :covered, :enabled, :insurable_id, :occupied,
          :title, :additional_interest_name, :additional_interest,
          addresses_attributes: %i[
            city country county id latitude longitude
            plus_four state street_name street_number
            street_two timezone zip_code
          ]
        )

        existed_ids = to_return[:addresses_attributes]&.map { |addr| addr[:id] }

        unless @insurable.blank? || existed_ids.nil? || existed_ids.compact.blank?
          (@insurable.addresses.pluck(:id) - existed_ids).each do |id|
            to_return[:addresses_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end
        to_return
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          title: %i[scalar like],
          permissions: %i[scalar array],
          insurable_type_id: %i[scalar array],
          insurable_id: %i[scalar array],
          account_id: %i[scalar array],
          confirmed: %i[scalar],
          created_at: %i[scalar array interval],
          updated_at: %i[scalar array interval],
          category: %i[scalar array],
          covered: %i[scalar array],
          enabled: %i[scalar array],
          occupied: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAccount
end
