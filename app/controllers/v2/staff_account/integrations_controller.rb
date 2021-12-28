module V2
  module StaffAccount
    class IntegrationsController < StaffAccountController
      before_action :set_substrate, only: :index
      before_action :set_provider, except: :index
      before_action :set_integration, except: :index # yes, even in create; we want to see if the thing exists already
      
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
                renters_insurance: {
                  username: nil,
                  password: nil,
                  database_server: nil,
                  database_name: nil,
                  url: nil,
                  enabled: nil,
                  active: false,
                  problems: "The integration has not been set up yet."
                },
                billing_and_payments: {
                  username: nil,
                  password: nil,
                  database_server: nil,
                  database_name: nil,
                  url: nil,
                  enabled: nil,
                  active: false,
                  problems: "The integration has not been set up yet."
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
              renters_insurance: {
                username: @integration.credentials['voyager']['username'],
                password: @integration.credentials['voyager']['password'],
                database_server: @integration.credentials['voyager']['database_server'],
                database_name: @integration.credentials['voyager']['database_name'],
                url: @integration.credentials['urls']['renters_insurance'],
                enabled: @integration.configuration['renters_insurance']['enabled'],
                active: @integration.configuration['renters_insurance']['active'],
                problems: @integration.configuration['renters_insurance']['configuration_problems']
              },
              billing_and_payments: {
                username: @integration.credentials['billing']['username'],
                password: @integration.credentials['billing']['password'],
                database_server: @integration.credentials['billing']['database_server'],
                database_name: @integration.credentials['billing']['database_name'],
                url: @integration.credentials['urls']['billing_and_payments'],
                enabled: @integration.configuration['billing_and_payments']['enabled'],
                active: @integration.configuration['billing_and_payments']['active'],
                problems: @integration.configuration['billing_and_payments']['configuration_problems']
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
            created = ::Integration.create(
              integratable: current_staff.organizable,
              provider: @provider,
              credentials: create_params
            )
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
            # update @interface's fields
            { renters_insurance: :voyager, billing_and_payments: :billing }.each do |interface, cred_section|
              [:username, :password, :database_server, :database_name].each do |field|
                @integration.credentials[cred_section.to_s][field.to_s] = update_params[interface][field] if update_params[interface]&.has_key?(field)
              end
              @integration.credentials['urls'][interface.to_s] = update_params[interface]['url'] if update_params[interface]&.has_key?('url')
              @integration.configuration[interface.to_s]['enabled'] = update_params[interface]['enabled'] if update_params[interface]&.has_key?('enabled')
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
      
      

      private # call as v2/integrations/yardi
      
        def set_provider
          @provider = params[:provider].to_s
        end
        
        def set_integration
          @integration = ::Integration.where(integratable: current_staff.organizable, provider: params[:provider].to_s).take # WARNING: does not throw error via .find() like some controllers
        end

        def create_params
          params.permit(
            renters_insurance: [:username, :password, :database_server, :database_name, :url, :enabled],
            billing_and_payments: [:username, :password, :database_server, :database_name, :url, :enabled]
          )
        end

        def update_params
          params.permit(
            renters_insurance: [:username, :password, :database_server, :database_name, :url, :enabled],
            billing_and_payments: [:username, :password, :database_server, :database_name, :url, :enabled]
          )
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

    end
  end
end


