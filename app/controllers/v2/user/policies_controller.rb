##
# V1 User Policies Controller
# file: app/controllers/v1/user/policies_controller.rb

module V2
  module User
    class PoliciesController < UserController
      before_action :set_policy,
        only: [:show, :confirm, :insecure_public_download]

      def index
        super(:@policies, current_user.policies)
      end

      def show
      end

      def new
      end

      def create
        rph = randomized_password_hash
        @user = current_user

        # get any additionally insured users which are already in the db
        additional_users = params[:users].blank? ? [] : users_params.map do |additional_user|
          to_return = ::User.where(email: additional_user[:email]).take
          if to_return.nil?
            to_return = ::User.new(additional_user)
            to_return.password = rph[:password]
            to_return.password_confirmation = rph[:password_confirmation]
          end
          to_return
        end

        # update @user and save any users not in the db yet, rolling back the transaction if one fails
        created_user_ids = []
        error_creator = nil
        begin
          ActiveRecord::Base.transaction do
            error_creator = @user
            @user.update!(user_params) unless user_params.blank?
            additional_users.each do |additional_user|
              error_creator = additional_user
              if additional_user.id.nil?
                additional_user.save!
                created_user_ids.push(additional_user.id)
              end
            end
            error_creator = nil
          end
        rescue
          render json: (error_creator.nil? ?
                       { error: "please provide identifying information for all additionally insured" }.to_json
                       : error_creator == @user ?
                         @user.errors.to_json
                         : error_creator.errors.to_hash
                           .transform_keys{|k| "#{ !error_creator.email.blank? ? error_creator.email : !(error_creator.profile.first_name.blank? || error_creator.profile.last_name.blank?) ? error_creator.profile.first_name + " " + error_creator.profile.last_name : "Additionally Insured User"}: #{k}"}
                           .to_json),
                 status: 422
          return
        end

        # woo-hoo! proceed to policy creation
        @carrier = Carrier.find(1)
        @policy = @carrier.policies.new(policy_params)
        additional_users.each{|u| @policy.users << u }
        @policy.user = @user

        if @policy.save

          @policy.build_premium()
          if @policy.verify()
            render json: @policy.to_json({ :includes => :user }),
                   status: 200  
          else
            #::User.where(id: created_user_ids).destroy_all
            #::Profile.where(profileable_type: "User", profileable_id: created_user_ids).destroy_all
            render json: { error: "Unable to verify policy", message: "There has been an issue verifying this policy, unable to proceed" }.to_json,
                   status: 422
          end
          else
          ::User.where(id: created_user_ids).destroy_all
          ::Profile.where(profileable_type: "User", profileable_id: created_user_ids).destroy_all
          render json: @policy.errors.to_json,
                 status: 422        
        end
      end
      
      def create_external
        @policy = current_user.policies.new(external_policy_params)
        @policy.carrier = Carrier.where(title: 'Other').take
        
        if @policy.save
	        render :show, status: :created
        else
          render json: @policy.errors,
            status: :unprocessable_entity
        end
	    end

      def confirm
        unless @policy.nil?
          
          if @policy.start_billing()
            if @policy.sync(false)
              if @policy.accept()
                @policy.users.each{|u| u.invite! if u.invitation_created_at.nil? }
                render json: { message: "Policy Accepted" },
                       status: :ok
              else
                render json: { error: "Policy Acceptance Failed", message: "There has been an error accepting this policy" }.to_json,
                       status: 422
              end
            else
            render json: { error: "Unable to start billing", message: "There has been an error starting billing for this policy" }.to_json,
                   status: 422
            end
          else
            render json: { error: "Unable to start billing", message: "There has been an error starting billing for this policy" }.to_json,
                   status: 422
          end
          
        else
          render json: { policy: "not found" },
                 status: 404
        end
          
      end
      
      def check
        set_error = false
        
        if Policy.exists?(:policy_number => params[:policy_number])
          @policy = current_user.policies.where(policy_number: params[:policy_number]).first
          set_error = true unless @policy.accepted?
        else
          set_error = true
        end
        
        if set_error == true
          render json: {
                   title: "Invalid Policy",
                   message: "Policy not found or no longer current."
                 }.to_json,
                 status: :unprocessable_entity 
        else
          render json: {
                   title: "Valid Policy",
                   message: "The server is sending a green light to perform an action on this policy."
                 }.to_json,
                 status: :ok 
        end        
      end

      def insecure_public_download
        unless @policy.nil?
          
          render pdf: 'EvidenceOfInsurance',
                 template: '/v1/qbe/evidence_of_insurance.html',
                 save_to_file: Rails.root.join('public/pdfs', "EvidenceOfInsurance.pdf")
   
        end  
      end

      private

        def view_path
          super + '/policies'
        end

        def policy_params
          params.require(:policy).permit(:effective_date, :expiration_date,
                                         :billing_interval, :number_insured,
                                         :account_id, :unit_id, :user_id, :paid_in_full,
                                         policy_rates_attributes: [:id, :rate_id],
                                         users_attributes: [:email, :guest,
                                           profile_attributes: [
                                             :id, :first_name, :middle_name, :last_name,
                                             :contact_email, :contact_phone, :birth_date
                                           ]                                         
                                         ])
        end
        
        def external_policy_params
	      	params.require(:policy)
	      				.permit(:policy_number, :effective_date, 
	      								:expiration_date, :policy_in_system,
	      								:unit_id, :account_id,
	      								carrier_data: [:other_carrier_name],
	      								documents_attributes: [:file, :title])  
	      end

        def user_params
          params.require(:user).permit(:marital_status,
                                       addresses_params: [
                                         :id, :street_number, :street_one, 
                                         :street_two, :locality, :county,
                                         :region, :country, :postal_code, :plus_four
                                       ])  
        end

        def users_params
          params.require(:users).map do |el|
            el.permit([ :email, :guest, profile_attributes: [
              :first_name, :middle_name, :last_name, :contact_email, :contact_phone, :birth_date
            ]])
          end
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            effective_date: [:scalar, :array, :interval],
            expiration_date: [:scalar, :array, :interval],
            last_payment_date: [:scalar, :array, :interval],
            next_payment_date: [:scalar, :array, :interval],
            auto_renewal: [:scalar],
            renewal_count: [:scalar],
            last_renewed_on: [:scalar, :array, :interval],
            original_expiration_date: [:scalar, :array, :interval],
            billing_status: [:scalar, :array],
            billing_interval: [:scalar, :array],
            billing_behind_since: [:scalar, :array, :interval],
            status: [:scalar, :array],
            billing_enabled: [:scalar],
            user_in_system: [:scalar],
            policy_in_system: [:scalar],
            unit_id: [:scalar, :array],
            carrier_id: [:scalar, :array],
            coverage_level_id: [:scalar, :array]
          }
        end

        def set_policy
          @policy = current_user.policies.find(params[:id])
        end

        def randomized_password_hash
          rp = (0...8).map { (65 + rand(26)).chr }.join
          return({ password: rp, password_confirmation: rp })
        end
    end
  end
end
