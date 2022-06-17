##
# V2 StaffAgency BrandingProfiles Controller
# File: app/controllers/v2/staff_agency/branding_profiles_controller.rb

module V2
  module StaffAgency
    class BrandingProfilesController < StaffAgencyController
      include BrandingProfilesMethods
      before_action :set_branding_profile,
                    only: %i[update show destroy faqs faq_create faq_update
                             faq_question_create faq_question_update attach_images export update_from_file second_logo_delete]


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
          render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
        end
      end

      private

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          profileable_type: [:scalar],
          profileable_id: [:scalar],
          enabled: [:scalar],
          url: [:scalar, :like]
        }
      end

      def relation
        BrandingProfile.where(profileable_type: 'Agency', profileable_id: @agency.id).
          or BrandingProfile.where(profileable_type: 'Account', profileable_id: @agency.accounts&.ids)
      end

      def supported_orders
        supported_filters(true)
      end

      def view_path
        super + '/branding_profiles'
      end

      def create_allowed?
        true
      end

      def update_allowed?
        true
      end

      def set_branding_profile
        @branding_profile = @agency.branding_profiles.find_by_id(params[:id]) || BrandingProfile.where(profileable_type: 'Account', profileable_id: @agency.accounts.ids).find_by_id(params[:id])
      end

      def branding_profile_params
        return({}) if params[:branding_profile].blank?

        params.require(:branding_profile).permit(
          :default, :profileable_id, :profileable_type,
          :footer_logo_url, :logo_url, :subdomain, :subdomain_test, :enabled, images: [],
                                                                              branding_profile_attributes_attributes: %i[id name value attribute_type],
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
  end # module StaffAgency
end
