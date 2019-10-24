
# read scheme
$scheme = JSON.parse(File.read(File.join(__dir__, "app-data/scheme.json")))

# insert context data
$scheme['contexts'] = {
  'user' => {
    'user_type' => 'User',
    'access_model' => 'model_class == ::User && model_id == current_user.id ? current_user : current_user.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id]))'
  },
  'staff_account' => {
    'user_type' => 'Staff',
    'route' => 'staff',
    'authenticated_route_constraint' => "current_staff.role == 'staff'",
    'access_model' => <<~'ENDSTR', # method(model_type, model_id = nil)
      return current_staff.organizable if model_class == ::Account && model_id == current_staff.organizable_id
      return current_staff.organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
      ENDSTR
    
  },
  'staff_agency' => {
    'user_type' => 'Staff',
    'route' => 'staff',
    'authenticated_route_constraint' => "current_staff.role == 'agent'",
    'access_model' => <<~'ENDSTR',
      return current_staff.organizable if model_class == ::Agency && model_id == current_staff.organizable_id
      return current_staff.organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
      ENDSTR
  },
  'staff_super_admin' => {
    'user_type' => 'Staff',
    'route' => 'staff',
    'authenticated_route_constraint' => "current_staff.role == 'super_admin'",
    'access_model' => 'model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))'
  },
  'public' => {
    'user_type' => nil,
    'route' => nil,
    'access_model' => 'model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))'
  }
}

# insert specials data
$scheme['specials'] = {
  'devise' => {
    'auth_controller_directory_root' => '',
    'user_auths' => {
      'User' => {
        'route' => 'v2/user/auth',
        'controller_path' => 'devise/users' # MOOSE WARNING: this is at odds with the current directory structure
      },
      'Staff' => {
        'route' => 'v2/staff/auth',
        'controller_path' => 'devise/staffs' # 'uninvitable' => true can be added to disable invite routes
      }
    }
  },
  'history' => {
    'model' => 'History',
    'concern' => 'RecordChange',
    'contexts' => [
      'staff_account',
      'staff_agency',
      'staff_super_admin'
    ]
  }
}

# save scheme
File.open(File.join(__dir__, "app-data/scheme.json"), "w") do |f|
  f.write(JSON.pretty_generate($scheme))
end
