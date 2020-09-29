module V2
  module StaffSuperAdmin
    class BrandingProfilesController < StaffSuperAdminController
      before_action :set_branding_profile, only: %i[update show destroy faqs faq_create faq_update faq_question_create faq_question_update faq_delete faq_question_delete]
      
      def index
        super(:@branding_profiles, BrandingProfile)
      end

      def show; end

      def create
        @branding_profile = BrandingProfile.new(branding_profile_params)
        if @branding_profile.errors.none? && @branding_profile.save
          render :show, status: :created
        else
          render json: @branding_profile.errors, status: :unprocessable_entity
        end
      end

      def faqs
        @branding_profile = BrandingProfile.includes(:faqs).find(params[:id]) || []
        render :faqs, status: :ok
      end

      def faq_create
        @branding_profile = BrandingProfile.find(params[:id])
        @faq = @branding_profile.faqs.new(faq_params)
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
        @faq_question = @faq.faq_questions.new(faq_question_params)
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
            render :show, status: :ok
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

      def branding_profile_params
        return({}) if params[:branding_profile].blank?

        params.require(:branding_profile).permit(
          :default, :id, :profileable_id, :profileable_type, :title,
          :url, :footer_logo_url, :logo_url, :subdomain, :subdomain_test,
          branding_profile_attributes_attributes: %i[id name value attribute_type], 
          styles: {}
        )
      end

      def faq_params
        return({}) if params.blank?

        params.permit(:title, :branding_profile_id)
      end

      def faq_question_params
        return({}) if params.blank?

        params.permit(:question, :answer, :faq_id)
      end
    end
  end
end
