module NetsuiteIntegration
  class Base
    attr_accessor :payload, :config

    def initialize(config, payload = {})
      @config = config
      @payload = payload
    end

    def customer_service
      @customer_service ||= NetsuiteIntegration::Services::Customer.new(@config)
    end

    def customer_refund_service
      @customer_refund_service ||= NetsuiteIntegration::Services::CustomerRefund.new(@config)
    end

    def customer_deposit_service
      @customer_deposit_service ||= NetsuiteIntegration::Services::CustomerDeposit.new(@config)
    end

    def inventory_item_service
      @inventory_item_service ||= NetsuiteIntegration::Services::InventoryItem.new(@config)
    end

    def non_inventory_item_service
      @non_inventory_item_service ||= NetsuiteIntegration::Services::NonInventoryItemService.new(@config)
    end

    def sales_order_service
      @sales_order_service ||= NetsuiteIntegration::Services::SalesOrder.new(@config)
    end
  end

  # Customer Errors
  class AlreadyPersistedCustomerException < StandardError; end
  class UpdateFailCustomerException < StandardError; end
  class CreationFailCustomerException < StandardError; end
  class RecordNotFoundCustomerException < StandardError; end

  # Customer Deposit Errors
  class RecordNotFoundCustomerDeposit < StandardError; end

  # Sales Order Errors
  class RecordNotFoundSalesOrder < StandardError; end

  # Customer Refund Errors
  class CreationFailCustomerRefundException < StandardError; end

  class NonInventoryItemException < StandardError; end

  class UnmappableCustomBodyFieldException < StandardError
    def initialize(msg=nil)
      msg ||= 'Unable to map a custom body field name to an internal id and type.'\
       ' Check your wombat flow parameter netsuite_custom_body_fields_map'
      super
    end
  end
end
