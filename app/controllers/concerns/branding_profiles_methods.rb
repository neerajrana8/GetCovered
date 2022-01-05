module BrandingProfilesMethods
  extend ActiveSupport::Concern

  included do
    before_action :validate_images_size, only: :attach_images
  end

  def index
    super(:@branding_profiles, relation)
    render template: 'v2/shared/branding_profiles/index', status: :ok
  end

  def list
    apply_filters(:@branding_profiles, relation)
    render template: 'v2/shared/branding_profiles/list', status: :ok
  end

  def show
    if @branding_profile.nil?
      render json: standard_error(error: :branding_profile_not_found, message: "Branding profile not found"),
             status: :not_found
    else
      render template: 'v2/shared/branding_profiles/show', status: :ok
    end
  end

  def import
    file = params[:input_file].open
    branding_profile_import =
      BrandingProfiles::Import.run(branding_profile_params: JSON.parse(file.read), agency: @agency)
    if branding_profile_import.valid?
      @branding_profile = branding_profile_import.result
      render :show, status: :ok
    else
      render json: standard_error(:branding_profile_import_fail, nil, branding_profile_import.errors.full_messages),
             status: :unprocessable_entity
    end
  end

  def update_from_file
    file = params[:input_file].open
    branding_profile_update =
      BrandingProfiles::Update.run(branding_profile: @branding_profile, branding_profile_params: JSON.parse(file.read))
    if branding_profile_update.valid?
      @branding_profile = branding_profile_update.result
      render :show, status: :ok
    else
      render json: standard_error(:branding_profile_import_fail, nil, branding_profile_update.errors.full_messages),
             status: :unprocessable_entity
    end
  end

  def export
    result = BrandingProfiles::Export.run!(branding_profile: @branding_profile).to_json
    send_data result,
              filename: "branding-profile-#{@branding_profile.profileable_type.underscore.split('/').last}-#{Date.today}.json",
              status: :ok
  end

  def attach_images
    if update_allowed?
      logo_status = process_image(:logo_url) if attach_images_params[:logo_url].present?
      logo_jpeg_status = process_image(:logo_jpeg_url) if attach_images_params[:logo_jpeg_url].present?
      footer_status = process_image(:footer_logo_url) if attach_images_params[:footer_logo_url].present?
      if logo_status == 'error' || logo_jpeg_status == 'error' || footer_status == 'error'
        render json: { success: false }, status: :unprocessable_entity
      else
        render json: { logo_url: logo_status, logo_jpeg_url: logo_jpeg_status, footer_logo_url: footer_status }, status: :ok
      end
    else
      render json: { success: false, errors: ['Unauthorized Access'] }, status: :unauthorized
    end
  end

  private

  def attach_images_params
    return({}) if params.blank?

    params.require(:images).permit(:logo_url, :logo_jpeg_url, :footer_logo_url)
  end

  def validate_images_size
    images = %i[logo_url logo_jpeg_url footer_logo_url]
    images.each do |image|
      if attach_images_params[image].present? && (attach_images_params[image].size > 10.megabyte)
        render json: standard_error(:images_bad_size, "#{image} is bigger than 10 megabytes"), status: :unprocessable_entity
        break
      end
    end
  end

  def process_image(field_name)
    resize_image(field_name)
    rename_image(field_name)
    image_attached = @branding_profile.images.attach(attach_images_params[field_name])
    if image_attached
      img_url = rails_blob_url(@branding_profile.images.last)
      img_url.present? && @branding_profile.update_column(field_name, img_url) ? img_url : 'error'
    else
      'error'
    end
  end

  def resize_image(field_name)
    unless attach_images_params[field_name].content_type == 'image/svg+xml'
      MiniMagick::Image.open(attach_images_params[field_name].tempfile.path).resize('600x1200>')
    end
  end

  def rename_image(field_name)
    attach_images_params[field_name].original_filename =
      "#{SecureRandom.uuid.tr('-', '')}.#{attach_images_params[field_name].original_filename.split('.').last}"
  end
end
