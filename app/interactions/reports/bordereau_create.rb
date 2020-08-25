module Reports
  class BordereauCreate < ActiveInteraction::Base
    time :range_start, default: 1.month.ago
    time :range_end,   default: Time.zone.now

    def execute
      total
      accounts_agencies
    end

    private

    def total
      Reports::Bordereau.new(range_start: range_start, range_end: range_end).generate.save
    end

    def accounts_agencies
      Agency.where(enabled: true).each do |agency|
        Reports::Bordereau.new(range_start: range_start, range_end: range_end, reportable: agency).generate.save
        agency.accounts.each do |account|
          Reports::Bordereau.new(range_start: range_start, range_end: range_end, reportable: account).generate.save
        end
      end
    end
  end
end
