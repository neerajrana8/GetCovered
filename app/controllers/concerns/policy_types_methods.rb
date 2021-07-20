module PolicyTypesMethods
  extend ActiveSupport::Concern

  def index
    super(:@policy_types, PolicyType.all)
    render 'v2/shared/policy_types/index'
  end

  private

  def supported_filters(called_from_orders = false)
    @calling_supported_orders = called_from_orders
    {
      master: %i[scalar],
      master_coverage: %i[scalar],
      master_policy_id: %i[scalar array]
    }
  end
end
