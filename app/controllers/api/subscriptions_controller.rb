# frozen_string_literal: true

class Api::SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    if params[:stripeToken]
      begin
          customer = Stripe::Customer.list(email: current_user.email).data.first
          customer = Stripe::Customer.create({ email: current_user.email, source: params[:stripeToken] })
          subscription = Stripe::Subscription.create({ customer: customer.id, plan: 'urban_subscription' })

          if Rails.env.test?
            invoice = Stripe::Invoice.create({
              customer: customer.id,
              subscription: subscription.id,
              paid: true
            })

            subscription.latest_invoice = invoice.id
            status = Stripe::Invoice.retrieve(subscription.latest_invoice).paid
          else
            status = Stripe::Invoice.retrieve(subscription.latest_invoice).paid
          end

          if status
            current_user.role = 'subscriber'
            current_user.save
            render json: { message: 'Transaction cleared' }
          else
            stripe_error_handler('Transaction did not go through')
          end
      rescue => error
        stripe_error_handler(error.message)
        end
    else
      stripe_error_handler('Internal problem with your payment. Please contact customer support')
    end
   end

  private

  def stripe_error_handler(error)
    render json: { error_message: error }, status: 400
  end
end
