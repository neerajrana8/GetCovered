module StaffsMethods
  extend ActiveSupport::Concern

  def re_invite
    if @staff.enabled?
      render json: { success: false, errors: { staff: 'Already activated' } }, status: :unprocessable_entity
    else
      if @staff.invite_as(current_staff)
        render json: { success: true }, status: :ok
      else
        render json: { success: false,
                       errors: { staff: 'Unable to re-invite Staff', rails_errors: @staff.errors.to_h } },
               status: :unprocessable_entity
      end
    end
  end

  def check_roles(staff, roles)
    roles.each do |role|
      if staff.staff_roles.where(organizable_id: role[:organizable_id], organizable_type: role[:organizable_type], role: role[:role]).count > 0
        staff.errors.add(:staff_role, "Role '#{role[:role]}' already exists for this #{role[:organizable_type]}")
      end
    end
  end

  def add_roles(staff, roles)
    roles.each do |role|
      staff_role = staff.staff_roles.build(role)

      if staff_role.valid?
        staff_role.save
      else
        staff.errors.add(:staff_role, staff_role.errors.first.type)
      end
    end
  end

  def build_first_role(staff)
    staff_role = staff.staff_roles.build(
      role: staff.role,
      organizable: staff.organizable
    )

    staff_role.save
  end
end
