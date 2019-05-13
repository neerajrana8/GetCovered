module V1
  module Staff
    class ApplicationModulesController < StaffController
      before_action :set_application_module, only: [:edit, :show, :update, :destroy]
      before_action :only_super_admins
      
      def index
        @application_modules = ApplicationModule.all
        
        respond_to do |format|
          format.html
          format.json { render json: @application_module }
        end
      end
      
      def show; end
      
      def new
        @application_module = ApplicationModule.new
        
        respond_to do |format|
          format.html # new.html.erb
          format.json { render json: @application_module }
        end
      end

      def edit; end
      
      def create
        @application_module = ApplicationModule.new(application_module_params)  
        respond_to do |format|
          if @application_module.save
            format.html { redirect_to @application_module, notice: 'ApplicationModule was successfully created.' }
            format.json { render json: @application_module, status: :created, location: @application_module }
          else
            format.html { render action: "new" }
            format.json { render json: @application_module.errors, status: :unprocessable_entity }
          end
        end
      end

      def update        
        respond_to do |format|
          if @application_module.update_attributes(application_module_params)
            format.html { redirect_to @application_module, notice: 'ApplicationModule was successfully updated.' }
            format.json { head :no_content }
          else
            format.html { render action: "edit" }
            format.json { render json: @application_module.errors, status: :unprocessable_entity }
          end
        end
      end

      def destroy
        @application_module.destroy
        respond_to do |format|
          format.html { redirect_to application_modules_url }
          format.json { head :no_content }
        end
      end

      private
      
      def set_application_module
        @application_module = ApplicationModule.find(params[:id])
      end
      
      def view_path
        super + '/application_modules'
      end
      
      def application_module_params
        params.require(:application_module).permit(:title, :enabled)
      end
    end
  end
end
