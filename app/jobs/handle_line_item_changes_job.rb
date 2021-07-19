class HandleLineItemChangesJob < ApplicationJob
  queue_as :default
  before_perform :set_lics

  def perform(*args)
    @lics.each do |lic|
      lic.handle
    end
  end

  private

    def set_lics
      @lics = ::LineItemChange.references(:line_items).includes(:line_item).where(handled: false)
    end
end
