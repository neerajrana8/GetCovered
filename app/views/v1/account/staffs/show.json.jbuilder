json.partial! "v1/account/staffs/staff", 
  staff: @resource

# No stats so far
# json.stats @resource.stats

# No communities so far
# json.communities do
#   json.array! @staff.assignments.select{ |a| a.assignable_type == 'Community' } do |assignment|
#     json.partial! "v1/account/communities/community_short",
#       community: assignment.assignable
#     json.assignment_id assignment.id
#   end
# end
