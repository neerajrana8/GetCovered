require 'csv'

module Policies
  class SendPoliciesListJob < ApplicationJob

    def perform(params, staff_id)
      current_staff = Staff.find_by_id(staff_id)
      return unless current_staff

      params = params.deep_symbolize_keys
      @policies = ::Policies::List.new(params, export: true).call

      policies_json = JbuilderTemplate.new(ActionController::Base.new.view_context) do |json|
        json.partial! "v2/policies/list", formats: [:json], policies: @policies
      end.target!
      policies = JSON.parse(policies_json).dig('data') || []
      ActiveRecord::Base.transaction do
        csv_file = generate_csv(policies)
        ::Policies::ListMailer.generate(csv_file, current_staff).deliver_now
      end
    end

    private

    def generate_csv(policies)
      csv_string = CSV.generate(headers: true) do |csv|
        csv << ['Number', 'Status', 'T Code', 'Community', 'Building', 'Unit', 'PM Account', 'Agency', 'Effective_date',
                'Expiration Date', 'Cutomer Name', 'Email', 'Product', 'Billing Strategy', 'Update Date', 'Policy Source']
        policies.each do |policy|
          csv << [policy.dig('number'), policy.dig('status'), policy.dig('tcode'), policy.dig('primary_insurable', 'parent_community', 'title'),
                  policy.dig('primary_insurable', 'parent_building', 'title'), policy.dig('primary_insurable', 'title'),
                  policy.dig('account', 'title'), policy.dig('agency', 'title'), policy.dig('effective_date')&.to_date&.strftime("%B %d, %Y"),
                  policy.dig('expiration_date')&.to_date&.strftime("%B %d, %Y"), policy.dig('primary_user', 'full_name'),
                  (policy.dig('primary_user', 'email') || policy.dig('primary_user', 'contact_email')),
                  policy.dig('policy_type_title'), policy.dig('billing_strategy'), policy.dig('updated_at')&.to_date&.strftime("%B %d, %Y"),
                  (policy.dig('policy_in_system') == true ? 'Internal' : 'External')]
        end
      end
      csv_string
    end
  end
end
