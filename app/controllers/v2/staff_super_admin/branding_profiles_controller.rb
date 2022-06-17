module V2
  module StaffSuperAdmin
    class BrandingProfilesController < StaffSuperAdminController
      include BrandingProfilesMethods

      before_action :set_branding_profile,
                    only: %i[update show destroy faqs faq_create faq_update faq_question_create
                             faq_question_update faq_delete faq_question_delete attach_images export update_from_file second_logo_delete]

      before_action :set_agency, only: [:import]

      def create
        profileable =
          case branding_profile_params[:profileable_type]
          when 'Account'
            Account.find_by_id(branding_profile_params[:profileable_id])
          when 'Agency'
            Agency.find_by_id(branding_profile_params[:profileable_id])
          end


        if profileable.present?
          branding_profile_outcome =
            case profileable
            when Agency
              BrandingProfiles::CreateFromDefault.run(agency: profileable)
            when Account
              BrandingProfiles::CreateFromDefault.run(account: profileable)
            end


          if branding_profile_outcome.valid?
            @branding_profile = branding_profile_outcome.result
            render template: 'v2/shared/branding_profiles/show', status: :created
          else
            render json: standard_error(
                           :branding_profile_was_not_created,
                           'Branding profile was not created',
                           branding_profile_outcome.errors
                         ),
                   status: :unprocessable_entity
          end
        else
          render json: standard_error(:agency_was_not_found,'Agency was not found'),
                 status: :unprocessable_entity
        end
      end

      def faqs
        @faqs = params['language'].present? ? BrandingProfile.find(params[:id]).faqs.where(language: params['language']) : BrandingProfile.find(params[:id]).faqs
        render :faqs, status: :ok
      end

      def faq_create
        @branding_profile = BrandingProfile.find(params[:id])
        @faq = @branding_profile.faqs.new(faq_params.merge(faq_order_params))
        if @faq.errors.empty? && @faq.save
          render json: @faq, status: :created
        else
          render json: { message: @faq.errors }, status: :unprocessable_entity
        end
      end

      def faq_update
        @branding_profile = BrandingProfile.find(params[:id])
        @faq = @branding_profile.faqs.find(params[:faq_id])
        if @faq.update(faq_params)
          render json: @faq, status: :created
        else
          render json: { message: @faq.errors }, status: :unprocessable_entity
        end
      end

      def faq_delete
        @branding_profile = BrandingProfile.find(params[:id])
        @faq = @branding_profile.faqs.find(params[:faq_id])
        if @faq.destroy
          render json: { message: 'Section deleted' }, status: :ok
        else
          render json: { message: @faq.errors }, status: :unprocessable_entity
        end
      end

      def faq_question_create
        @branding_profile = BrandingProfile.find(params[:id])
        @faq = @branding_profile.faqs.find(params[:faq_id])
        @faq_question = @faq.faq_questions.new(faq_question_params.merge(question_order_params))
        if @faq_question.errors.empty? && @faq_question.save
          render json: @faq_question, status: :created
        else
          render json: { message: @faq_question.errors }, status: :unprocessable_entity
        end
      end

      def faq_question_update
        @branding_profile = BrandingProfile.find(params[:id])
        @faq = @branding_profile.faqs.find(params[:faq_id])
        @faq_question = @faq.faq_questions.find(params[:faq_question_id])
        if @faq_question.update(faq_question_params)
          render json: @faq_question, status: :created
        else
          render json: { message: @faq_question.errors }, status: :unprocessable_entity
        end
      end

      def faq_question_delete
        @branding_profile = BrandingProfile.find(params[:id])
        @faq = @branding_profile.faqs.find(params[:faq_id])
        @faq_question = @faq.faq_questions.find(params[:faq_question_id])
        if @faq_question.destroy
          render json: { message: 'Section deleted' }, status: :ok
        else
          render json: { message: @faq_question.errors }, status: :unprocessable_entity
        end
      end

      def update
        if update_allowed?
          if @branding_profile.update(branding_profile_params)
            render template: 'v2/shared/branding_profiles/show', status: :ok
          else
            render json: @branding_profile.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def destroy
        if destroy_allowed?
          if @branding_profile.destroy
            render json: { success: true }, status: :ok
          else
            render json: { success: false }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end



      private

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          profileable_type: [:scalar],
          profileable_id: [:scalar],
          url: [:scalar, :like],
          enabled: [:scalar]
        }
      end

      def relation
        BrandingProfile
      end

      def supported_orders
        supported_filters(true)
      end

      def view_path
        super + '/branding_profiles'
      end

      def update_allowed?
        true
      end

      def destroy_allowed?
        true
      end

      def set_branding_profile
        @branding_profile = access_model(::BrandingProfile, params[:id])
      end

      def set_agency
        @agency = Agency.find_by_id(params[:agency_id])
        render json: standard_error(:agency_was_not_found), status: 422 if @agency.blank?
      end

      def branding_profile_params
        return({}) if params[:branding_profile].blank?

        params.require(:branding_profile).permit(
          :default, :id, :profileable_id, :profileable_type,
          :url, :footer_logo_url, :logo_url, :subdomain, :subdomain_test, :global_default, :enabled,
          images: [], branding_profile_attributes_attributes: %i[id name value attribute_type],
          styles: {}
        )
      end

      def faq_params
        return({}) if params.blank?

        params.permit(:title, :branding_profile_id, :faq_order, :language)
      end

      def faq_order_params
        { faq_order: @branding_profile.faqs.count }
      end

      def question_order_params
        { question_order: @faq.faq_questions.count }
      end

      def faq_question_params
        return({}) if params.blank?

        params.permit(:question, :answer, :faq_id, :question_order)
      end
    end
  end
end
