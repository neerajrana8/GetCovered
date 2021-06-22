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
          user.invite! if user.save
        end

        ::LeaseUser.create(lease: @lease, user: user, primary: user_params[:primary])
      end

      render :show, status: :created
    else
      render json: @lease.errors, status: :unprocessable_entity
    end
  end

  def update
    if @lease.update_as(current_staff, update_params)
      users_ids = users_params[:users]&.map { |user_params| user_params[:user][:id] }&.compact
      @lease.lease_users.where.not(id: users_ids).destroy_all

      users_params[:users]&.each do |user_params|
        lease_user = @lease.lease_users.find_by(user_id: user_params[:user][:id])

        if lease_user.present?
          lease_user.update(primary: user_params[:primary])
        else
          user = ::User.find_by(id: user_params[:user][:id]) || ::User.find_by(email: user_params[:user][:email])

          if user.nil?
            user = ::User.new(user_params[:user])
            user.password = SecureRandom.base64(12)
            user.invite! if user.save
          end

          LeaseUser.create(lease: @lease, user: user, primary: user_params[:primary])
        end
      end

      render :show, status: :ok
    else
      render json: @lease.errors, status: :unprocessable_entity
    end
  end

  private

  def users_params
    params.permit(users: [:primary, user: [
                                            :id, :email, :agency_id,
                                            profile_attributes: %i[birth_date contact_phone first_name gender job_title last_name salutation],
                                            address_attributes: %i[city country county state street_name street_two zip_code]
                                          ]])
  end
end
