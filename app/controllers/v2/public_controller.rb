##
# V2 Public Controller
# File: app/controllers/v2/public_controller.rb

module V2
  class PublicController < V1Controller
    
    private

      def view_path
        super + "/public"
      end
      
      def access_model(model_class, model_id = nil)
        model_class.send(*(model_id.nil? ? [:itself] : [:find, model_id]))
      end
      
  end
end
