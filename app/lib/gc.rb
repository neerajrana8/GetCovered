#
# Refactoring purpose library
# Collects all logic and scenarios in a single scope to be available include in to existing code
# Refactored scenarios should be moved from here to their places inside services, models, and controllers
#
module Gc

  # Common

  def skip
    true
  end

  # Insurables

  def policy_insurable(policy)
    policy.primary_insurable
  end

  def insurable_leases(insurable)
    insurable.leases
  end

  def all_insurables
    Insurable.all
  end

  def all_units
    Insurable.where(insurable_type_id: InsurableType::UNITS_IDS)
  end

  def all_covered_units
    all_units.where(covered: true)
  end

  def all_uncovered_units
    all_units.where(covered: false)
  end

  def all_units_without_any_lease
    units_ids = all_units.pluck(:id)
    insurable_ids = all_leases.pluck(:insurable_id)
    diff = units_ids - insurable_ids
    Insurable.where(id: diff)
  end

  def all_units_with_expired_lease
    ids = all_expired_leases.pluck(:insurable_id)
    Insurable.where(id: ids)
  end

  def all_units_with_valid_lease
    ids = all_valid_leases.pluck(:insurable_id)
    Insurable.where(id: ids)
  end

  def unit_policies(unit)
    Policy.where(id: PolicyInsurable.where(insurable_id: unit.id).pluck(:policy_id)).order(expiration_date: :desc)
  end

  def unit_policy(unit)
    Policy.where(id: PolicyInsurable.where(insurable_id: unit.id).pluck(:policy_id))
  end

  def uncover_unit(unit)
    unit.update(covered: false)
  end

  def cover_unit(unit)
    unit.update(covered: true)
  end

  def unit_shouldbe_covered?(lease, policy, check_date)
    return false if lease.nil?
    !lease_expired?(lease, check_date) && !policy_expired?(policy, check_date)
  end


  def units_without_leases
    units = all_units
    leases = all_leases.where(insurable_id: units.pluck(:id))
    units_with_leases = Insurable.where(id: leases.pluck(:insurable_id))
    ids = units.pluck(:id) - units_with_leases.pluck(:id)
    Insurable.where(id: ids)
  end

  # Leases

  def all_leases
    Lease.all
  end

  def active_lease(insurable)
    insurable.leases.where(status: :current)&.take
  end

  def make_lease_expired(lease)
    lease.update!(status: 'expired')
  end

  def make_lease_current(lease)
    lease.update!(status: 'current')
  end

  def pending_leases
    Lease.where(status: 'pending')
  end

  def current_leases
    Lease.where(status: 'current')
  end

  def expired_leases
    Lease.where(status: 'expired')
  end

  def lease_shouldbe_covered?(policy, lease, check_date)
    !policy_expired?(policy, check_date) && !lease_expired?(lease, check_date)
  end

  def tenant_matched?(lease, policy)
    lease_name = lease.primary_user&.profile&.last_name
    lease_email = lease.primary_user&.email
    policy_name = policy.primary_user&.profile&.last_name
    policy_email = policy.primary_user&.email

    lease_name == policy_name && policy_email == lease_email
  end

  def uncover_lease(lease)
    lease.update covered: false
  end

  def cover_lease(lease)
    lease.update covered: true
  end

  def lease_expired?(lease, check_date)
    return true if lease.end_date.nil?
    lease.end_date < check_date
  end

  def all_expired_leases
    Lease.where('end_date < ?', DateTime.now)
  end

  def all_valid_leases
    Lease.where('end_date > ?', DateTime.now)
  end

  def all_current_leases
    Lease.where('end_date > ?', DateTime.now)
  end

  def all_covered_leases_with_valid_date
    all_current_leases.where(covered: true)
  end

  def all_uncovered_leases_with_valid_date
    all_current_leases.where(covered: false)
  end


  # Policies


  def all_expired_policies
    Policy.where('expiration_date < ?', DateTime.now)
  end

  def active_policy_statuses
    %w[BOUND BOUND_WITH_WARNING RENEWING RENEWED REINSTATED EXTERNAL_VERIFIED]
  end

  def policy_expired_status?(policy)
    policy.status == 'EXPIRED'
  end

  def make_policy_expired_status(policy)
    policy.update status: 'EXPIRED'
  end

  def active_policies
    Policy.where(status: active_policy_statuses)
  end

  def policy_expired?(policy, check_date)
    return true if policy.expiration_date.nil?

    policy.expiration_date < check_date
  end

  def policy_shouldbe_expired?(policy, check_date)
    policy_expired?(policy, check_date)
  end

  def all_valid_by_date_policies
    Policy.where('expiration_date > ?' , DateTime.now)
  end

  def policies_by_type
    Policy.includes(:policy_type).references(:policy_type).group('policy_types.title').count
  end

  def all_policices
    Policy.all
  end

  def policies_valid_by_status_and_date
    all_valid_by_date_policies.where(status: active_policy_statuses)
  end


  # Analytics
  def total_stats

    units_covered = Insurable.where(insurable_type_id: InsurableType::UNITS_IDS).group(:covered).count

    {
      insurables_leases_policies: {
        insurables_total: all_insurables.count,
        units_total: all_units.count,
        units_covered: all_covered_units.count,
        units_uncovered: all_uncovered_units.count,
        units_with_valid_lease: all_units_with_valid_lease.count,
        units_with_expired_lease: all_units_with_expired_lease.count,
        units_without_any_lease: all_units_without_any_lease.count,
        leases_total: all_leases.count,
        all_covered_leases_with_valid_date: all_covered_leases_with_valid_date.count,
        all_uncovered_leases_with_valid_date: all_uncovered_leases_with_valid_date.count,
        policies_total: all_policices.count,
        policies_valid_by_date: all_valid_by_date_policies.count,
        policies_valid_by_status: active_policies.count,
        policies_valid_by_status_and_date: policies_valid_by_status_and_date.count
      }

      # total_insurables_by_covered: Insurable.group(:covered).count,
      # units_insurables_by_covered: units_covered,
      # units_without_leases: units_without_leases.count,

      # lease_by_covered: Lease.group(:covered).count,
      # lease_by_status: Lease.group(:status).count,
      # leases_expired_by_date: all_expired_leases.count,
      # leases_current_by_date: all_current_leases.count,

      # policies_by_type: policies_by_type,
      # policies_in_status: Policy.group(:status).count,
      # policies_expired_by_date: all_expired_policies.count,
      # policies_valid_by_date: all_valid_by_date_policies.count,
    }
  end

  # Utils


  def title(str)
    puts "> #{str}"
  end


  def stats_as_table
    stats = total_stats

    stats.keys.each do |k|
      d = stats[k]
      if d.is_a?(Hash)
        x = d.to_a
        x.unshift([k, ''])
        table(x)
      end

      if d.is_a?(Integer)
        x = [[k, d]]
        table(x, header: false)
      end
    end
  end

  def table(arr, header: true)

    column_sizes = arr.reduce([]) do |lengths, row|
      row.each_with_index.map{|iterand, index| [lengths[index] || 0, iterand.to_s.length].max}
    end
    head = '+' + column_sizes.map{|column_size| '-' * (column_size + 2) }.join('+') + '+'
    puts head

    to_print = arr.clone
    if (header == true)
      header = to_print.shift
      print_table_data_row(column_sizes, header)
      puts head
    end
    to_print.each{ |row| print_table_data_row(column_sizes, row) }
    puts head
  end


  def print_table_data_row(column_sizes, row)
    row = row.fill(nil, row.size..(column_sizes.size - 1))
    row = row.each_with_index.map{|v, i| v = v.to_s + ' ' * (column_sizes[i] - v.to_s.length)}
    puts '| ' + row.join(' | ') + ' |'
  end

  def with_captured_stdout
    original_stdout = $stdout  # capture previous value of $stdout
    $stdout = StringIO.new     # assign a string buffer to $stdout
    yield                      # perform the body of the user code
    $stdout.string             # return the contents of the string buffer
  ensure
    $stdout = original_stdout  # restore $stdout to its previous value
  end



end
