
module V2
  module StaffSuperAdmin
    class InsurableRateConfigurationsController < StaffSuperAdminController

      def get_parent_options
        return if Rails.env == 'production' # just in case since this is temporary
        # grab params
        return unless unpack_params
        # grab our boyo
        configurable = InsurableGeographicalCategory.get_for(state: nil)
        configurer = (@account || @agency || @carrier)
        irc = ::InsurableRateConfiguration.get_inherited_irc(@carrier_policy_type, configurer, configurable, agency: @agency, exclude: :children_inclusive, union_mode: true) # MOOSE WARNING: DOES UNION_MODE WORK???
        coverage_options = ::InsurableRateConfiguration.remove_overridability_data!(
          irc.configuration['coverage_options'].select do |uid, co|
            co['options_type'].include?('multiple_choice') &&
            (
              co['requirement'].include?('forbidden') ||
              irc.configuration['rules'].any?{|rule_name, rule_datas| rule_datas.any?{|rule_data| rule_data['subject'] == uid && rule_data['rule'].any?{|rewl, parmz| rewl == 'has_requirement' && parmz != 'forbidden' } } }
            )
          end
        ) # MOOSE WARNING: we don't do any overridability checks here, but we really should
        # get our target entity's options
        entity_irc = ::InsurableRateConfiguration.where(carrier_policy_type: @carrier_policy_type, configurer: configurer, configurable: configurable).take || ::InsurableRateConfiguration.new(configuration: { 'coverage_options' => {} })
        # annotate with our stuff
        coverage_options.each do |uid, opt|
          found = entity_irc.configuration['coverage_options'][uid]
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
        return unless unpack_params
        covopts = set_options_params[:coverage_options]
        if covopts.blank?
          render json: { success: true }, status: :ok
          return
        end
        # grab models
        configurable = InsurableGeographicalCategory.get_for(state: nil)
        configurer = @account || @agency
        entity_irc = ::InsurableRateConfiguration.where(carrier_policy_type: @carrier_policy_type, configurer: configurer, configurable: configurable).take ||
                     ::InsurableRateConfiguration.new(carrier_policy_type: @carrier_policy_type, configurer: configurer, configurable: configurable, configuration: { 'coverage_options' => {} })
        entity_covopts = entity_irc.configuration['coverage_options']
        # update options
        covopts.each do |uid, opt|
          opt['options'] = opt['allowed_options'] # simple way to let the user pass 'allowed_options' instead but leave this code IRC generic
          found = entity_covopts[uid]
          if opt['options'].nil?
            entity_covopts[uid] = nil unless found.nil?
          elsif opt['options'].blank?
            if found.nil?
              entity_covopts[uid] = { 'requirement' => 'forbidden' }
            else
              found['requirement'] = 'forbidden'
            end
          else
            if found.nil?
              entity_covopts[uid] = { 'options' => opt['options'] }
            else
              found['options'] = opt['options']
            end
          end
        end
        entity_covopts.compact!
        if entity_irc.save
          render json: { success: true}, status: :ok
        else
          render json: standard_error(:insurable_rate_configuration_update_failed, "Failed to apply updates!", entity_irc.errors.to_h),
            status: 422
        end
        return
      end

      private
      
        def set_options_params
          params.require(:insurable_rate_configuration).permit(coverage_options: {})
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
          # get carrier, policy type id, & carrier_policy_type
          @carrier = nil
          @policy_type_id = nil
          @carrier_policy_type = nil
          if params[:carrier_policy_type_id]
            @carrier_policy_type = ::CarrierPolicyType.where(id: params[:carrier_policy_type_id].to_i).take
            @carrier = @carrier_policy_type&.carrier
            @policy_type_id = @carrier_policy_type&.policy_type_id
          else
            @carrier = ::Carrier.where(id: params[:carrier_id].to_i).take
            @policy_type_id = params[:policy_type_id].nil? ? nil : params[:policy_type_id].to_i
            @carrier_policy_type = ::CarrierPolicyType.where(carrier_id: @carrier&.id, policy_type_id: @policy_type_id).take
          end
          if !params[:carrier_policy_type_id] && @carrier.nil?
            render json: standard_error(:carrier_not_found, "No carrier with id #{@carrier.id || 'null'} was found", nil),
              status: 422
            return
          elsif !params[:carrier_policy_type_id] && @policy_type_id.nil?
            render json: standard_error(:policy_type_not_found, "No policy type with id #{@policy_type_id || 'null'} was found", nil),
              status: 422
            return
          elsif @carrier_policy_type.nil?
            render json: standard_error(:carrier_policy_type_not_found, "No carrier policy type with #{params[:carrier_policy_type_id] ? "id #{params[:carrier_policy_type_id]}" : "carrier id #{@carrier&.id || 'null'} and policy type id #{@policy_type_id || 'null'}"} was found", nil),
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
