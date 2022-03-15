##
# V2 Public Addresses Controller
# File: app/controllers/v2/public/addresses_controller.rb

module V2
  module StaffSuperAdmin
    class AddressesController < StaffSuperAdminController
      def index
        if params[:search].presence
          insurable_ids = Address.where(addressable_type: "Insurable").where("addresses.full ILIKE '%#{ params[:search] }%'").pluck(:addressable_id)
          insurable_type_ids = InsurableType::RESIDENTIAL_COMMUNITIES_IDS + InsurableType::BUILDINGS_IDS
          @insurables = Insurable.where(id: insurable_ids, insurable_type_id: insurable_type_ids, enabled: true)
                                 .send(*(params[:policy_type_id].blank? ? [:itself] : [:where, "policy_type_ids @> ARRAY[?]::bigint[]", params[:policy_type_id].to_i]))
                                 .send(*(params[:policy_type_id].to_i == PolicyType::RESIDENTIAL_ID ? [:where, { preferred_ho4: true }] : [:itself]))
                                 .send(*(params[:account_id].present? ? [:where, { account_id: params[:account_id] }] : [:itself]))
                                 .send(*(params[:agency_id].present? ?  [:where, { agency_id: params[:agency_id] }] : [:itself]))

          @response = V2::StaffSuperAdmin::Insurables.new(
            @insurables
          ).response

          render json: @response.to_json,
                 status: :ok
        else
          render json: [].to_json,
                 status: :ok
        end
      end
    end
  end
end
