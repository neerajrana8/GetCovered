# Issuer controller to issue child policies
#
module V2
  module Public
    # Issuer methods Controller

    AFFORDABLE_ID = 'affordable'.freeze

    class IssuerController < ApiController
      def enroll_child_policy
        @insurable = Insurable.find(enrollment_params[:insurable_id])
        users = enrollment_users

        if unit_affordable?(@insurable)
          raise_error "This is affordable unit, child policy is not required; Insurable ID=#{@insurable.id}"
        end

        if users.count.zero?
          raise_error "No users found in system matched for Insurable #{@insurable.id}" \
               "and #{enrollment_params[:user_attributes]}"
        end

        lease = Lease.find_by(insurable_id: @insurable.id, status: 'current', defunct: false)

        raise_error "No valid lease found for insurable ID=#{enrollment_params[:insurable_id]}" unless lease

        unless lease_users_matched?(lease, users)
          raise_error "Passed Users not matched with Lease users #{lease.users.pluck(:email)}"
        end

        if policy_exists?
          raise_error "Child policy already exists for Insurable ID=#{@insurable.id}"
        else
          policy = MasterPolicy::ChildPolicyIssuer.call(enrollment_master_policy, lease)
        end
        notify_users(users, policy)
        render json: policy
      end

      private

      def unit_affordable?(unit)
        return true if unit.special_status == AFFORDABLE_ID

        false
      end

      def lease_users_matched?(lease, users)
        r = false
        lease_emails = lease.users.pluck(:email)
        users_emails = users.pluck(:email)
        users_emails.each do |ue|
          lease_emails.each do |le|
            if ue == le
              r = true
              break
            end
          end
        end
        r
      end

      def disabled_lease_users_matched?(lease, users)
        lease_emails = lease.users.pluck(:email)
        users_emails = users.pluck(:email)
        !(lease_emails - users_emails).empty?
      end

      def policy_exists?
        pi = PolicyInsurable.where(insurable_id: @insurable.id)
        policies_for_insurable = Policy.where(
          id: pi.pluck(:policy_id),
          policy_type_id: PolicyType::MASTER_COVERAGE_ID,
          status: 'BOUND'
        )
        policies_for_insurable.count.positive?
      end

      def branding_for_mail
        BrandingProfile.global_default
      end

      def cost
        configuration = MasterPolicy::ConfigurationFinder.call(enrollment_master_policy, @insurable)
        configuration.total_placement_amount.to_f / 100
      end

      def notify_users(users, policy, force = false)
        users.each do |user|
          # Compliance::PolicyMailer.with(organization: @insurable.account || @insurable.agency)
          #   .enrolled_in_master(user: user,
          #                       community: enrollment_community,
          #                       force: force).deliver_now
          #

          PolicyMailer
            .with(
              organization: @insurable.account || @insurable.agency,
              branding_profile: branding_for_mail,
              user: user,
              policy: policy,
              community: enrollment_community,
              unit: @insurable,
              total_placement_cost: cost)
            .notify_new_child_policy.deliver_now
        end
      end

      def enrollment_lease
        Lease.find_by(insurable_id: @insurable.id, status: 'current')
      end

      def enrollment_master_policy
        enrollment_community.policies.where(policy_type_id: 2).take
      end

      def enrollment_community
        @insurable.parent_community
      end

      def enrollment_users
        ::User.where(email: enrollment_params[:user_attributes].map{|el| el[:email]})
      end

      def create_users_if_not_found
        users = []
        enrollment_params[:user_attributes].each do |user|
          secure_tmp_password = SecureRandom.base64(12)
          new_user = ::User.create({
                                     email: user[:email],
                                     password: secure_tmp_password,
                                     password_confirmation: secure_tmp_password,
                                     profile_attributes: {
                                       contact_email: user[:email],
                                       first_name: user[:first_name],
                                       last_name: user[:last_name]
                                     }}
                                  )
          users << new_user
        end
        users
      end

      def invite_users(users)
        users.each(&:invite!)
      end

      def enrollment_params
        params.permit!
      end
    end
  end
end
