require 'rake'
require 'ruby-progressbar'

namespace :permissions do
  desc 'Populate existing permissions'
  task :add_missed, [:default_value] => [:environment] do |_, args|
    default_value = args[:default_value] == 'true' # if passed "true" - `true`, otherwise `false`
    puts 'Update Global Agency Permissions'.blue.to_s
    progress_bar = ProgressBar.create(format: "%a %b\u{15E7}%i %p%% %t",
                                      progress_mark: ' ',
                                      remainder_mark: "\u{FF65}",
                                      starting_at: 0,
                                      total: GlobalAgencyPermission.count)
    GlobalAgencyPermission.all.each do |global_agency_permission|
      new_permissions = {}
      current_permissions = global_agency_permission.permissions

      GlobalAgencyPermission::AVAILABLE_PERMISSIONS.each do |key:, **|
        new_permissions[key] = current_permissions[key] || default_value
      end

      global_agency_permission.update(permissions: new_permissions) if new_permissions != current_permissions

      progress_bar.increment
    end
    
    puts 'Update Staff Permissions'.blue.to_s

    progress_bar = ProgressBar.create(format: "%a %b\u{15E7}%i %p%% %t",
                                      progress_mark: ' ',
                                      remainder_mark: "\u{FF65}",
                                      starting_at: 0,
                                      total: GlobalAgencyPermission.count)
    StaffPermission.all.each do |staff_permission|
      new_permissions = {}
      current_permissions = staff_permission.permissions

      GlobalAgencyPermission::AVAILABLE_PERMISSIONS.each do |key:, **|
        new_permissions[key] = current_permissions[key] || default_value
      end

      staff_permission.update(permissions: new_permissions) if new_permissions != current_permissions

      progress_bar.increment
    end
  end
end
