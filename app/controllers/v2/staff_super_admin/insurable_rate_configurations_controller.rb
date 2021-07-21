
module V2
  module StaffSuperAdmin
    class InsurableRateConfigurationsController < StaffSuperAdminController

      def get_parent_options
        return if Rails.env == 'production' # just in case since this is temporary
        # grab params
        return unless unpack_params
        # grab some useful stuff
        configurer_list = [account, agency]
        configurer_list.push(configurer_list.last.agency) while !configurer_list.last.agency.nil?
        carrier_insurable_type = CarrierInsurableType.where(carrier_id: 5, insurable_type_id: 4).take
        usa = InsurableGeographicalCategory.get_for(state: nil)
        
        
        
        
        
        
      
        # grab params
        agency = Agency.where(id: params[:id].to_i).take
        if agency.nil?
          render json: standard_error(:agency_not_found, "No agency with the provided id (#{params[:id] || 'null'}) was found", nil),
            status: 422
          return
        end
        # grab some useful stuff
        agency_list = [agency]
        agency_list.push(agency_list.last.agency) while !agency_list.last.agency.nil?
        carrier_insurable_type = CarrierInsurableType.where(carrier_id: 5, insurable_type_id: 4).take
        usa = InsurableGeographicalCategory.get_for(state: nil)
        # calculate parent options
        parent_ircs = (agency_list.drop(1) + [Carrier.find(5)]).reverse.map do |configurer|
          ::InsurableRateConfiguration.new(
            carrier_insurable_type: carrier_insurable_type,
            configurer: configurer,
            configurable: usa,
            carrier_info: {},
            rules: {},
            coverage_options: combine_option_sets(
              *InsurableRateConfiguration.where(configurer: configurer, configurable_type: "InsurableGeographicalCategory", carrier_insurable_type: carrier_insurable_type)
                                          .map{|irc| irc.coverage_options }
            ).values
          )
        end
        coverage_options = []
        parent_ircs.each do |irc|
          irc.merge_parent_options!(coverage_options, mutable: false, allow_new_coverages: InsurableRateConfiguration::COVERAGE_ADDING_CONFIGURERS.include?(irc.configurer_type))
          coverage_options = irc.coverage_options
        end
        coverage_options.select!{|co| co['enabled'] != false }
        # calculate our own options
        agency_irc = ::InsurableRateConfiguration.where(carrier_insurable_type: carrier_insurable_type, configurer: agency, configurable: usa).take || ::InsurableRateConfiguration.new(coverage_options: [])
        # annotate with our stuff
        coverage_options.select!{|co| co['options_type'] == 'multiple_choice' }
        coverage_options.each do |opt|
          found = agency_irc.coverage_options.find{|co| co['uid'] == opt['uid'] }
          if found.nil?
            opt['allowed_options'] = opt['options'].dup
          elsif found['enabled'] == false
            opt['allowed_options'] = []
          elsif found['options'].nil?
            opt['allowed_options'] = opt['options'].dup
          else
            opt['allowed_options'] = found['options'] & opt['options']
          end
        end
        # return it all
        render json: coverage_options, status: :ok
        return
      end
      
      def set_options
        return if Rails.env == 'production' # just in case since this is temporary
   
        # grab params
        agency = Agency.where(id: params[:id].to_i).take
        if agency.nil?
          render json: standard_error(:agency_not_found, "No agency with the provided id (#{params[:id] || 'null'}) was found", nil),
            status: 422
          return
        end
        covopts = set_options_params[:coverage_options]
        if covopts.blank?
          render json: { success: true }, status: :ok
          return
        end
        # grab models
        carrier_insurable_type = CarrierInsurableType.where(carrier_id: 5, insurable_type_id: 4).take
        usa = InsurableGeographicalCategory.get_for(state: nil)
        agency_irc = ::InsurableRateConfiguration.where(carrier_insurable_type: carrier_insurable_type, configurer: agency, configurable: usa).take ||
                     ::InsurableRateConfiguration.new(carrier_insurable_type: carrier_insurable_type, configurer: agency, configurable: usa, coverage_options: [])
        # update options
        covopts.each do |opt|
          opt['options'] = opt['allowed_options'] # simple way to let the user pass 'allowed_options' instead but leave this code IRC generic
          found_index = agency_irc.coverage_options.find_index{|co| co&.[]('uid') == opt['uid'] }
          if opt['options'].nil?
            agency_irc.coverage_options[found_index] = nil unless found_index.nil?
          elsif opt['options'].blank?
            if found_index.nil?
              agency_irc.coverage_options.push({ 'uid' => opt['uid'], 'category' => opt['category'], 'enabled' => false })
            else
              agency_irc.coverage_options[found_index]['enabled'] = false
            end
          else
            if found_index.nil?
              agency_irc.coverage_options.push({ 'uid' => opt['uid'], 'category' => opt['category'], 'options' => opt['options'] })
            else
              agency_irc.coverage_options[found_index]['options'] = opt['options']
            end
          end
        end
        agency_irc.coverage_options.compact!
        if agency_irc.save
          render json: { success: true}, status: :ok
        else
          render json: standard_error(:insurable_rate_configuration_update_failed, "Failed to apply updates!", agency_irc.errors.to_h),
            status: 422
        end
        return
      end

      private
      
        def set_options_params
          params.require(:insurable_rate_configuration).permit(coverage_options: [:uid, :category, allowed_options: [] ])
        end
        
        def unpack_params
          # get account & agency
          @account = nil
          @agency = nil
          case params[:type]
            when 'Account'
              @account = Account.where(id: params[:id].to_i).take
              if @account.nil?
                render json: standard_error(:account_not_found, "No account with the provided id (#{params[:id] || 'null'}) was found", nil),
                  status: 422
                return
              end
              @agency = @account.agency
            when 'Agency'
              @agency = Agency.where(id: params[:id].to_i).take
            else
              render json: standard_error(:unsupported_configurable, "It is not possible to customize rates for an object of type '#{params[:type] || 'null'}'", nil),
                status: 422
              return
          end
          if @agency.nil?
            render json: standard_error(:agency_not_found, "No agency with the provided id (#{params[:id] || 'null'}) was found", nil),
              status: 422
            return
          end
          # get carrier, insurable type, & carrier_insurable_type
          @carrier = nil
          @insurable_type_id = nil
          @carrier_insurable_type = nil
          if params[:carrier_insurable_type_id]
            @carrier_insurable_type = ::CarrierInsurableType.where(id: params[:carrier_insurable_type_id].to_i).take
            @carrier = @carrier_insurable_type&.carrier
            @insurable_type_id = @carrier_insurable_type&.insurable_type_id
          else
            @carrier = ::Carrier.where(id: params[:carrier_id].to_i).take
            @insurable_type_id = params[:insurable_type_id].nil? ? nil : params[:insurable_type_id].to_i
            @carrier_insurable_type = ::CarrierInsurableType.where(carrier_id: @carrier&.id, insurable_type_id: @insurable_type_id).take
          end
          if !params[:carrier_insurable_type_id] && @carrier.nil?
            render json: standard_error(:carrier_not_found, "No carrier with id #{@carrier.id || 'null'} was found", nil),
              status: 422
            return
          elsif !params[:carrier_insurable_type_id] && @insurable_type_id.nil?
            render json: standard_error(:insurable_type_not_found, "No insurable type with id #{@insurable_type_id || 'null'} was found", nil),
              status: 422
            return
          elsif @carrier_insurable_type.nil?
            render json: standard_error(:carrier_insurable_type_not_found, "No carrier insurable type with #{params[:carrier_insurable_type_id] ? "id #{params[:carrier_insurable_type_id]}" : "carrier id #{@carrier&.id || 'null'} and insurable type id #{@insurable_type_id || 'null'}"} was found", nil),
              status: 422
            return
          end
          # return success
          return true
        end

        def combine_option_sets(*option_sets)
          return [] if option_sets.blank?
          req_rankings = { 'forbidden' => 0, 'required' => 1, 'optional' => 2 }
          to_return = {}
          option_sets.each do |opts|
            opts.select{|opt| opt['enabled'] != false && opt['options_type'] == 'multiple_choice' }.each do |opt|
              if to_return[opt['uid']].blank?
                to_return[opt['uid']] = {
                  'uid' => opt['uid'],
                  'title' => opt['title'],
                  'enabled' => true,
                  'category' => opt['category'],
                  'requirement' => opt['requirement'],
                  'options_type' => opt['options_type'],
                  'options_format' => opt['options_format'],
                  'options' => opt['options']
                }
              else
                to_return[opt['uid']]['options'] += (opt['options'] || [])
                to_return[opt['uid']]['options'].uniq!
                to_return[opt['uid']]['options'].sort!
                to_return[opt['uid']]['requirement'] = opt['requirement'] if req_rankings[opt['requirement']] > req_rankings[to_return[opt['uid']]['requirement']]
              end
            end
            opts.select{|opt| opt['enabled'] != false && opt['options_type'] == 'none' }.each do |opt|
              next if to_return.has_key?(opt['uid'])
              to_return[opt['uid']] = {
                'uid' => opt['uid'],
                'title' => opt['title'],
                'enabled' => true,
                'category' => opt['category'],
                'requirement' => opt['requirement'],
                'options_type' => opt['options_type']
              }
            end
          end
          return to_return
        end


    end
  end
end
