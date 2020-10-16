module Carriers
  module FeesMethods
    extend ActiveSupport::Concern

    def add_fees
      agency = Agency.find_by(id: params[:ownerable_id])
      billing_strategy = BillingStrategy.find_by(id: params[:assignable_id])
      if Fee.where(ownerable_id: agency.id, assignable_id: billing_strategy.id).exists?
        render json: { message: 'Already exists' }, status: :unprocessable_entity
      elsif !Fee.where(ownerable_id: agency.id, assignable_id: billing_strategy.id).exists?
        fee = Fee.new(fee_params.merge(ownerable: agency, assignable: billing_strategy))
        fee.save
        render json: { message: 'Fee was succesfully created' }, status: :ok
      else
        render json: { message: 'Fee was not created' }, status: :unprocessable_entity
      end
    end

    def fees_list
      if params[:carrier_agency_id].present?
        fees = paginator(Fee.where(ownerable_type: 'Agency', ownerable_id: params[:carrier_agency_id]).order(created_at: :desc))
        render json: fees, status: :ok
      else
        fees = paginator(Fee.where(ownerable_type: 'Agency').order(created_at: :desc))
        render json: fees, status: :ok
      end
    end
  end
end
