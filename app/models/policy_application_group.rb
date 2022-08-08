# == Schema Information
#
# Table name: policy_application_groups
#
#  id                        :bigint           not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  policy_applications_count :integer
#  status                    :integer          default("in_progress")
#  account_id                :bigint
#  agency_id                 :bigint
#  effective_date            :date
#  expiration_date           :date
#  auto_renew                :boolean          default(FALSE)
#  auto_pay                  :boolean          default(FALSE)
#  billing_strategy_id       :bigint
#  policy_group_id           :bigint
#  carrier_id                :bigint
#  policy_type_id            :bigint
#
class PolicyApplicationGroup < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :agency, optional: true
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :policy_group, optional: true

  has_many :policy_applications
  has_one :policy_group_quote
  belongs_to :billing_strategy
  has_many :model_errors, as: :model, dependent: :destroy

  enum status: %i[in_progress awaiting_acceptance error accepted]

  def update_status
    ActiveRecord::Base.transaction do
      if policy_applications.count == policy_applications_count && !all_errors_any? && !awaiting_acceptance?
        policy_group_quote.calculate_premium

        invoices_errors = policy_group_quote.generate_invoices_for_term(false, true)

        if invoices_errors.blank?
          update(status: :awaiting_acceptance)
        else
          ModelError.create(
            model: self,
            kind: :premium_and_invoices_was_not_generated,
            information: {
              params: nil,
              policy_users_params: nil,
              errors: invoices_errors
            }
          )
          update(status: :error)
        end
      elsif all_errors_any?
        update(status: :error)
      end
    end
  end

  # Checks the errors existence without getting all of them from the database
  def all_errors_any?
    model_errors.any? || policy_applications_errors.any? || policy_group_quote.model_errors.any?
  end

  def all_errors
    model_errors | policy_applications_errors | policy_group_quote.model_errors
  end

  private

  def policy_applications_errors
    join_query = <<-SQL
      LEFT JOIN policy_applications 
        ON model_errors.model_id = policy_applications.id AND model_errors.model_type = 'PolicyApplication' 
      LEFT JOIN policy_application_groups 
        ON policy_applications.policy_application_group_id = policy_application_groups.id
    SQL
    ModelError.joins(join_query).where(policy_application_groups: { id: id })
  end
end
