module SessionRecordable
  extend ActiveSupport::Concern

  included do
    has_many :login_activities, as: :user
    after_save :update_login_client, if: Proc.new { tokens_changed? }
  end

  def update_login_client
    token_changes = previous_changes['tokens']
    changed_token = (token_changes.second.to_a - token_changes.first.to_a).to_h
    client = changed_token.keys.sample
    if client && token_changes.first[client].present? #works only on sign_in NOT ON CREATE TOKEN
      login_record = login_activities.find_by(client: client) || login_activities.where(client: nil).last
      login_record.update(client: client, expiry: changed_token[client]['expiry']) if login_record
    end
    #on delete tokens
    if token_changes.second.size < token_changes.first.size
      changed_token = (token_changes.first.to_a - token_changes.second.to_a).to_h
      login_records = login_activities.where(client: changed_token.keys - [client])
      login_records.update_all(active: false)
    end
  end

  def tokens_changed?
    previous_changes.include?(:tokens)
  end

end
