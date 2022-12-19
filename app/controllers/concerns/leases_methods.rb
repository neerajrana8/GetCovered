module LeasesMethods
  extend ActiveSupport::Concern

  def create
    @lease = ::Lease.new(create_params)
    if @lease.errors.none? && @lease.save_as(current_staff)
      users_params[:users]&.each do |user_params|
        user = ::User.find_by(id: user_params[:user][:id]) || ::User.find_by(email: user_params[:user][:email])
        if user.nil?
          user = ::User.new(user_params[:user])
          user.password = SecureRandom.base64(12)
          user.password_confirmation = user.password
          user.invite! if user.save
        end

        ::LeaseUser.create(lease: @lease, user: user, primary: user_params[:primary],
                           moved_in_at: user_params[:moved_in_at],
                           moved_out_at: user_params[:moved_out_at],
                           integration_profiles_attributes: user_params[:user][:integration_profiles_attributes])
      end

      # NOTE: Auto assign master policy if applicable
      Rails.logger.info "#DEBUG call(assign_master_policy) #{@lease}"
      assign_master_policy

      render template: 'v2/shared/leases/show', status: :created
    else
      render json: @lease.errors, status: :unprocessable_entity
    end
  end

  def update
    if @lease.update_as(current_staff, update_params)
      users_ids = users_params[:users]&.map { |user_params| user_params[:user][:id] }&.compact
      LeaseUser.where(lease_id: @lease.id).where.not(user_id: users_ids).destroy_all

      users_params[:users]&.each do |user_params|
        lease_user = LeaseUser.where(lease_id: @lease.id).find_by(user_id: user_params[:user][:id])

        if lease_user.present?
          binding.pry
          lease_user.update(primary: user_params[:primary], lessee: user_params[:lessee],
                            moved_in_at: user_params[:moved_in_at], moved_out_at: user_params[:moved_out_at])
          lease_user.integration_profiles.find(user_params[:user][:integration_profiles_attributes]&.last[:id])&.update(external_id: user_params[:user][:integration_profiles_attributes]&.last[:external_id])
          user = lease_user.user
          user.update(user_params[:user].except(:integration_profiles_attributes))
          if user.errors.any?
            render json: standard_error(:user_update_error, nil, user.errors.full_messages),
                   status: :unprocessable_entity
            return
          end

        else
          user = ::User.find_by(id: user_params[:user][:id]) || ::User.find_by(email: user_params[:user][:email])

          if user.nil?
            user = ::User.new(user_params[:user])
            user.password = SecureRandom.base64(12)
            user.invite! if user.save
          else
            user.update(user_params[:user].except(:integration_profiles_attributes))

            if user.errors.any?
              render json: standard_error(:user_update_error, nil, user.errors.full_messages),
                     status: :unprocessable_entity
              return
            end
          end

          LeaseUser.create(lease: @lease, user: user, primary: user_params[:primary],
                           moved_in_at: user_params[:moved_in_at],
                           moved_out_at: user_params[:moved_out_at],
                           integration_profiles_attributes: user_params[:user][:integration_profiles_attributes])
        end
      end

      render template: 'v2/shared/leases/show', status: :ok
    else
      render json: @lease.errors, status: :unprocessable_entity
    end
  end

  private

  def assign_master_policy
    unit = @lease.insurable
    parent_insurable = @lease.insurable&.insurable

    # NOTE: Do not create MPC if start_date in future
    return nil if @lease.start_date > Time.current.to_date

    master_policy = parent_insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
    if master_policy

      return nil if master_policy.effective_date > Time.current.to_date

      policy_number = MasterPolicies::GenerateNextCoverageNumber.run!(master_policy_number: master_policy.number)

      new_child_policy_params = {
        agency: master_policy.agency,
        carrier: master_policy.carrier,
        account: master_policy.account,
        status: 'BOUND',
        policy_coverages_attributes: master_policy.policy_coverages.map do |policy_coverage|
          policy_coverage.attributes.slice('limit', 'deductible', 'enabled', 'designation', 'title')
        end,
        number: policy_number,
        # TODO: Must be id of Master policy coverage policy type
        policy_type_id: PolicyType::MASTER_COVERAGE_ID, # policy.policy_type.coverage,
        policy: master_policy,
        effective_date: Time.zone.now,
        expiration_date: master_policy.expiration_date,
        system_data: master_policy.system_data,
        policy_users_attributes: [{ user_id: @lease.primary_user.id }]
      }

      unit.policies.create(new_child_policy_params)
      unit.update(covered: true)
      @lease.update(covered: true)
    end
  end

  def users_params
    params.permit(users: [:primary, :moved_in_at, :moved_out_at, :lessee, user: [
                    :id, :email, :agency_id,
                    profile_attributes: %i[birth_date contact_phone first_name gender job_title last_name middle_name salutation],
                    address_attributes: %i[city country county state street_number street_name street_two zip_code],
                    integration_profiles_attributes: [:id, :integration_id, :external_id]
                  ]])
  end
end
