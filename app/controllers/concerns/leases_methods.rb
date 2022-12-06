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

        ::LeaseUser.create(lease: @lease, user: user, primary: user_params[:primary])
      end

      # NOTE: Auto assign master policy if applicable
      Rails.logger.info "#DEBUG call(assign_master_policy) #{@lease}"
      assign_master_policy

      # NOTE: Policy assignment through MasterCoverageSweepJob REF: #GCVR2-768
      Compliance::Policies::MasterCoverageSweepJob.perform_later(@lease.start_date)

      render template: 'v2/shared/leases/show', status: :created
    else
      render json: @lease.errors, status: :unprocessable_entity
    end
  end

  def update
    if @lease.update_as(current_staff, update_params)
      users_ids = users_params[:users]&.map { |user_params| user_params[:user][:id] }&.compact
      @lease.lease_users.where.not(user_id: users_ids).destroy_all

      users_params[:users]&.each do |user_params|
        lease_user = @lease.lease_users.find_by(user_id: user_params[:user][:id])

        if lease_user.present?
          lease_user.update(primary: user_params[:primary])
          user = lease_user.user
          user.update(user_params[:user])
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
            user.update(user_params[:user])

            if user.errors.any?
              render json: standard_error(:user_update_error, nil, user.errors.full_messages),
                     status: :unprocessable_entity
              return
            end
          end

          LeaseUser.create(lease: @lease, user: user, primary: user_params[:primary])
        end
      end

      render template: 'v2/shared/leases/show', status: :ok
    else
      render json: @lease.errors, status: :unprocessable_entity
    end
  end

  private

  #
  # NOTE: Moved from Insurable model after_create.hook
  # Changed to get parent_insurable inside Lease
  #
  def assign_master_policy
    parent_insurable = @lease.insurable&.insurable
    return if InsurableType::COMMUNITIES_IDS.include?(@lease.insurable.insurable_type_id) || parent_insurable.blank?

    master_policy = parent_insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
    Rails.logger.info "#DEBUG master_policy=#{master_policy}"
    if master_policy.present? && parent_insurable.policy_insurables.where(policy: master_policy).take.auto_assign
      Rails.logger.info "#DEBUG lease.insurable.insurable_type_id=#{@lease.insurable.insurable_type_id}"
      Rails.logger.info "#DEBUG master_policy.insurables.find_by=#{master_policy.insurables.find_by(insurable_id: @lease.insurable.id)}"
      # if InsurableType::BUILDINGS_IDS.include?(@lease.insurable.insurable_type_id) &&
      if master_policy.insurables.find_by(insurable_id: @lease.insurable.id).blank?
        Rails.logger.info "#DEBUG PolicyInsurable.create policy=#{master_policy.id} insurable=#{@lease.insurable.id}"
        PolicyInsurable.create(policy: master_policy, insurable: @lease.insurable, auto_assign: true)
      end
      Insurables::MasterPolicyAutoAssignJob.perform_later # try to cover if its possible
    end
  end

  def users_params
    params.permit(users: [:primary, user: [
                                            :id, :email, :agency_id,
                                            profile_attributes: %i[birth_date contact_phone first_name gender job_title last_name salutation],
                                            address_attributes: %i[city country county state street_number street_name street_two zip_code]
                                          ]])
  end
end
