# app/services/calc_commissions_service.rb
class CalcCommissionsService
  
  def self.call(*args, &block)
    new(*args, &block).execute
  end

  def initialize(params)
    @policy = params[:policy]
  end

  def execute

  end
end
