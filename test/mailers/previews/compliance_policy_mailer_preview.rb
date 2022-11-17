class CompliancePolicyMailerPreview < ActionMailer::Preview
  def policy_expiring_soon
    #self.set_account_by_env()
    self.generate_data_for_policy_expiring_soon
    expiration = Time.current + 14.days
    @policy.update effective_date: expiration - 1.year, expiration_date: expiration, status: "EXPIRED", policy_in_system: true
    Compliance::PolicyMailer.with(organization: @essex)
                            .policy_expiring_soon(policy: @policy)
  end

  def policy_lapsed
    self.set_account_by_env()
    @essex = Account.find(1)
    @lease = Lease.find(20)
    @policy = Policy.find(2025)
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
    when "local","development"
      @essex = Account.find(7)
      @policy = Policy.find(2025)
      @lease = Lease.find(20)
    when "awsdev"
      @essex = Account.find(36)
      @lease = Lease.find(20)
      @policy = Policy.find(1)
    when "aws_staging" #TODO: after refreshing database can'be not working on STAGE
      @essex = Account.find(7)
      @lease = Lease.find(20)
      @policy = Policy.find(1)
    end
  end

  #TODO: will generalize and move to seeds when finish to create all relations to all emails
  def generate_data_for_policy_expiring_soon
    user = User.find_by_email("test3@test.com")
    if user.blank?
      user = FactoryBot.create(:user)
      policy_type = PolicyType.find_by_title('Residential')
      @agency = FactoryBot.create(:agency)
      @account = FactoryBot.create(:account, agency: @agency)
      branding_profile = FactoryBot.create(:branding_profile, profileable: @account)
      carrier = Carrier.first
      carrier.agencies << [@agency]

      @policy = FactoryBot.build(:policy, account: @account, agency: @agency, carrier: carrier,
                              policy_in_system: true,
                              policy_type: policy_type,
                              status: 'BOUND',
                              auto_pay: false,
                              expiration_date: DateTime.current.to_date + 7.days,
                              billing_enabled: true)
      @policy.save!
      FactoryBot.create(:policy_user, user: user, policy: @policy)
    else
      @policy =  user.policies.take
      @agency = @policy.agency
      @account = @policy.account
    end
  end
end
