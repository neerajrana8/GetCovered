json.partial! "v2/staff_super_admin/assignments/assignment_show_fields.json.jbuilder",
  assignment: assignment


json.assignable do
  if assignment.assignable.is_a?(Insurable)
    json.insurable json.partial! "v2/staff_super_admin/insurables/insurable_show_fields.json.jbuilder",
  insurable: assignment.assignable
  end
end
