##
# V2 Controller
# file: app/controllers/v2_controller.rb



# MOOSE WARNING: THINGS TO DO TO IMPROVE EFFICIENCY:
# (1) Remove SQL parse method.
# (2) Use only passed includes as includes.
# (3) Convert includes from WHERE clauses to joins; get rid of handle_order's custom joins and integrate them into the joins tree.
# Results will be:
#   (1) Table aliases remain consistent (extra unused aliases from the initial includes will get their names after the joins have been given theirs);
#   (2) LEFT OUTER JOINs get replaced with LEFT INNER JOINs, reducing time and memory usage;
#   (3) Extra joins when sorts repeat pre-loaded SQL joins will be eliminated.
# ALSO:
# (1) Implement support for "distinct" has_many relationships and for "where" scopes... maybe.

class V2Controller < ApplicationController
  
  # Simple Health Check that will be updated later today
  
	def health_check
		render json: { ok: true , node: "It's alive!"}.to_json	
	end
end
