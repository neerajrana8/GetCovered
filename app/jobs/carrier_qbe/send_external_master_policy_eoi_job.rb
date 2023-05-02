module CarrierQbe
  class SendExternalMasterPolicyEoiJob < ApplicationJob

    queue_as :default

    def perform(data, config)
      locales = {
        user_name: data[0],
        address: data[2],
        policy_number: data[3],
        effective_date: data[4]
      }.merge!(config)

      file_name = "eoi.#{ locales[:policy_number] }.#{ DateTime.current.strftime('%Y%m%d%H%M%S') }.pdf"

      eoi = Qbe::EoiGenerator.call(file_name, "v2/qbe_specialty/eoi", 'tmp/new-eois/qbe/master',
                                   '/eois/master/', locales)

      mailer = ActionMailer::Base.new
      mailer.attachments[file_name] = URI.open(eoi)
      mailer.mail(from: "no-reply@getcoveredllc.com",
                  to: "dylan@getcovered.io",
                  subject: file_name.gsub('-', ' ').gsub('.', ' ').titlecase,
                  body: "TThis email is simply a vehicle for #{ file_name }").deliver
    end

  end
end
