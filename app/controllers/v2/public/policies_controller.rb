##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class PoliciesController < PublicController
      include PoliciesMethods

      before_action :set_community, only: [:enroll_master_policy]

      # NOTE: Needs refactoring
      def enroll_master_policy
        master_policy = @community.policies.where(policy_type_id: 2).take

        @users = access_model(::User).where(email: enrollment_params[:user_attributes].map { |el| el[:email] })

        if @users.blank?
          # return render json: { message: 'Users not found' }, status: :ok if @users.blank?

          @users = []
          enrollment_params[:user_attributes].each do |user|
            secure_tmp_password = SecureRandom.base64(12)
            new_user = ::User.create(
              email: user[:email],
              password: secure_tmp_password,
              password_confirmation: secure_tmp_password,
              profile_attributes: {
                first_name: user[:first_name],
                last_name: user[:last_name]
              }
            )
            @users << new_user
          end

        end

        if master_policy.present?
          start_coverage = master_policy.effective_date
          # render json: { message: 'Users not found' }, status: :ok if @users.blank?

          #TODO: need to add invitation uesr.invite! but how to determine to which user? primary?
          if master_policy.qbe_specialty_issue_coverage(@community, @users, start_coverage)
            @users.each do |user|
              user.invite!
            end
            render json: { message: 'Insurable was added to master policy coverage' }, status: :ok
          else
            render json: standard_error(
              :insurable_not_added_to_master_policy,
              'Insurable wasn\'t added to master policy coverage'
            ), status: :unprocessable_entity
          end
        else
          render json: standard_error(
            :master_policy_not_founded_for_current_insurable,
            'Master policy wasn\'t found for current insurable'
          ), status: :unprocessable_entity
        end
      end

      def master_policy_unit_coverage
        if params[:community_id].blank?
          render json: standard_error(:community_id_param_blank, 'Community parameter can\'t be blank'),
                 status: :unprocessable_entity
        else
          @community = Insurable.communities.find_by_id(params[:community_id])
          if @community.present?
            request.params[:id] = @community.id
            request.params[:user_id] = nil

            res = V2::Public::InsurablesController.dispatch(:show, request, response)
          else
            render json: standard_error(:community_not_found, 'Community with this id not found'),
                   status: :unprocessable_entity
          end

        end
      end

      def add_coverage_proof
        # NOTE: if there’s a matched carrier, the front-end sends the carrier_id,
        #       if there are no matches the front-end sends ‘out_of_system_carrier_title’ that contains the entered string
        params_hash = coverage_proof_params
        if coverage_proof_params[:out_of_system_carrier_title] && coverage_proof_params[:carrier_id].blank?
          carrier = ::Carrier.new(
            title: coverage_proof_params[:out_of_system_carrier_title],
            integration_designation: 'out_of_system'
          )

          unless carrier.save
            return render(
              json: standard_error(
                :carrier_invalid,
                I18n.t('public_policies_controller.title_already_exists_error'),
                carrier.errors.full_messages
              ),
              status: :unprocessable_entity
            )
          end

          params_hash[:carrier_id] = carrier.id
        end

        if Policy.where(number: params_hash[:number]).count > 0
          self.external_unverified_proof(params_hash)
        else
          self.apply_proof(params_hash)
        end
      end

      private

      def external_unverified_proof(params)
        @policy = Policy.find_by_number params[:number]
        if !@policy.nil? && @policy.policy_in_system == false
          # NOTE: This is not proper way to update documetns and insurable address attached to policy
          @policy.documents.purge
          @policy.insurables.delete_all
          if @policy.update(params)
            @policy.policy_coverages.where.not(id: @policy.policy_coverages.order(id: :asc).last.id).each do |coverage|
              coverage.destroy
            end
            result = ::Policies::UpdateUsers.run!(policy: @policy, policy_users_params: user_params[:policy_users_attributes]&.values)
            @policy.reload

            #TODO: temp test need to remove according to GCVR2-1197
            if Rails.env.development? or ENV['RAILS_ENV'] == 'awsdev'
              PolicyMailer.with(policy: @policy).coverage_proof_uploaded.deliver_now
              # else
              #   PolicyMailer.with(policy: @policy).coverage_proof_uploaded.deliver_later
            end
            PolicyMailer.with(policy: @policy).coverage_proof_uploaded.deliver_later
            render :show, status: :ok
          else
            render json: @policy.errors, status: 422
          end
        else
          render json: standard_error(:policy_in_system_violation, 'Policy in system violation'), status: 400
        end
      end

      def apply_proof(params)
        @policy = Policy.new(params)
        @policy.policy_in_system = false
        @policy.status = 'EXTERNAL_UNVERIFIED' if params[:status].blank?
        @policy.number = @policy.number.strip
        add_error_master_types(@policy.policy_type_id)
        if @policy.errors.blank? && @policy.save
          result = ::Policies::UpdateUsers.run!(policy: @policy, policy_users_params: user_params[:policy_users_attributes]&.values)
          @policy.reload
          if result.failure?
            render json: result.failure, status: 422
          else
            PolicyMailer.with(policy: @policy).coverage_proof_uploaded.deliver_later
            render :show, status: :created
          end
        else
          render json: @policy.errors, status: :unprocessable_entity
        end
      end

      def set_community
        @community = Insurable.find(params[:id])
      end

      def enrollment_params
        params.permit(user_attributes: [:email, :first_name, :last_name])
      end

      def external_policy_status_check(policy)
        to_return = false
        if ["EXTERNAL_UNVERIFIED", "EXTERNAL_REJECTED"].include?(policy.status)
          to_return = true
        elsif policy.status == "EXTERNAL_VERIFIED"
          if (Time.now..(Time.now + 30.days)) === policy.expiration_date
            to_return = true
          end
        end
        return to_return
      end

    end

  end # module Public
end

