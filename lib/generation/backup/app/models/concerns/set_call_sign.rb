#
# SetCallSign Concern
# file: app/models/concerns/slug_title.rb

module SetCallSign
  extend ActiveSupport::Concern

  included do
    before_validation :set_call_sign, on: :create,
      unless: Proc.new { |obj| obj.title.nil? }
  end

  def set_call_sign
    parent_class = self.class.name.constantize
    common_words = ["", "a", "ago", "also", "am", "an", "and", "ani", "ar", "aren't", "arent",
                    "as", "ask", "at", "did", "didn't", "didnt", "do", "doe", "would",
                    "be", "been", "best", "better", "the"]

    stripped_title = self.title.split(/\W/)
                         .delete_if{ |wrd| common_words.include?(wrd.downcase) }
                         .join(' ')
    tmp_identifier = stripped_title.split(/\W/).map(&:first).join[0..3]

    loop_index = 0
    
    loop do
      self.call_sign = loop_index == 0 ? tmp_identifier : "#{tmp_identifier}#{loop_index}"
      loop_index += 1

      break unless parent_class.where(call_sign: call_sign).exists?
    end
  end
  
end