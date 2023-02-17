class UserCoverageMailer < ApplicationMailer
  before_action { @user = params[:user] }
  before_action { @policy = params[:policy] }
  before_action { @quote = params[:quote] }
  before_action { @links = params[:links] }
  before_action :check_user_preference

  default to: -> { @user.email },
          from: -> { 'no-reply@getcoveredinsurance.com' },
          bcc: -> { 'systememails@getcovered.io' }

  def coverage_required
    mail(
      :subject => 'Get Renters Insurance'
    )
  end

  def coverage_required_follow_up
    mail(
      :subject => 'FOR THE LOVE OF GOD GET RENTERS INSURANCE'
    )
  end

  def acceptance_email
    @title = 'Rent Guarantee'

    @text = "Hello #{ @user.profile.full_name },<br><br>Thank you for choosing Pensio Tenants.<br>﻿Your Rent Guarantee registration has been accepted on #{ Time.current.strftime('%m/%d/%y') }.<br>You can accept your Rent Guarantee by <a href=\"#{ whitelabel_host(@policy.agency) }/rentguarantee/confirm/#{ @user.raw_invitation_token }?policy_id=#{ @policy.id }\">clicking here</a>.<br><br>Kind Regards,<br>Pensio Tenants Corp & the Get Covered Team<br><br>Keeping You At Home!"

    mail(:subject => "Your New #{ @title }")

  end


  def qbe_proof_of_coverage
    @policy.reload()
    unless @policy.sent?
      @user_name = @user&.profile&.full_name
      I18n.locale = @user&.profile&.language if @user&.profile&.language&.present?

      attachments["evidence-of-insurance.pdf"] = {
        mime_type: "application/pdf",
        encoding: "base64",
        content: Base64.strict_encode64(@policy.documents.last.download)
      }

      @agency_account_name = @policy.account&.title || @policy.agency&.title

      subject = "#{@agency_account_name} - #{t('user_coverage_mailer.qbe_proof_of_coverage.subject')}"
      mail(to: @user.email, subject: subject, from: "support@getcoveredinsurance.com")
      return true
    else
      return false
    end
  end

  def proof_of_coverage
    unless @policy.carrier_id == 1
      attach_all_documents

      @user_name = @user&.profile&.full_name
      I18n.locale = @user&.profile&.language if @user&.profile&.language&.present?
      @accepted_on = Time.current.strftime('%m/%d/%y')
      @site = whitelabel_host(@policy.agency)

      @content =
        if @policy.policy_type_id == 5
          documents =
            if @policy&.documents&.any?
              I18n.t('user_coverage_mailer.all_documents.rent_guarantee_documents')
            else
              ''
            end
          {
            subject: I18n.t('user_coverage_mailer.all_documents.rent_guarantee_title'),
            text: I18n.t('user_coverage_mailer.all_documents.rent_guarantee_text',
                         site: @site, accepted_on: @accepted_on, documents: documents, user_name: @user_name)
          }
        else
          documents =
            if @policy&.documents&.any?
              I18n.t('user_coverage_mailer.all_documents.other_documents')
            else
              ''
            end
          {
            subject: I18n.t('user_coverage_mailer.all_documents.other_title'),
            text: I18n.t('user_coverage_mailer.all_documents.other_text',
                         site: @site, accepted_on: @accepted_on, documents: documents, user_name: @user_name)
          }
        end

      mail(:subject => @content[:subject])
    else
      return false
    end
  end

  def all_documents
    unless @policy.nil? || @user.nil?

      @user_name = @user&.profile&.full_name
      I18n.locale = @user&.profile&.language if @user&.profile&.language&.present?
      @accepted_on = Time.current.strftime('%m/%d/%y')
      @site = whitelabel_host(@policy.agency)

      @content =
        if @policy.policy_type_id == 5
          documents =
            if @policy&.documents&.any?
              I18n.t('user_coverage_mailer.all_documents.rent_guarantee_documents')
            else
              ''
            end
          {
            subject: I18n.t('user_coverage_mailer.all_documents.rent_guarantee_title'),
            text: I18n.t('user_coverage_mailer.all_documents.rent_guarantee_text',
                         site: @site, accepted_on: @accepted_on, documents: documents, user_name: @user_name)
          }
        else
          documents =
            if @policy&.documents&.any?
              I18n.t('user_coverage_mailer.all_documents.other_documents')
            else
              ''
            end
          {
            subject: I18n.t('user_coverage_mailer.all_documents.other_title'),
            text: I18n.t('user_coverage_mailer.all_documents.other_text',
                         site: @site, accepted_on: @accepted_on, documents: documents, user_name: @user_name)
          }
        end
      @policy.documents.each do |doc|
        file_url = Rails.application.routes.url_helpers.rails_blob_url(doc, host: Rails.application.credentials[:uri][ENV['RAILS_ENV'].to_sym][:api]).to_s
        attachments[doc.filename.to_s] = open(file_url).read
      end
      mail(:subject => @content[:subject])
    else
      return false
    end
  end

  def commercial_quote
    file_url = "#{Rails.application.credentials.uri[ENV["RAILS_ENV"].to_sym][:api]}#{Rails.application.routes.url_helpers.rails_blob_path(@quote.documents.last, only_path: true)}"
    attachments["quote-#{ @quote.external_id }.pdf"] = open(file_url).read
    mail(:subject => 'Your New Insurance Quote')
  end

  def added_to_policy
    mail(:subject => 'You have been added to a new policy')
  end

  def policy_expiring

    mail(
      :subject => 'Your policy is expiring'
    )
  end

  def payment_expiring
    mail(
      :subject => "Your payment method for Policy ##{@policy.number} is expiring"
    )
  end

  def auto_pay_fail
    mail(
      :subject => "Autopayment for Policy #{@policy.number} failed."
    )
  end

  def late_payment
    mail(
      :subject => "Payment for Policy ##{@policy.number} is past due."
    )
  end

  def late_payment_cancellation
    mail(
      :subject => "Policy ##{@policy.number} cancelled for lack of payment."
    )
  end

  def policy_in_default
    @url = BrandingProfiles::FindByObject.run!(object: @policy.agency)&.url ||
        Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]

    @missed_invoices = @policy.invoices.missed
    @next_invoice = @policy.invoices.upcoming.order(:due_date).first

    mail(
        :subject => "Policy ##{@policy.number} in default.  Please update Payment information"
    )
  end

  private

  def attach_all_documents
    @policy.documents.each do |doc|
      file_url = Rails.application.routes.url_helpers.rails_blob_url(doc, host: Rails.application.credentials[:uri][ENV['RAILS_ENV'].to_sym][:api]).to_s
      attachments[doc.filename.to_s] = open(file_url).read
    end
  end

  def whitelabel_host(agency)
    BrandingProfiles::FindByObject.run!(object: agency)&.url ||
      Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]
  end

  def check_user_preference
    return false if @user.nil?
  end

end
