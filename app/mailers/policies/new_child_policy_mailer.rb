module Policies
  # NewChildPolicyMailer
  class NewChildPolicyMailer < ApplicationMailer
    def notify
      mail(to: params[:user].contact_email,
           bcc: 'systememails@getcovered.io',
           from: 'policyverify@getcovered.io',
           subject: 'Master Policy Enrollment Confirmation',
           body: "Policy issued #{params[:policy].id}")
    end

    def body_text
      "Hi
#{params[:user][:profile][:first_name]} #{params[:user][:profile][:lastname_name]}
,
Thank you, the Master Policy has been activated for your unit.
#{params[:community][:title]} , #{params[:insurable][:title]}
You are now in compliance with the insurance requirement per your
lease agreement.
As a reminder
, you will be charged
[Master Policy
Fee]
each month.
Please respond to this email if you have questions.
Thank you for your
prompt attention to this matter
."
    end
  end
end
