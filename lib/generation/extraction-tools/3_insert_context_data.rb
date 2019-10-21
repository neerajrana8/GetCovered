
# read scheme
$scheme = JSON.parse(File.read(File.join(__dir__, "app-data/scheme.json")))

# insert context data
$scheme['contexts'] = {
  'user' => {
    'user_type' => 'User',
    'access_model' => 'model_class == ::User && model_id == current_user.id ? current_user : current_user.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id]))'
  },
  'staff' => {
    'user_type' => 'Staff',
    'subcontext_determinant' => "current_staff.role"
    'subcontexts' => {
      'account' => {
        'determinant_value' => '"staff"',
        'access_model' => <<~'ENDSTR'
          return current_staff.organizable if model_class == ::Account && model_id == current_staff.organizable_id
          return current_staff.organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
          ENDSTR
      },
      'agency' => {
        'determinant_value' => '"agent"',
        'access_model' => <<~'ENDSTR'
          return current_staff.organizable if model_class == ::Agency && model_id == current_staff.organizable_id
          return current_staff.organizable.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
          ENDSTR
      },
      'super_admin' => {
        'determinant_value' => '"super_admin"',
        'access_model' => 'model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))'
      }
    }
  },
  'public' => {
    'user_type' => nil,
    'access_model' => 'model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))'
  }
}

# save scheme
File.open(File.join(__dir__, "app-data/scheme.json"), "w") do |f|
  f.write(JSON.pretty_generate($scheme))
end
