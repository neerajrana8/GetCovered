##
# V1 Portations Reports Controller
# file: app/controllers/v1/account/portations_controller.rb

module V1
  module Account
    class PortationsController < StaffController
      before_action :set_portation,
        except: [:index, :create, :mappings]
        
	    	def index
		    	@portations = current_staff.account.portations
		    end
		    
		    def show
			  	# Blank  
			  end
			  
			  def create
	        @portation = current_staff.portations.new(portation_params)

	        if @portation.process_action == 'export'
		        
		        selection = params[:selection].nil? ? {
			        :scheme => 'all', # options: all, date_range, on_relation
			        :parent => nil,
			        :id => nil 
		        } : params[:selection]
		        
		        if selection[:scheme] == 'date_range'
			      	start_date = Date.parse(params[:start_date])
			      	end_date = Date.parse(params[:end_date])
			        @portation.system_data['export_ids'] = @portation.process_category
			        																								 .singularize
			        																							   .titlecase
			        																								 .gsub(/\s+/, "")
			        																								 .constantize
			        																								 .where(:created_at => start_date.beginning_of_day..end_date.end_of_day)
			        																								 .map(&:id)	
			      elsif selection[:scheme] == 'on_relation'
			      	
			      	parent_model = selection[:parent].constantize.find(selection[:id].to_i)
			      	@portation.system_data['export_ids'] = parent_model.send(@portation.process_category)
			      																										 .all.order(:created_at)
			      																										 .map(&:id)
            else
			        @portation.system_data['export_ids'] = @portation.process_category
			        																								 .singularize
			        																							   .titlecase
			        																								 .gsub(/\s+/, "")
			        																								 .constantize
			        																								 .all
			        																								 .map(&:id)	
			      end
		      
	        end
	        
	        if @portation.save() && @portation.reload()
		        if @portation.process_action == 'export'
		        	if @portation.queue()
			        	render :show, 
			        		status: :created
			        else
			          puts "\n\nEXPORT ERROR\n\n".red
								pp @portation.errors.full_messages unless @portation.errors.blank?
								pp @portation.document.errors.full_messages unless @portation.document.errors.blank?
								
			          render json: @portation.errors.to_json,
			            status: :unprocessable_entity
			        end
		        elsif @portation.process_action == 'import'
		          
		          prep_check = @portation.prepare()
		          status_color = prep_check ? "green" : "red"
		          
		          puts "\n\nPREP CHECK: #{ prep_check }\n\n".send(status_color)
		          
		        	if @portation.prepare
			        	render :show, 
			        		status: :created
			        else
			          puts "\n\nIMPORT ERROR\n\n".red
								pp @portation.errors.full_messages unless @portation.errors.blank?
								pp @portation.document.errors.full_messages unless @portation.document.errors.blank?
	        	
			          render json: @portation.document.errors.to_json,
			            status: :unprocessable_entity
			        end
		        end
	        else
			      puts "\n\nSAVE ERROR\n\n".red
	        	pp @portation.errors.full_messages unless @portation.errors.blank?
	        	
	          render json: @portation.errors.to_json,
	            status: :unprocessable_entity
	        end
				end
				
				def queue
					if @portation.queue
						render json: { success: true }.to_json,
							status: :ok
					else	        	
	          render json: @portation.errors.to_json,
	            status: :unprocessable_entity
					end
				end
				
				def mappings
					render json: Portation.new(portation_params)
															  .mapping_data.to_json, status: :ok
				end
				
				def update
					# Blank
				end
				
				private
					def set_portation
						@portation = Portation.find(params[:id])	
					end
					
					def portation_params
          	params.require(:portation)
          				.permit(:status, :overwrite, :process_category, 
          								:process_action, :process_level, 
          								mapping_data: [ assignments: [
	          								:access, :field, :label, :enabled,
	          								:column, :transformations, :required
          								]],
          								document_attributes: [
	          								:title, :file_type, :authorable_type, 
	          								:authorable_id, :file, :file_data => []
          								])
					end
					
					def file_params
						params.require(:document).permit(:file)	
					end
	   end
	end
end