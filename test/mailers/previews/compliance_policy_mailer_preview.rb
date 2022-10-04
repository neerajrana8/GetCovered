class CompliancePolicyMailerPreview < ActionMailer::Preview
  def policy_expiring_soon
    self.set_account_by_env()
    @essex = Account.find(7)
    @lease = Lease.find(20)
    @policy = Policy.find(1)
    expiration = Time.current + 14.days
    @policy.update effective_date: expiration - 1.year, expiration_date: expiration, status: "EXPIRED", policy_in_system: true
    Compliance::PolicyMailer.with(organization: @essex)
                            .policy_expiring_soon(policy: @policy)
  end

  def policy_lapsed
    self.set_account_by_env()
    @essex = Account.find(7)
    @lease = Lease.find(20)
    @policy = Policy.find(1)
    expiration = Time.current - 1.day
    @policy.update effective_date: expiration - 1.year, expiration_date: expiration, status: "EXPIRED", policy_in_system: true
    Compliance::PolicyMailer.with(organization: @essex)
                            .policy_lapsed(policy: @policy, lease: @lease)
  end

  #TODO: wasnt able to send
  def enrolled_in_master
    self.set_account_by_env()
    @essex = Account.find(7)
    @lease = Lease.find(20)
    @policy = Policy.find(1)
    Compliance::PolicyMailer.with(organization: @essex)
                            .enrolled_in_master(user: @lease.primary_user(),
                                                community: @lease.insurable.parent_community(),
                                                force: false)
  end

  def enrolled_in_master_force_placement
    self.set_account_by_env()
    @essex = Account.find(7)
    @lease = Lease.find(20)
    @policy = Policy.find(1)
    Compliance::PolicyMailer.with(organization: @essex)
                            .enrolled_in_master(user: @lease.primary_user(),
                                                community: @lease.insurable.parent_community(),
                                                force: true)
  end

  def external_policy_status_changed
    self.set_account_by_env()
    @essex = Account.find(7)
    @lease = Lease.find(20)
    policy_id, insurable_id = Policy.where(status: Policy.statuses["EXTERNAL_REJECTED"]).map{|el| [el.id,el.primary_insurable&.id]}.reject{|el| el.last.nil?}&.last
    @policy = Policy.find(policy_id)
    Compliance::PolicyMailer.with(organization: @essex)
                            .external_policy_status_changed(policy: @policy)
  end

  private
  def set_account_by_env
    case Rails.env
    when "local" || "development"
      @essex = Account.find(1)
      @policy = Policy.find(1)
      @lease = Lease.find(42)
    when "awsdev"
      @essex = Account.find(36)
      @lease = Lease.find(20)
      @policy = Policy.find(1)
    when "aws_staging"
      @essex = Account.find(7)
      @lease = Lease.find(20)
      @policy = Policy.find(1)
    end
  end
end
