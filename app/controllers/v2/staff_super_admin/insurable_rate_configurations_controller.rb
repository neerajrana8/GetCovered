
module V2
  module StaffSuperAdmin
    class InsurableRateConfigurationsController < StaffSuperAdminController

      def get_parent_options
        return if Rails.env == 'production' # just in case since this is temporary
        # grab params
        return unless unpack_params(default_carrier_policy_type: CarrierPolicyType.where(carrier_id: 5, policy_type_id: 1).take)
        # grab our boyo
        configurer = (@account || @agency || @carrier)
        irc = ::InsurableRateConfiguration.get_inherited_irc(@carrier_policy_type, configurer, @configurable, agency: @agency, exclude: :children_inclusive, union_mode: true) # WARNING: DOES UNION_MODE WORK???
        coverage_options = ::InsurableRateConfiguration.remove_overridability_data!(
          irc.configuration['coverage_options'].select do |uid, co|
            co['options_type'] == 'multiple_choice' &&
            (
              co['requirement'] != 'forbidden' ||
              irc.configuration['rules'].any?{|rule_name, rule_data| rule_data['subject'] == uid && rule_data['rule'].any?{|rewl, parmz| rewl == 'has_requirement' && parmz != 'forbidden' } }
            ) # WARNING: we don't do any overridability checks here, but we really should... a rule that can't override the requirement value shouldn't count.
          end
        )
        # get our target entity's options
        entity_covopts = ::InsurableRateConfiguration.remove_overridability_data!(
          (
            ::InsurableRateConfiguration.where(carrier_policy_type: @carrier_policy_type, configurer: configurer, configurable: @configurable).take || ::InsurableRateConfiguration.new(configuration: { 'coverage_options' => {} })
          ).configuration['coverage_options']
        )
        # annotate with our stuff
        coverage_options.each do |uid, opt|
          found = entity_covopts[uid]
          if found.nil?
            opt['allowed_options'] = opt['options'].dup
          elsif found['requirement'] == 'forbidden'
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
        return unless unpack_params(default_carrier_policy_type: CarrierPolicyType.where(carrier_id: 5, policy_type_id: 1).take)
        covopts = set_options_params[:coverage_options]
        if covopts.blank?
          render json: { success: true }, status: :ok
          return
        end
        # grab models
        configurer = @account || @agency # WARNING: no carrier option, because we don't want people screwing up the carrier configurations
        entity_irc = ::InsurableRateConfiguration.where(carrier_policy_type: @carrier_policy_type, configurer: configurer, configurable: @configurable).take ||
                     ::InsurableRateConfiguration.new(carrier_policy_type: @carrier_policy_type, configurer: configurer, configurable: @configurable, configuration: { 'coverage_options' => {} })
        entity_covopts = entity_irc.configuration['coverage_options']
        # update options
        covopts.each do |uid, opt|
          opt['options'] = opt['allowed_options'] # simple way to let the user pass 'allowed_options' instead but leave this code IRC generic
          found = entity_covopts[uid]
          if opt['options'].nil?
            entity_covopts[uid] = nil unless found.nil?
          elsif opt['options'].blank?
            if found.nil?
              entity_covopts[uid] = { 'requirement' => 'forbidden' } # MOOSE WARNING: rules from carrier that set requirement to optional will still override this... which should NOT be the case. Only setting req to 'required' should override this. Fix it to work that way.
            else
              found['requirement'] = 'forbidden'
            end
          else
            if found.nil?
              entity_covopts[uid] = { 'options' => opt['options'] }
            else
              found.delete('requirement') if found['requirement'] == 'forbidden'
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
        
        def unpack_params(default_carrier_policy_type: nil)
          # get account & agency & configurable
          @account = nil
          @agency = nil
          @configurable = nil
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
            when 'Insurable'
              @configurable = Insurable.where(id: params[:id].to_i).take
              if @configurable.nil?
                render json: standard_error(:insurable_not_found, "No insurable with the provided id (#{params[:id] || 'null'}) was found", nil),
                  status: 422
                return
              elsif !InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(@configurable.insurable_type_id)
                render json: standard_error(:insurable_invalid, "The requested insurable has type '#{@configurable.insurable_type.title}'; only residential community types support customized coverage options", nil),
                  status: 422
                return
              end
              @account = @configurable&.account
              if @account.nil?
                render json: standard_error(:account_not_found, "The selected insurable is not associated with a property manager account; its coverage options cannot be customized", nil),
                  status: 422
                return
              end
              @agency = @account&.agency
            else
              render json: standard_error(:unsupported_configurable, "It is not possible to customize coverage options for an object of type '#{params[:type] || 'null'}'", nil),
                status: 422
              return
          end
          if @agency.nil?
            render json: standard_error(:agency_not_found, "No agency with the provided id (#{params[:id] || 'null'}) was found", nil),
              status: 422
            return
          end
          @configurable ||= InsurableGeographicalCategory.get_for(state: nil)
          # get carrier, policy type id, & carrier_policy_type
          @carrier = nil
          @policy_type_id = nil
          @carrier_policy_type = nil
          if params[:carrier_policy_type_id] || default_carrier_policy_type
            @carrier_policy_type = default_carrier_policy_type || ::CarrierPolicyType.where(id: params[:carrier_policy_type_id].to_i).take
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

    end
  end
end
