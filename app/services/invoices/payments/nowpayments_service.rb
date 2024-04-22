# frozen_string_literal: true

module Invoices
  module Payments
    class NowpaymentsService < BaseService
      include Lago::Nowpayments::ErrorHandlable
      include Customers::PaymentProviderFinder

      PENDING_STATUSES = %w[waiting confirming confirmed sending partially_paid].freeze
      SUCCESS_STATUSES = %w[refunded finished].freeze
      FAILED_STATUSES = %w[expired failed].freeze

      def initialize(invoice = nil)
        @invoice = invoice

        super(nil)
      end

      def create
        result.invoice = invoice
        return result unless should_process_payment?

        unless invoice.total_amount_cents.positive?
          update_invoice_payment_status(payment_status: :succeeded)
          return result
        end

        increment_payment_attempts

        res = create_nowpayments_payment

        nowpayments_success, _nowpayments_error = handle_nowpayments_response(res)
        return result unless nowpayments_success

        payment = Payment.new(
          invoice:,
          payment_provider_id: nowpayments_payment_provider.id,
          payment_provider_customer_id: customer.nowpayments_customer.id,
          amount_cents: invoice.total_amount_cents,
          amount_currency: invoice.currency.upcase,
          provider_payment_id: res.response['id'],
          status: 'waiting',
        )
        payment.save!

        update_invoice_payment_status(
          payment_status: invoice_payment_status(payment.status),
        )

        result.payment = payment
        result
      end

      def update_payment_status(provider_payment_id:, status:, metadata: {})
        payment = if metadata[:payment_type] == 'one-time'
          # TODO: Implement
          create_payment(provider_payment_id:, metadata:)
        else
          Payment.find_by(provider_payment_id:)
        end
        return result.not_found_failure!(resource: 'nowpayments_payment') unless payment

        result.payment = payment
        result.invoice = payment.invoice
        return result if payment.invoice.succeeded?

        # NOTE: Had to add this to get working?
        @invoice ||= payment.invoice

        payment.update!(status:)

        update_invoice_payment_status(payment_status: invoice_payment_status(status))

        result
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      def generate_payment_url
        return result unless should_process_payment?

        payment = Payment.find_by(invoice: invoice)

        return result.not_found_failure!(resource: 'payment') if payment.blank?

        result.payment_url = "#{nowpayments_payment_provider.auth_site}/payment/?iid=#{payment.provider_payment_id}"

        result
      rescue Lago::Nowpayments::NowpaymentsError => e
        deliver_error_webhook(e)

        result.service_failure!(code: e.code, message: e.msg)
      end

      private

      attr_accessor :invoice

      delegate :organization, :customer, to: :invoice

      def create_payment(provider_payment_id:, metadata:)
        @invoice = Invoice.find(metadata[:lago_invoice_id])

        increment_payment_attempts

        Payment.new(
          invoice:,
          payment_provider_id: nowpayments_payment_provider.id,
          payment_provider_customer_id: nil, # customer.nowpayments_customer.id,
          amount_cents: invoice.total_amount_cents,
          amount_currency: invoice.currency.upcase,
          provider_payment_id:,
        )
      end

      def should_process_payment?
        return false if invoice.succeeded? || invoice.voided?
        return false if nowpayments_payment_provider.blank?

        true
      end

      def client
        @client ||= Lago::Nowpayments::Client.new(
          api_key: nowpayments_payment_provider.api_key,
          api_site: nowpayments_payment_provider.api_site,
        )
      end

      def success_redirect_url
        nowpayments_payment_provider.success_redirect_url.presence || ::PaymentProviders::NowpaymentsProvider::SUCCESS_REDIRECT_URL
      end

      def nowpayments_payment_provider
        @nowpayments_payment_provider ||= payment_provider(customer)
      end

      def create_nowpayments_payment
        # update_payment_method_id
        client.create_invoice(
          payload: Lago::Nowpayments::Params.new(payment_params).to_h,
        )
      rescue Lago::Nowpayments::NowpaymentsError => e
        deliver_error_webhook(e)
        update_invoice_payment_status(payment_status: :failed, deliver_webhook: false)
        raise e
      end

      def payment_params
        {
          price_amount: invoice.total_amount.to_s,
          price_currency: invoice.currency.downcase,
          order_id: invoice.number,
          ipn_callback_url: nowpayments_payment_provider.ipn_callback_url,
          success_url: nowpayments_payment_provider.success_redirect_url,
          cancel_url: nowpayments_payment_provider.cancel_redirect_url,
          partially_paid_url: nowpayments_payment_provider.partially_paid_redirect_url,
          is_fixed_rate: true,
          is_fee_paid_by_user: true,
        }
      end

      def invoice_payment_status(payment_status)
        return :pending if PENDING_STATUSES.include?(payment_status)
        return :succeeded if SUCCESS_STATUSES.include?(payment_status)
        return :failed if FAILED_STATUSES.include?(payment_status)

        payment_status
      end

      def update_invoice_payment_status(payment_status:, deliver_webhook: true)
        result = Invoices::UpdateService.call(
          invoice:,
          params: {
            payment_status:,
            ready_for_payment_processing: payment_status.to_sym != :succeeded,
          },
          webhook_notification: deliver_webhook,
        )
        result.raise_if_error!
      end

      def increment_payment_attempts
        invoice.update!(payment_attempts: invoice.payment_attempts + 1)
      end

      def deliver_error_webhook(nowpayments_error)
        return unless invoice.organization.webhook_endpoints.any?

        SendWebhookJob.perform_later(
          'invoice.payment_failure',
          invoice,
          provider_customer_id: customer.nowpayments_customer.provider_customer_id,
          provider_error: {
            message: nowpayments_error.msg,
            error_code: nowpayments_error.code,
          },
        )
      end
    end
  end
end
