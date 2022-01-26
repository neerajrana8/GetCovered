class FetchQbeRatesJob < ApplicationJob
  queue_as :default
  
  # target should be an Insurable or an InsurableGeographicalCategory for qbe (i.e. it's .insurable value is non-nil)
  def perform(target, number_insured: [1,2,3,4,5], traits_override: {}, delay: nil, igc: :unset)
    # make target point at an insurable, make igc point at an igc or nil, flee if invalid target was provided
    if igc == :unset # when recursing we get to skip these time-wasting checks becuase we will always explicitly specify igc as nil or as an IGC
      igc = nil
      if target.class == ::InsurableGeographicalCategory
        igc = target
        target = igc.insurable
        return if target.nil?
      elsif target.class != ::Insurable
        return
      end
      return if !::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(target.insurable_type_id)
    end
    # get the rates
    target.get_qbe_rates(number_insured.first, traits_override: traits_override, irc_configurable_override: igc)
    unless number_insured.length == 1
      case delay
        when :synchronous; FetchQbeRatesJob.perform_now(igc || target, number_insured: number_insured.drop(1), traits_override: traits_override, delay: delay, igc: igc)
        when nil, 0;       FetchQbeRatesJob.perform_later(igc || target, number_insured: number_insured.drop(1), traits_override: traits_override, delay: delay, igc: igc)
        else;              FetchQbeRatesJob.set(wait: delay.minutes).perform_later(igc || target, number_insured: number_insured.drop(1), traits_override: traits_override, delay: delay, igc: igc)
      end
    end
  end


end
