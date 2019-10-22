# V2 Stripe Charges Controller
# file: app/controllers/v2/stripe/charges_controller.rb

module V2
  module Stripe
    class ChargesController < StripeController
      before_action :set_response_body
      
      # Stripe Charge Failed
      #
      
      def failed
        @charge = ::Charge.where(stripe_id: @response_body["data"]["object"]["id"]).take
        if @charge.nil?
          render json: { success: false, errors: "No Charge found with stripe_id '#{@response_body["data"]["object"]["id"]}'" }.to_json,
            status: 422
          return
        end
        # mark the charge as failed
        @charge.mark_failed("Payment processor reported failure: #{@response_body["data"]["object"]['failure_message'] || 'unknown error'} (code #{@response_body["data"]["object"]['failure_code'] || 'null'})")
        render json: { success: true }.to_json, 
          status: 200
      end
      
      # Stripe Charge Succeeded
      #
      
      def succeeded
        @charge = ::Charge.where(stripe_id: @response_body["data"]["object"]["id"]).take
        if @charge.nil?
          render json: { success: false, errors: "No Charge found with stripe_id '#{@response_body["data"]["object"]["id"]}'" }.to_json,
            status: 422
          return
        end
        # mark the charge as failed
        @charge.mark_succeeded
        render json: { success: true }.to_json, 
          status: 200
      end

      # Stripe Charge Refund Updated
      #

      def refund_updated
        @refund = ::Refund.where(stripe_id: @response_body["data"]["object"]["id"])
        if @refund.nil?
          render json: { success: false, errors: "No Refund found with stripe_id '#{@response_body["data"]["object"]["id"]}'" }.to_json,
            status: 422
          return
        end
        unless @refund.update_from_stripe_hash(@response_body["data"]["object"])
          render json: { success: false, errors: "Failed to update refund record" }.to_json,
            status: 422
          return
        end
        render json: { success: true }.to_json,
          status: 200
      end

      # Stripe Charge Dispute Created
      #

      def dispute_created
        @charge = ::Charge.where(stripe_id: @response_body["data"]["object"]["charge"])
        if @charge.nil?
          render json: { success: false, errors: "No Charge found with stripe_id '#{@response_body["data"]["object"]["charge"]}'" }.to_json,
            status: 422
          return
        end
        created_dispute = @charge.disputes.create({
          stripe_id: dispute_hash['id'],
          amount: dispute_hash['amount'],
          reason: dispute_hash['reason'],
          status: dispute_hash['status']
        })
        unless created_dispute
          render json: { success: false, errors: "Failed to save dispute record" }.to_json,
            status: 422
          return
        end
        render json: { success: true }.to_json,
          status: 200
      end

      # Stripe Charge Dispute Updated
      #

      def dispute_updated
        @dispute = ::Dispute.where(stripe_id: @response_body["data"]["object"]["id"])
        if @dispute.nil?
          render json: { success: false, errors: "No Dispute found with stripe_id '#{@response_body["data"]["object"]["id"]}'" }.to_json,
            status: 422
          return
        end
        unless @dispute.update_from_stripe_hash(@response_body["data"]["object"])
          render json: { success: false, errors: "Failed to update dispute record" }.to_json,
            status: 422
          return
        end
        render json: { success: true }.to_json,
          status: 200
      end

      # Stripe Charge Dispute Closed
      #

      def dispute_closed
        @dispute = ::Dispute.where(stripe_id: @response_body["data"]["object"]["id"])
        if @dispute.nil?
          render json: { success: false, errors: "No Dispute found with stripe_id '#{@response_body["data"]["object"]["id"]}'" }.to_json,
            status: 422
          return
        end
        unless @dispute.update_from_stripe_hash(@response_body["data"]["object"])
          render json: { success: false, errors: "Failed to update dispute record" }.to_json,
            status: 422
          return
        end
        render json: { success: true }.to_json,
          status: 200
      end
      
      private
      
        def set_response_body
          
          @response_body = JSON.parse(request.body.read)
          
          unless @response_body["data"].nil?
            unless @response_body["data"]["object"].nil?
              # We have a response
              # so do nothing :)
            else
              render json: { error: "Response Object Missing" }, 
                status: 422
            end
          else
            render json: { error: "Response Data Missing" }, 
              status: 422
          end
        end
    end
  end
end
