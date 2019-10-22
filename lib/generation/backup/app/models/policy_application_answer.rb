# frozen_string_literal: true

# =Policy Application Answer Model
# file: +app/models/policy_application_answer.rb+

class PolicyApplicationAnswer < ApplicationRecord
  before_create :set_data
  
  belongs_to :policy_application_field
  belongs_to :policy_application
  
  enum section: { fields: 0, questions: 1 }
  
  validate :answers_must_be_from_options, :answer_must_match_desired
  
  def answers_must_be_from_options
    return if data['options'].blank?
    
    errors.add(:data, 'answer must be from options') unless data['options'].include?(data['answer'])
  end
  
  def answer_must_match_desired
    return if data['desired'].blank?
    
    errors.add(:data, 'answer must match desired') if data['desired'] != data['answer']
  end
  
  private
  
  def set_data
    if policy_application_field.answer_type == 'boolean'
      data['options'] = [true, false]
    elsif policy_application_field.answer_type == 'number'
      data['options'] = policy_application_field.answer_options
      .nil? ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] :
      policy_application_field.answer_options
    elsif policy_application_field.answer_type == 'OPTION_SELECT'
      data['options'] = policy_application_field.answer_options
    end
    data['answer'] = policy_application_field.default_answer
    data['desired'] = policy_application_field.desired_answer
  end
end
