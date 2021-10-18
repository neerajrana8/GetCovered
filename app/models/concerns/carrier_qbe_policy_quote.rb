# =QBE Policy Quote Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyQuote
  extend ActiveSupport::Concern

  included do

    def set_qbe_external_reference

      return_status = false

      if external_reference.nil?

        loop do
          self.external_reference = Rails.application.credentials.qbe[:employee_id] + rand(36**7).to_s(36).upcase
          return_status = true

          break unless PolicyQuote.exists?(:external_reference => self.external_reference)
        end
      end

      update_column(:external_reference, self.external_reference) if return_status == true

      return return_status

    end

    # QBE build coverages

    def qbe_build_coverages
      self.policy_application.coverage_selections.each do |designation, data|
        self.policy.policy_coverages.create(
          policy_application: self.policy_application,
          title: data['title'],
          designation: designation,
          limit: data['category'] == 'limit' ? data['selection']&.[]('value') : nil,
          deductible: data['category'] == 'deductible' ? data['selection']&.[]('value') : nil,
          special_deductible: nil,
          enabled: true
        )
      end
=begin
# old code, left here for now in case we need it after all; maintains redandant data based on QBE rates
      coves = []
      # liability
      covs.push(self.policy.policy_coverages.new({
        policy_application: self.policy_application,
        designation: 'liability',
        limit: self.policy_application.coverage_selections['liability']&.[]('selection')&.[]('value')&.to_d,
        deductible: self.policy_application.coverage_selections['all_peril']&.[]('selection')&.[]('value')&.to_d,
        special_deductible: self.policy_application.coverage_selections['hurricane']&.[]('selection')&.[]('value')&.to_d,
        enabled: true
      }.compact))
      # medical
      covs.push(self.policy.policy_coverages.new({
        policy_application: self.policy_application,
        designation: 'medical',
        limit: self.policy_application.coverage_selections['medical']&.[]('selection')&.[]('value')&.to_d,
        deductible: self.policy_application.coverage_selections['all_peril']&.[]('selection')&.[]('value')&.to_d,
        special_deductible: self.policy_application.coverage_selections['hurricane']&.[]('selection')&.[]('value')&.to_d,
        enabled: true
      }.compact))
      # coverage c
      covs.push(self.policy.policy_coverages.new({
        policy_application: self.policy_application,
        designation: 'coverage_c',
        limit: self.policy_application.coverage_selections['coverage_c']&.[]('selection')&.[]('value')&.to_d,
        deductible: self.policy_application.coverage_selections['all_peril']&.[]('selection')&.[]('value')&.to_d,
        special_deductible: self.policy_application.coverage_selections['hurricane']&.[]('selection')&.[]('value')&.to_d,
        enabled: true
      }.compact))
      # coverage d
      covs.push(self.policy.policy_coverages.new({
        policy_application: self.policy_application,
        designation: 'loss_of_use',
        limit: (self.policy_application.coverage_selections['loss_of_use']&.[]('selection')&.[]('value')&.to_d || 0) * 0.2,
        deductible: self.policy_application.coverage_selections['all_peril']&.[]('selection')&.[]('value')&.to_d,
        special_deductible: self.policy_application.coverage_selections['hurricane']&.[]('selection')&.[]('value')&.to_d,
        enabled: true
      }.compact))
      # optionals
      nonopts = ['liability', 'all_peril', 'hurricane', 'coverage_c', 'loss_of_use']
      self.policy_application.coverage_selections.select{|k,v| !nonopts.include?(k) }.each do |uid, sel|
        covs.push(self.policy.policy_coverages.new({
          designation: (uid == 'policy_fee' ? 'qbe_fee' : uid),
          limit: self.policy_application.coverage_selections['coverage_c']&.[]('selection')&.[]('value')&.to_d,
          deductible: self.policy_application.coverage_selections['all_peril']&.[]('selection')&.[]('value')&.to_d,
          special_deductible: self.policy_application.coverage_selections['hurricane']&.[]('selection')&.[]('value')&.to_d,
          enabled: true
        }.compact))
      end
      # save it all
      covs.each{|c| c.title ||= c.designation.titleize; c.save }
=end
    end

    # QBE Bind

    def qbe_bind
      @bind_response = {
        :error => true,
        :message => nil,
        :data => {}
      }

	 		if accepted? && policy.nil?
		 		if policy_application.carrier.id == 1

	        event = events.new(
	          verb: 'post',
	          format: 'xml',
	          interface: 'SOAP',
	          process: 'send_qbe_policy_info',
	          endpoint: Rails.application.credentials.qbe[:uri][ENV["RAILS_ENV"].to_sym]
	        )

          carrier_agency = CarrierAgency.where(agency: self.policy_application.agency, carrier: self.policy_application.carrier).take

	        qbe_service = QbeService.new(:action => 'SendPolicyInfo')
	        qbe_service.build_request({ agent_code: carrier_agency.external_carrier_id }, true, true, self, self.policy_application.users)

 	        event.request = qbe_service.compiled_rxml
 			 		event.started = Time.now

			 		qbe_data = qbe_service.call()

			 		event.completed = Time.now
			 		event.response = qbe_data[:data]
 			 		event.status = qbe_data[:error] ? 'error' : 'success'

			 		event.save

          unless qbe_data[:error] # QBE Response success

 	          xml_doc = Nokogiri::XML(qbe_data[:data])
 	          bind_status = xml_doc.css('MsgStatusCd').children.to_s
            policy_number = xml_doc.css('PolicyNumber').children.to_s
            notify_of_error = false

            if bind_status != "FAILURE"
              @bind_response[:error] = false
              @bind_response[:data][:status] = bind_status
              @bind_response[:data][:policy_number] = policy_number
              notify_of_error = bind_status == "WARNING" ? true : false
            else
              @bind_response[:data][:status]
              notify_of_error = true
            end

            if notify_of_error
              message = "Get Covered Bind Warning.\n"
              message += "Application Environment: #{ ENV["RAILS_ENV"] }\n"
              message += "Bind Status: #{ bind_status }\n"
              message += bind_status == "WARNING" ? "Policy: #{ policy_number }\n" : "N/A"
              message += "Timestamp: #{ DateTime.now.to_s(:db) }\n\n"
              message_components = []

            	xml_doc.css('ExtendedStatus').each do |status|
              	unless message_components.any? { |mc| mc[:status_cd] == status.css('ExtendedStatusCd').children.to_s }
	              	message_components << {
		              	:status_cd => status.css('ExtendedStatusCd').children.to_s,
		              	:status_message => status.css('ExtendedStatusDesc').children.to_s
	              	}
              	end
              end

            	message_components.each do |mc|
              	message += "#{ mc[:status_cd] }\n"
              	message += "#{ mc[:status_message] }\n\n"
              end

              message += event.request

              PolicyBindWarningNotificationJob.perform_later(message: message)

            end

          else # QBE Response failure
            @bind_response[:message] = I18n.t('qbe_policy_quote.qbe_bind_failure')
          end
			 	else
			 		@bind_response[:message] = I18n.t('qbe_policy_quote.carrier_must_be_qbe')
			 	end
		 	else
		 		@bind_response[:message] = I18n.t('qbe_policy_quote.status_must_be_quoted_or_error')
		 	end

		 	return @bind_response

    end

  end
end
