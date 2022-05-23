# Policy User model
# file: app/models/policy_user.rb

class PolicyUser < ApplicationRecord

  # Callbacks
  before_create :set_first_as_primary
  after_create :set_account_user, if: proc { |pol_usr| !pol_usr.user.nil? }

  belongs_to :policy_application, optional: true
  belongs_to :policy, optional: true
  belongs_to :user, optional: true
  
  has_many :integration_profiles, as: :profileable

  accepts_nested_attributes_for :user

  validate :user_listed_once

  enum status: { invited: 0, accepted: 1, disputed: 2, removed: 3 }
  enum dispute_status: { undisputed: 0, in_process: 1, resolved: 2 }

  def dispute
    update(status: 'disputed', disputed_at: Time.now, dispute_status: 'in_process') ? true : false
  end

  def resolve_dispute(remove = nil)
    raise ArgumentError, I18n.t('policy_user_model.must_indicate_removal') if remove.nil?

    update_status = remove ? 'removed' : 'accepted'
    update(status: update_status, dispute_status: 'resolved') ? true : false
  end

  def invite
    invite_sent = false
    client_host_link =
      BrandingProfiles::FindByObject.run!(object: self)&.url ||
      Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]

    unless disputed? ||
           accepted? ||
           primary? ||
           policy.nil? ||
           user.nil?

      links = {
        accept: "#{client_host_link}/confirm-policy",
        dispute: "#{client_host_link}/dispute-policy"
      }

      UserCoverageMailer.with(policy: policy, user: user, links: links).added_to_policy.deliver
      invite_sent = true
    end

    invite_sent
  end

  def accept(email = nil)
    raise ArgumentError, I18n.t('policy_user_model.email_must_be_present') if email.nil?

    acceptance_status = false

    if user.email == email
      if update(status: 'accepted')
        UserCoverageMailer.with(policy: policy, user: user).proof_of_coverage.deliver_later
        acceptance_status = true
      end
    end

    acceptance_status
  end

  private

  def set_first_as_primary
    ref_model = policy.nil? ? policy_application : policy
    if ref_model.policy_users.count == 0
      self.primary = true
      self.status = 'accepted'
    end
  end

    def set_account_user
      ref_model = policy.nil? ? policy_application : policy
			policy_type_check = ref_model.policy_type == PolicyType.find_by(id: 4) ||
                          ref_model.policy_type == PolicyType.find_by(id: 5)

      unless ref_model.account.nil? # commented out so we can support insurables without accounts: && policy_type_check
        acct = AccountUser.where(user_id: user.id, account_id: ref_model.account_id).take
        if acct.nil?
          AccountUser.create!(user: user, account: ref_model.account)
        elsif acct.status != 'enabled'
          acct.update(status: 'enabled')
        else
          # do nothing
        end
      end
    end

  def user_listed_once
    if policy_application
      user_ids = policy_application.users.map(&:id)
      errors.add(:user, I18n.t('policy_user_model.already_included_on_policy')) if user_ids.count(user.id) > 1
    end
  end
end
