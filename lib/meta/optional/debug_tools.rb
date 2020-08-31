
def toggle_db_output
  return (ActiveRecord::Base.logger.level = (ActiveRecord::Base.logger.level == 1 ? 0 : 1)) == 1 ? "OFF" : "ON"
end

def call_controller_action(controller, action, params = nil)
  cont = controller.new # add string interpretation at some point
  cont.params = ActionController::Parameters.new(params) unless params.nil? # add string interpretation at some point
  cont.send(action)
end
