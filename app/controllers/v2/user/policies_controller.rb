##
# V2 User Policies Controller
# File: app/controllers/v2/user/policies_controller.rb

module V2
  module User
    class PoliciesController < UserController

      skip_before_action :authenticate_user!, only: %i[bulk_decline render_eoi bulk_accept refund_policy cancel_policy cancel_auto_renewal]

      before_action :user_from_invitation_token, only: %i[bulk_decline render_eoi bulk_accept]
      before_action :set_policy, only: %i[show refund_policy cancel_policy cancel_auto_renewal]
      before_action :set_substrate, only: %i[index add_coverage_proof]

      def index
        if params[:short]
          super(:@policies, @substrate)
        else
          super(:@policies, @substrate)
        end
      end

      def show; end

      def add_coverage_proof
        insurable = Insurable.find_by(id: params[:insurable_id])
        render(json: { message: I18n.t('user_policies_controller.need_insurable') }, status: :unprocessable_entity) && return if insurable.nil?

        @policy = @substrate.new(coverage_proof_params)
        @policy.account = insurable.account
        @policy.policy_in_system = false
        @policy.policy_users.new(user_id: current_user.id)
        add_error_master_types(@policy.policy_type_id)
        if @policy.errors.blank? && @policy.save
          Insurables::UpdateCoveredStatus.run!(insurable: @policy.primary_insurable) if @policy.primary_insurable.present?
          render json: { message: I18n.t('user_policies_controller.policy_created') }, status: :created
        else
          render json: @policy.errors, status: :unprocessable_entity
        end
      end

      def delete_coverage_proof_documents
        @policy.documents.where(id: params.permit(documents_ids: [])[:documents_ids]).purge
      end

      def bulk_decline
        @policy = ::Policy.find(params[:id])
        render(json: { errors: [I18n.t('user_users_controler.unauthorized_access')] }, status: :unauthorized) && return unless @policy.primary_user == @user

        render(json: { errors: [ @policy.declined ? I18n.t('user_policies_controller.policy_was_already_declined') : I18n.t('user_policies_controller.policy_was_already_accepted')] }, status: :not_acceptable) && return unless @policy.declined.nil?

        @policy.bulk_decline
        render json: { message: I18n.t('user_policies_controller.policy_is_declined') }
      end

      def bulk_accept
        @policy = ::Policy.find(params[:id])
        render(json: { errors: [I18n.t('user_users_controler.unauthorized_access')] }, status: :unauthorized) && return unless @policy.primary_user == @user

        render(json: { errors: [ @policy.declined ? I18n.t('user_policies_controller.policy_was_already_declined') : I18n.t('user_policies_controller.policy_was_already_accepted')] }, status: :not_acceptable) && return unless @policy.declined.nil?

        @policy.update_attribute(:declined, false)
        ::Policies::SendProofOfCoverageJob.perform_later(@policy.id)

        render json: { message: I18n.t('user_policies_controller.policy_is_accepted') }
      end

      def resend_policy_documents
        ::Policies::SendProofOfCoverageJob.perform_later(params[:id])
        render json: { message: I18n.t('user_policies_controller.documents_were_sent') }
      end

      def refund_policy
        change_request = ChangeRequest.new(requestable: current_user, changeable: @policy, customized_action: 'refund')
        if change_request.save
          ::Policies::CancellationMailer.
            with(policy: @policy, change_request: change_request).
            refund_request.
            deliver_later
          render json: { message: I18n.t('user_policies_controller.refund_was_sent') }, status: :ok
        else
          render json: standard_error(:refund_policy_error, I18n.t('user_policies_controller.refund_was_successfully_sent'), change_request.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      def cancel_policy
        change_request = ChangeRequest.new(requestable: current_user, changeable: @policy, customized_action: 'cancel')
        if change_request.save
          ::Policies::CancellationMailer.
            with(policy: @policy, change_request: change_request).
            cancel_request.
            deliver_later
          render json: { message: I18n.t('user_policies_controller.cancel_was_successfully_sent') }, status: :ok
        else
          render json: standard_error(:refund_policy_error, I18n.t('user_policies_controller.refund_was_not_successfully_sent'), change_request.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      def render_eoi
        @policy = ::Policy.find(params[:id])
        render(json: { errors: [I18n.t('user_users_controler.unauthorized_access')] }, status: :unauthorized) && return unless @policy.primary_user == @user

        render(json: { errors: [ @policy.declined ? I18n.t('user_policies_controller.policy_was_already_declined') : I18n.t('user_policies_controller.policy_was_already_accepted') ] }, status: :not_acceptable) && return unless @policy.declined.nil?

        render json: {
          evidence_of_insurance: render_to_string('/v2/pensio/evidence_of_insurance.html.erb', layout: false),
          summary: render_to_string('/v2/pensio/summary.html.erb', layout: false)
        }
      end

      def cancel_auto_renewal
        if @policy.update(auto_renew: renewal_params[:auto_renew])
          render json: { message: I18n.t('user_policies_controller.auto_renewal_change') }, status: :ok
        else
          render json: standard_error(:autorenewal_policy_error, I18n.t('user_policies_controller.auto_renewal_change_not_successfull'), @policy.errors.full_messages),
                 status: :unprocessable_entity
        end
      end

      private

      def view_path
        super + '/policies'
      end

      def set_policy
        @policy = if current_user.blank?
                    Policy.find_by(id: params[:id])
                  else
                    access_model(::Policy, params[:id])
                  end
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Policy)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.policies
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def coverage_proof_params
        params.require(:policy).permit(:number,
                                       :account_id, :agency_id, :policy_type_id,
                                       :carrier_id, :effective_date, :expiration_date,
                                       :out_of_system_carrier_title, :address, documents: [],
                                                                               policy_users_attributes: [:user_id])
      end

      def add_error_master_types(type_id)
        @policy.errors.add(:policy_type_id,  I18n.t('user_policies_controller.you_cannot_add_coverage_with_master')) if [2,3].include?(type_id)
      end

      def renewal_params
        params.require(:policy).permit(:id, :auto_renew, :token)
      end

    end
  end # module User
end
