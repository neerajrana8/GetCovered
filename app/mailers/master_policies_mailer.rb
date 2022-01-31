class MasterPoliciesMailer < ApplicationMailer
  before_action do
    @staff = params[:staff]
    @master_policy = params[:master_policy]
    @invoice = params[:invoice]
  end

  after_action :record_mail

  def bill_master_policy
    mail(from: 'support@getcoveredinsurance.com', to: @staff.email, subject: "Master Policy #{@master_policy.number} Invoice")
  end

  private

  def record_mail
    contact_record = ContactRecord.new(
      approach: 'email',
      direction: 'outgoing',
      status: 'sent',
      contactable: @staff
    )

    contact_record.save
  end
end
