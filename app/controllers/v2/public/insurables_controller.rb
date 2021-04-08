##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class InsurablesController < PublicController
      include InsurablesMethods

      before_action :set_insurable,
        only: [:show]

      before_action :set_substrate,
        only: [:index]

      private

        def view_path
          super + "/insurables"
        end

        def set_insurable
          @insurable = access_model(::Insurable, params[:id])
        end

        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Insurable)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.insurables
          end
        end

        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
          }
        end

        def supported_orders
          supported_filters(true)
        end

        def msi_community_info_id
          params.require(:policy_application)
            .permit(policy_rates_attributes:      [:insurable_rate_id],
                    policy_insurables_attributes: [:insurable_id])
        end

        def get_or_create_params
          params.permit(:address, :unit, :insurable_id, :create_if_ambiguous, :allow_creation, :communities_only, :titleless)
        end

        # output stuff with essentially the same format as in the Address search
        def insurable_prejson(ins, short_mode: false)
          case ins
            when ::Insurable
              if ::InsurableType::RESIDENTIAL_UNITS_IDS.include?(ins.insurable_type_id)
                com = ins.parent_community unless short_mode
                return {
                  id: ins.id, title: ins.title,
                  account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
                }.merge(short_mode ? {} : {
                  enabled: ins.enabled, preferred_ho4: com&.preferred_ho4 || false,
                  category: ins.category, primary_address: insurable_prejson(ins.primary_address),
                  community: insurable_prejson(com, short_mode: true)
                }.compact)
              elsif ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(ins.insurable_type_id)
                return {
                  id: ins.id, title: ins.title, enabled: ins.enabled, preferred_ho4: ins.preferred_ho4,
                  account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id
                }.merge(short_mode ? {} : {
                  category: ins.category, primary_address: insurable_prejson(ins.primary_address),
                  units: ins.preferred_ho4 ? ins.units.select{|u| u.enabled }.map{|u| { id: u.id, title: u.title } } : nil
                }.compact)
              elsif ::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(ins.insurable_type_id)
                com = ins.parent_community
                return {
                  id: ins.id, title: ins.title,
                  account_id: ins.account_id, agency_id: ins.agency_id, insurable_type_id: ins.insurable_type_id,
                }.merge(short_mode ? {} : {
                  enabled: ins.enabled, preferred_ho4: com&.preferred_ho4 || false,
                  category: ins.category, primary_address: insurable_prejson(ins.primary_address),
                  units: com&.preferred_ho4 ? ins.units.select{|u| u.enabled }.map{|u| { id: u.id, title: u.title } } : nil, # WARNING: we don't bother recursing with short mode here
                  community: insurable_prejson(com, short_mode: true)
                }.compact)
              else
                return nil
              end
            when ::Address
              return {
                full: ins.full,
                street_number: ins.street_number, street_name: ins.street_name,
                street_two: ins.street_two,
                city: ins.city, state: ins.state, zip_code: ins.zip_code,
                county: ins.county, country: ins.country
              }
            else
              return nil
          end
        end

    end
  end # module Public
end
