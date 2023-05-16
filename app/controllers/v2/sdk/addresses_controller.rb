##
# V2 SDK Addresses Controller
# File: app/controllers/v2/sdk/addresses_controller.rb

module V2
  module Sdk
    class AddressesController < SdkController
      include AddressesMethods

      def search
        ids = Array.new
        @addresses = Address.where("addresses.full_searchable LIKE '%#{ search_params[:query] }%' AND addressable_type = 'Insurable'")
        @addresses.each { |a| ids << a.addressable_id if a.addressable.insurable_type_id == 1 && a.addressable.account_id == @bearer.id }
        @communities = Insurable.find(ids)

        @response = Array.new

        @communities.each do |community|
          building_check = community.insurables.exists?(insurable_type_id: 7)

          response_object = {
            :id => community.id,
            :title => community.title,
            :address => community.addresses[0].full_searchable,
            :external_id => community.integration_profiles.blank? ? nil : community.integration_profiles[0].external_id
          }

          if building_check
            response_object[:buildings] = Array.new
            community.insurables.where(insurable_type_id: 7).each do |building|
              building_object = {
                :id => building.id,
                :title => building.title,
                :address => building.addresses[0].full_searchable,
                :external_id => building.integration_profiles.blank? ? nil : building.integration_profiles[0].external_id,
                :units => []
              }

              building.insurables.each do |unit|
                building_object[:units] << {
                  :id => unit.id,
                  :title => unit.title,
                  :external_id => unit.integration_profiles.blank? ? nil : unit.integration_profiles[0].external_id
                }
              end

              response_object[:buildings] << building_object
            end
          else
            response_object[:units] = Array.new
            community.insurables.each do |unit|
              response_object[:units] << {
                :id => unit.id,
                :title => unit.title,
                :external_id => unit.integration_profiles.blank? ? nil : unit.integration_profiles[0].external_id
              }
            end
          end
          @response << response_object
        end
        render json: @response.to_json, status: :ok
      end

      private
      def search_params
        params.require(:address).permit(:query)
      end
    end
  end
end