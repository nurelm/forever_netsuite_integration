module NetsuiteIntegration
  module Services
    class CustomerDeposit < Base
      attr_reader :payments, :persisted, :payload

      def initialize(config, payload = {})
        super config
        @payload = payload
        @payments = payload[:order][:payments] if payload[:order]
      end

      def create_records(sales_order)
        completed_payments.map do |payment|
          external_id = "#{prefix}-#{sales_order.external_id}-#{payment[:number]}"

          if payment[:amount] > 0
            unless deposit = find_by_external_id(external_id)
              deposit = build(sales_order, payment)
              result = deposit.add

              puts deposit.inspect #debug

              # Need to know if at least one of them was persisted
              @persisted ||= result
            end
          end

          deposit
        end.compact
      end

      # Apparently we dont need to pass the customer reference. Tried that for a
      # while and was either getting "permission error" or "Invalid reference
      # for customer key 4353 (customer internal id)"
      def build(sales_order, payment)
        deposit = NetSuite::Records::CustomerDeposit.new

        # Warning: works with 2013_1 through 2013_2; may cause INSUFFICIENT_PERMISSION on other versions

        # Setting external_id to Spree's order number, so we could search by it later
        # Warning: external_id must be unique across all NetSuite data objects
        deposit.external_id = "#{prefix}-#{sales_order.external_id}-#{payment[:number]}"

        deposit.sales_order = NetSuite::Records::RecordRef.new(internal_id: sales_order.internal_id)
        deposit.customer = NetSuite::Records::RecordRef.new(internal_id: sales_order.entity.internal_id)

        if config['netsuite_account_for_sales_id'].present?
          deposit.account = NetSuite::Records::RecordRef.new(internal_id: config.fetch('netsuite_account_for_sales_id'))
          # possible permission error on the accounts field if this is not set to false
          deposit.undep_funds = false
        else
          deposit.undep_funds = true
        end

        deposit.payment = payment[:amount]
        deposit.tran_date = sales_order.tran_date || payload[:order][:placed_on]

        if department_id(payment).present?
          deposit.department = NetSuite::Records::RecordRef.new(internal_id: department_id(payment))
        end

        deposit
      end

      # Current limitation is that we can only get 1 customer deposit back
      def find_by_external_id(external_id)
        NetSuite::Records::CustomerDeposit.get external_id: external_id
      rescue NetSuite::RecordNotFound
        nil
      end

      def find_by_sales_order(sales_order, payments)
        payments.map do |p|
          next unless p[:amount] > 0

          external_id = build_id sales_order, p
          NetSuite::Records::CustomerDeposit.get external_id: external_id
        end.compact
      end

      private
        def department_id(payment)
          payment['netsuite_department_id'] || config['netsuite_department_id']
        end

        def build_id(sales_order, payment)
          "#{prefix}-#{sales_order.external_id}-#{payment[:number]}"
        end

        # Prefix is used to avoid running into external_id duplications
        def prefix
          'cd'
        end

        def completed_payments
          payments.select { |p| p[:status] == "completed" }
        end
    end
  end
end
