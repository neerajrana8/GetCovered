module IntegrationsMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_namespace_and_account
    before_action :set_substrate, only: :index
    before_action :set_provider, except: :index
    before_action :set_integration, except: :index # yes, even in create; we want to see if the thing exists already
  end

  def index
    render json: standard_error(:does_not_exist, "No integration index functionality exists yet."),
      status: 404
  end
  
  def show
    # render a blank integration inside of here, no need to bother returning
    if @integration.nil?
      case @provider
        when 'yardi'
          render json: {
            exists: false,
            renters_insurance: (@namespace == 'staff_account' ? {
              username: nil,
              password: nil,
              database_server: nil,
              database_name: nil,
              url: nil
            } : {}).merge({
              enabled: nil,
              active: false,
              problems: ["The integration has not been set up yet."]
            }),
            billing_and_payments: (@namespace == 'staff_account' ? {
              username: nil,
              password: nil,
              database_server: nil,
              database_name: nil,
              url: nil
            } : {}).merge({
              enabled: nil,
              active: false,
              master_policy_charge_code: nil,
              master_policy_gla: nil,
              available_charge_settings: [],
              problems: ["The integration has not been set up yet."]
            }),
            sync: {
              syncable_communities: [],
              sync_history: [],
              next_sync: nil,
              pull_policies: false,
              push_policies: false,
              push_master_policy_invoices: false,
              master_policy_charge_description: nil
            }
          }, status: 404
        else
          render json: standard_error(:integration_not_found, "No #{@provider.titleize} integration could be found for your account."),
            status: 404
      end
      return
    end
    unimplemented_provider = false
    # render an integration inside of here, no need to bother returning
    case @provider
      when 'yardi'
        @integration.credentials ||= {}
        @integration.credentials['voyager'] ||= {}
        @integration.credentials['billing'] ||= {}
        @integration.credentials['urls'] ||= {}
        @integration.configuration ||= {}
        @integration.configuration['renters_insurance'] ||= {}
        @integration.configuration['billing_and_payments'] ||= {}
        render json: {
          exists: true,
          renters_insurance: (@namespace == 'staff_account' ? {
            username: @integration.credentials['voyager']['username'],
            password: @integration.credentials['voyager']['password'],
            database_server: @integration.credentials['voyager']['database_server'],
            database_name: @integration.credentials['voyager']['database_name'],
            url: @integration.credentials['urls']['renters_insurance']
          } : {}).merge({
            enabled: @integration.configuration['renters_insurance']['enabled'],
            active: @integration.configuration['renters_insurance']['active'],
            problems: @integration.configuration['renters_insurance']['configuration_problems']
          }),
          billing_and_payments: (@namespace == 'staff_account' ? {
            username: @integration.credentials['billing']['username'],
            password: @integration.credentials['billing']['password'],
            database_server: @integration.credentials['billing']['database_server'],
            database_name: @integration.credentials['billing']['database_name'],
            url: @integration.credentials['urls']['billing_and_payments']
          } : {}).merge({
            available_charge_settings: @integration.configuration['billing_and_payments']['available_charge_settings'],
            master_policy_charge_code: @integration.configuration['billing_and_payments']['master_policy_charge_code'],
            master_policy_gla: @integration.configuration['billing_and_payments']['master_policy_gla'],
            enabled: @integration.configuration['billing_and_payments']['enabled'],
            active: @integration.configuration['billing_and_payments']['active'],
            problems: @integration.configuration['billing_and_payments']['configuration_problems']
          }),
          sync: {
            syncable_communities: @integration.configuration['sync']['syncable_communities'],
            sync_history: [], # disabled until log system properly set up @integration.configuration['sync']['sync_history'],
            next_sync: @integration.configuration['sync']['next_sync'],
            pull_policies: @integration.configuration['sync']['pull_policies'],
            push_policies: @integration.configuration['sync']['push_policies'],
            push_master_policy_invoices: @integration.configuration['sync']['push_master_policy_invoices'],
            master_policy_charge_description: @integration.configuration['sync']['master_policy_invoices']['charge_description']
          }
        }, status: 200
      else
        render json: standard_error(:integration_not_found, "This interface has not yet been updated with support for #{@provider.titleize} integrations."),
          status: 422
    end
    return
  end
  
  
  def create
    if @integration
      render json: standard_error(:integration_already_exists, "An integration already exists for #{@provider.titleize}."),
        status: 422
      return
    end
    case @provider
      when 'yardi'
        created = ::Integration.new(
          integratable: @account,
          provider: @provider,
          credentials: {},
          configuration: {}
        )
        { renters_insurance: :voyager, billing_and_payments: :billing }.each do |interface, cred_section|
          [:username, :password, :database_server, :database_name].each do |field|
            created.credentials[cred_section.to_s][field.to_s] = yardi_create_params[interface][field] if yardi_create_params[interface]&.has_key?(field)
          end
          created.credentials['urls'][interface.to_s] = yardi_create_params[interface]['url'] if yardi_create_params[interface]&.has_key?('url')
          created.configuration[interface.to_s]['enabled'] = yardi_create_params[interface]['enabled'] if yardi_create_params[interface]&.has_key?('enabled')
        end
        if !created.id
          render json: standard_error(:error_creating_integration, "#{created.errors.to_h}"),
            status: 422
        else
          @integration = Integrations::Yardi::Refresh.run!(integration: @integration)
          show # we just call show to render what we've made
        end
      else
        render json: standard_error(:integration_not_found, "This interface has not yet been updated with support for #{@provider.titleize} integrations."),
          status: 422
    end
    return
  end
  
  
  def update
    if @integration.nil?
      render json: standard_error(:integration_not_found, "No #{@provider.titleize} integration could be found for your account."),
        status: 404
      return
    end
    case @provider
      when 'yardi'
        # update interface's fields
        { renters_insurance: :voyager, billing_and_payments: :billing }.each do |interface, cred_section|
          [:username, :password, :database_server, :database_name].each do |field|
            @integration.credentials[cred_section.to_s][field.to_s] = yardi_update_params[interface][field] if yardi_update_params[interface]&.has_key?(field)
          end
          @integration.credentials['urls'][interface.to_s] = yardi_update_params[interface]['url'] if yardi_update_params[interface]&.has_key?('url')
          @integration.configuration[interface.to_s]['enabled'] = yardi_update_params[interface]['enabled'] if yardi_update_params[interface]&.has_key?('enabled')
        end
        @integration.configuration['billing_and_payments']['master_policy_charge_code'] = yardi_update_params['billing_and_payments']&.has_key?('master_policy_charge_code')
        @integration.configuration['billing_and_payments']['master_policy_gla'] = yardi_update_params['billing_and_payments']&.has_key?('master_policy_gla')
        # update syncable community enablings
        yups = (yardi_update_params['sync']['syncable_communities'] rescue {})
        @integration.configuration['sync']['syncable_communities'].each do |k,v|
          v['enabled'] = yups[k.to_sym][:enabled] if yups.has_key?(k.to_sym) && yups[k.to_sym].has_key?(:enabled)
        end
        # update generic sync settings
        ['pull_policies', 'push_policies', 'push_master_policy_invoices'].each do |k,v|
          next unless yardi_update_params[:sync]&.has_key?(k)
          @integration.configuration['sync'][k] = yardi_update_params[:sync][k]
        end
        if yardi_update_params[:sync].has_key?('master_policy_charge_description') && yardi_update_params[:sync].has_key?('master_policy_charge_description').class == ::String
          @integration.configuration['sync']['master_policy_invoices']['charge_description'] = yardi_update_params[:sync]['master_policy_charge_description']
        end
        # try saving
        if !@integration.save
          render json: standard_error(:error_creating_integration, "#{created.errors.to_h}"),
            status: 422
        else
          @integration = Integrations::Yardi::Refresh.run!(integration: @integration)
          show # we just call show to render the updates
        end
      else
        render json: standard_error(:integration_not_found, "This interface has not yet been updated with support for #{@provider.titleize} integrations."),
          status: 422
    end
    return 
  end
      
  private
  
    def set_provider
      @provider = params[:provider].to_s
    end
    
    def set_integration
      @integration = ::Integration.where(integratable: @account, provider: params[:provider].to_s).take # WARNING: does not throw error via .find() like some controllers
    end

    def yardi_create_params
      if @namespace == 'staff_account'
        params.permit(
          renters_insurance: [:username, :password, :database_server, :database_name, :url, :enabled],
          billing_and_payments: [:username, :password, :database_server, :database_name, :url, :master_policy_charge_code, :master_policy_gla, :enabled],
          sync: [ :pull_policies, :push_policies, :push_master_policy_invoices, :master_policy_charge_description ]
        )
      else
        {}
      end
    end

    def yardi_update_params
      if @namespace == 'staff_account'
        params.permit({
          renters_insurance: [:username, :password, :database_server, :database_name, :url, :enabled],
          billing_and_payments: [:username, :password, :database_server, :database_name, :url, :master_policy_charge_code, :master_policy_gla, :enabled],
          sync: [
            :pull_policies, :push_policies, :push_master_policy_invoices, :master_policy_charge_description,
            syncable_communities: [@integration.configuration['sync']['syncable_communities'].map do |k,v|
              [k, [:enabled]]
            end.to_h]
          ]
        })
      else
        {}
      end
    end

    def set_substrate
      @substrate = access_model(::Integration)
    end

    def supported_orders
      supported_filters(true)
    end

    def update_allowed?
      true
    end
    
    def set_namespace_and_account
      @account = nil
      @namespace = nil
      
      if current_staff&.respond_to?(:staff_roles)
        if request.original_fullpath.include?("staff_super_admin") && current_staff.staff_roles.exists?(role: 'super_admin', enabled: true) 
          @namespace = 'staff_super_admin'
          @account = Account.find(params[:account_id].to_i)
        else
          @namespace = 'staff_account'
          @account = current_staff.staff_roles.where(enabled: true, active: true, organizable_type: 'Account').take.organizable
        end
      else
        if request.original_fullpath.include?("staff_super_admin")
          @account = Account.where(params[:account_id].to_i).take
          @namespace = "staff_super_admin"
        elsif request.original_fullpath.include?("staff_account")
          @account = current_staff&.organizable
          @namespace = "staff_account"
        end
      end
      
      if @account.nil? || @namespace.nil?
        render json: {}, status: 404 # apparently rendering in a before_action aborts the rest of the handling, woohoo
      end
      
    end
end
