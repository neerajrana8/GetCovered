class InvitationToPmTenantPortalMailerPreview < ActionMailer::Preview
  def first_audit_email
    self.set_account_by_env()

    Compliance::AuditMailer.with(organization: @essex)
                           .intro(user: @lease.primary_user(),
                                  community: @lease.insurable.parent_community(),
                                  lease_start_date: @lease.start_date,
                                  follow_up: 0)
  end

  def second_audit_email
    self.set_account_by_env()

    Compliance::AuditMailer.with(organization: @essex)
                           .intro(user: @lease.primary_user(),
                                  community: @lease.insurable.parent_community(),
                                  lease_start_date: @lease.start_date,
                                  follow_up: 1)
  end

  def third_audit_email
    self.set_account_by_env()

    Compliance::AuditMailer.with(organization: @essex)
                           .intro(user: @lease.primary_user(),
                                  community: @lease.insurable.parent_community(),
                                  lease_start_date: @lease.start_date,
                                  follow_up: 2)
  end

  def external_policy_submitted
    self.set_account_by_env()
    effective_date = Time.current.at_beginning_of_month
    @policy.update effective_date: effective_date, expiration_date: effective_date + 1.year, status: "EXTERNAL_UNVERIFIED", policy_in_system: false
    Compliance::PolicyMailer.with(organization: @essex)
                            .external_policy_status_changed(policy: @policy)
  end

  def external_policy_accepted
    self.set_account_by_env()
    effective_date = Time.current.at_beginning_of_month
    @policy.update effective_date: effective_date, expiration_date: effective_date + 1.year, status: "EXTERNAL_VERIFIED", policy_in_system: false
    Compliance::PolicyMailer.with(organization: @essex)
                            .external_policy_status_changed(policy: @policy)
  end

  def external_policy_declined
    self.set_account_by_env()
    effective_date = Time.current.at_beginning_of_month
    @policy.update effective_date: effective_date, expiration_date: effective_date + 1.year, status: "EXTERNAL_REJECTED", policy_in_system: false
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