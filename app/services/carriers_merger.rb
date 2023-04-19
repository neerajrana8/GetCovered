class CarriersMerger < ApplicationService
  attr_accessor :main_carrier
  attr_accessor :carriers_to_merge

  def initialize(main_carrier, carriers_to_merge)
    @main_carrier = main_carrier
    @carriers_to_merge = carriers_to_merge
  end

  def call
    raise 'Carriers to merge should all be out_of_system' unless carriers_to_merge.all? { |carrier| carrier.out_of_system? }

    ActiveRecord::Base.transaction do
      # NOTE: migrate policies
      Policy
        .where(carrier_id: @carriers_to_merge.pluck(:id))
        .update_all(carrier_id: @main_carrier.id, out_of_system_carrier_title: @main_carrier.title)

      # NOTE: get rid of merged carriers
      @carriers_to_merge.each(&:destroy)

      @main_carrier.reload
    end
  end
end
