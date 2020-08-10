class UpgradePolicyCancellationColumns < ActiveRecord::Migration[5.2]
  def up
    rename_column :policies, :cancellation_date_date, :cancellation_date
    add_column :policies, :cancellation_reason, :integer
    # convert cancellation codes to cancellation reasons
    Policy.where.not(cancellation_code: nil).each do |pol|
      case pol.carrier_id
        when 1,2
          reason = QbeService::CANCELLATION_REASON_MAPPING.find{|m| m[:code] == pol.cancellation_code }&.[](:reason)
          raise "Policy #{pol.id} has cancellation code '#{pol.cancellation_code}', which does not exist in QbeService::CANCELLATION_REASON_MAPPING and so cannot be converted to a cancellation_reason!" if reason.nil?
          pol.update_columns(cancellation_reason: reason)
        else
          raise "Policy #{pol.id} has carrier '#{pol.carrier.title}' with a non-nil cancellation_code, and the UpgradePolicyCancellationColumns migration has no code to translate this carrier's cancellation codes into cancellation reasons!"
      end
    end
    # done converting
    remove_column :policies, :cancellation_code
  end
  
  def down
    add_column :policies, :cancellation_code, :integer
    # convert cancellation reasons to cancellation codes
    Policy.where.not(cancellation_reason: nil).each do |pol|
      case pol.carrier_id
        when 1,2
          code = QbeService::CANCELLATION_REASON_MAPPING.find{|m| m[:reason] == pol.cancellation_reason }&.[](:code)
          raise "Policy #{pol.id} has cancellation reason '#{pol.cancellation_reason}', which does not exist in QbeService::CANCELLATION_REASON_MAPPING and so cannot be converted to a cancellation_code!" if code.nil?
          pol.update_columns(cancellation_code: code)
        else
          raise "Policy #{pol.id} has carrier '#{pol.carrier.title}' with a non-nil cancellation_reason, and the UpgradePolicyCancellationColumns migration has no code to translate this carrier's cancellation reasons into cancellation codes!"
      end
    end
    # done converting
    remove_column :policies, :cancellation_reason
    rename_column :policies, :cancellation_date, :cancellation_date_date
  end
end
