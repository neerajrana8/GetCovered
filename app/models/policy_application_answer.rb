##
# =Policy Application Answer Model
# file: +app/models/policy_application_answer.rb+

class PolicyApplicationAnswer < ApplicationRecord
	
	before_create :set_data
	
  belongs_to :policy_application_field
  belongs_to :policy_application	
  
  enum section: { fields: 0, questions: 1 }

	private
	
		def set_data
			if policy_application_field.answer_type == "boolean"
				self.data["options"] = [true, false]	
			elsif	policy_application_field.answer_type == "number"
				self.data["options"] = policy_application_field.answer_options
																											 .nil? ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] :
																											 				 policy_application_field.answer_options
			elsif policy_application_field.answer_type == "OPTION_SELECT"
				self.data["options"] = policy_application_field.answer_options
			end
			self.data["answer"] = policy_application_field.default_answer
			self.data["desired"] = policy_application_field.desired_answer
		end
end
