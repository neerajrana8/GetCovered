# == Schema Information
#
# Table name: policy_premium_item_transaction_memberships
#
#  id                                 :bigint           not null, primary key
#  policy_premium_item_transaction_id :bigint
#  member_type                        :string
#  member_id                          :bigint
#
class PolicyPremiumItemTransactionMembership < ApplicationRecord

  # Hey there! I'm a join table! I'm as basic as they come, yo! Except... I've got a polymorphic association.
  # Oh heck yes, you know it! Polymorphic all the way, bro. I'm gonna polymorph my way unto the very stars.
  #
  # ...one day. But for now, I'm still a young polymorpher. But hey, I can dream, can't I?!?!

  belongs_to :policy_premium_item_transaction
  belongs_to :member,
    polymorphic: true
  
end
