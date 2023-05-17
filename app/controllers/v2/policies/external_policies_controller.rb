# frozen_string_literal: true
module V2
  module Policies
    # External policies controller
    class ExternalPoliciesController < ApiController

      # Check policy by number
      def check
        resp = {}
        policy = Policy.find_by(number: policy_params[:number])
        if policy
          resp = policy_response(policy)
        end
        render json: resp
      end

      private

      def link_to_document(document)
        rails_blob_url(
          document,
          host: Rails.application.credentials[:uri][ENV['RAILS_ENV'].to_sym][:api]
        )
      end

      def document_response(policy)
        policy.documents.map do |f|
          {
            id: f.id,
            filename: f.filename,
            url: link_to_document(f),
            preview_link: link_to_document(f)
          }
        end
      end

      def carrier_response(policy)
        policy&.carrier
      end

      def users_response(policy)
        policy.users.map do |u|
          {
            id: u.id,
            email: u.email,
            profile: u.profile
          }
        end
      end

      def policy_response(policy)
        #coverage_requirements = coverage_requirements_by_policy(policy)
        master_policy_configuration = policy.master_policy_configuration

        return {
          policy: policy,
          policy_users: policy.policy_users,
          policy_coverages: policy.coverages,
          policy_insurables: policy.insurables,
          primary_insurable: policy.primary_insurable,
          master_policy_configuration: master_policy_configuration,
          #coverage_requirements: coverage_requirements,
          documents: document_response(policy),
          carrier: carrier_response(policy),
          users: users_response(policy)
        }
      end

      def policy_params
        params.require(:policy).permit(:id,
                                       :account_id,
                                       :agency_id,
                                       :carrier_id,
                                       :address, :number,
                                       :policy_type_id,
                                       :out_of_system_carrier_title,
                                       :status,
                                       # :lease_start,
                                       :effective_date,
                                       :expiration_date,
                                       # :additional_interest,
                                       :system_purchased,
                                       system_data: {},
                                       # policy_users_attributes: [
                                       #   :spouse, :primary,
                                       #   user_attributes: [
                                       #     :email,
                                       #     profile_attributes: %i[birth_date contact_phone first_name gender job_title last_name middle_name salutation],
                                       #     address_attributes: %i[city county street_number state street_name street_two zip_code]
                                       #   ]
                                       # ],
                                       policy_coverages_attributes: [],
                                       documents: [],
                                       policy_insurables_attributes: [:insurable_id])
      end

    end
  end
end
