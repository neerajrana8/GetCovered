module Policies
  # NewChildPolicyMailer
  class NewChildPolicyMailer < ApplicationMailer
    def notify
      mail(to: params[:user].contact_email,
           bcc: 'systememails@getcovered.io',
           from: 'policyverify@getcovered.io',
           subject: 'Your policy is issued',
           body: "Policy issued #{params[:policy].id}")
    end
  end
end
