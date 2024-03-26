# frozen_string_literal: true

FactoryBot.define do
  sequence :adyen_payments_response do
    OpenStruct.new(
      status: 200,
      response: {
        'additionalData' => {
          'recurringProcessingModel' => 'UnscheduledCardOnFile',
        },
        'pspReference' => SecureRandom.uuid,
        'resultCode' => 'Authorised',
        'merchantReference' => SecureRandom.uuid,
      },
    )
  end

  sequence :adyen_payments_error_response do
    OpenStruct.new(
      status: 422,
      response: {
        'errorType' => 'validation',
        'message' => 'There are no payment methods available for the given parameters.',
      },
    )
  end

  sequence :adyen_payment_links_response do
    OpenStruct.new(
      status: 200,
      response: {
        'amount' => {
          'currency' => 'EUR',
          'value' => 0,
        },
        'expiresAt' => '2023-05-19T10:00:19+02:00',
        'merchantAccount' => SecureRandom.uuid,
        'recurringProcessingModel' => 'UnscheduledCardOnFile',
        'reference' => SecureRandom.uuid,
        'reusable' => false,
        'shopperReference' => SecureRandom.uuid,
        'storePaymentMethodMode' => 'enabled',
        'id' => SecureRandom.uuid,
        'status' => 'active',
        'url' => 'https://test.adyen.link/test',
      },
    )
  end

  sequence :adyen_payment_links_error_response do
    OpenStruct.new(
      status: 422,
      response: {
        'errorType' => 'validation',
        'message' => 'There are no payment methods available for the given parameters.',
      },
    )
  end

  sequence :adyen_payment_methods_response do
    OpenStruct.new(
      status: 200,
      response: {
        'paymentMethods' => [
          {
            'brands' => %w[amex bcmc cartebancaire mc visa visadankort],
            'name' => 'Credit Card',
            'type' => 'scheme',
          },
        ],
        'storedPaymentMethods' => [
          {
            'brand' => 'visa',
            'expiryMonth' => '03',
            'expiryYear' => '30',
            'holderName' => 'Checkout Shopper PlaceHolder',
            'id' => SecureRandom.uuid,
            'lastFour' => '1234',
            'name' => 'VISA',
            'networkTxReference' => SecureRandom.uuid,
            'supportedRecurringProcessingModels' => %w[CardOnFile Subscription UnscheduledCardOnFile],
            'supportedShopperInteractions' => %w[Ecommerce ContAuth],
            'type' => 'scheme',
          },
        ],
      },
    )
  end

  sequence :nowpayments_invoice_response do
    id = SecureRandom.uuid
    OpenStruct.new(
      status: 200,
      response: {
        'id' => id,
        'token_id' => SecureRandom.uuid,
        'order_id' => SecureRandom.uuid,
        'order_description' => 'description',
        'price_amount' => '10.00',
        'price_currency' => 'USD',
        'pay_currency' => nil,
        'ipn_callback_url' => 'https://nowpayments.io',
        'invoice_url' => "https://sandbox.nowpayments.io/payment/?iid=#{id}",
        'success_url' => 'https://nowpayments.io',
        'cancel_url' => 'https://nowpayments.io',
        'partially_paid_url' => 'https://nowpayments.io',
        'payout_currency' => nil,
        'created_at' => '2024-03-23T01:37:56.549Z',
        'updated_at' => '2024-03-23T01:37:56.549Z',
        'is_fixed_rate' => true,
        'is_fee_paid_by_user' => true,
      },
    )
  end
end
