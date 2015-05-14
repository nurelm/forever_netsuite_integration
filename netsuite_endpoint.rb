require "sinatra"
require "endpoint_base"

require File.expand_path(File.dirname(__FILE__) + '/lib/netsuite_integration')

class NetsuiteEndpoint < EndpointBase::Sinatra::Base
  Honeybadger.configure do |config|
    config.api_key = ENV['HONEYBADGER_KEY']
    config.environment_name = ENV['RACK_ENV']
  end if ENV['HONEYBADGER_KEY'].present?

  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_API']
    config.host    = ENV['AIRBRAKE_HOST'] if ENV['AIRBRAKE_HOST'].present?
    config.port    = ENV['AIRBRAKE_PORT'] if ENV['AIRBRAKE_PORT'].present?
    config.secure  = config.port == 443
  end if ENV['AIRBRAKE_API'].present?

  set :logging, true
  set :show_exceptions, false

  error Errno::ENOENT, NetSuite::RecordNotFound, NetsuiteIntegration::NonInventoryItemException do
    result 500, env['sinatra.error'].message
  end

  error Savon::SOAPFault do
    result 500, env['sinatra.error'].to_s
  end

  before do
    if config = @config
      # https://github.com/wombat/netsuite_integration/pull/27
      # Set connection/flow parameters with environment variables if they aren't already set from the request
      %w(email password account role sandbox api_version wsdl_url silent).each do |env_suffix|
        if ENV["NETSUITE_#{env_suffix.upcase}"].present? && config["netsuite_#{env_suffix}"].nil?
          config["netsuite_#{env_suffix}"] = ENV["NETSUITE_#{env_suffix.upcase}"]
        end
      end

      @netsuite_client ||= NetSuite.configure do
        reset!

        if config['netsuite_wsdl_url'].present?
          wsdl config['netsuite_wsdl_url']
        end

        if config['netsuite_api_version'].present?
          api_version config['netsuite_api_version']
        else
          api_version "2013_2"
        end

        if config['netsuite_role'].present?
          role config['netsuite_role']
        else
          role 3
        end

        sandbox config['netsuite_sandbox'].to_s == "true" || config['netsuite_sandbox'].to_s == "1"

        email        config.fetch('netsuite_email')
        password     config.fetch('netsuite_password')
        account      config.fetch('netsuite_account')
        read_timeout 175
        log_level    :info
      end
    end
  end

  post '/get_products' do
    products = NetsuiteIntegration::Product.new(@config)

    if products.collection.any?
      products.messages.each do |message|
        add_object "product", message
      end

      add_parameter 'netsuite_last_updated_after', products.last_modified_date

      count = products.messages.count
      @summary = "#{count} #{"item".pluralize count} found in NetSuite"
    end

    result 200, @summary
  end

  ['/add_order', '/update_order'].each do |path|
    post path do
      begin
        create_or_update_order
      rescue NetsuiteIntegration::CreationFailCustomerException => e
        result 500, "Could not save customer #{@payload[:order][:email]}: #{e.message}"
      end
    end
  end

  post '/cancel_order' do
    if order = sales_order_service.find_by_external_id(@payload[:order][:number] || @payload[:order][:id])
      if customer_record_exists?
        refund = NetsuiteIntegration::Refund.new(@config, @payload, order)
        if refund.process!
          summary = "Customer Refund created and NetSuite Sales Order #{@payload[:order][:number]} was closed"
          result 200, summary
        else
          summary = "Failed to create a Customer Refund and close the NetSuite Sales Order #{@payload[:order][:number]}"
          result 500, summary
        end
      else
        sales_order_service.close!(order)
        result 200, "NetSuite Sales Order #{@payload[:order][:number]} was closed"
      end
    else
      result 500, "NetSuite Sales Order not found for order #{@payload[:order][:number] || @payload[:order][:id]}"
    end
  end

  post '/get_inventory' do
    begin
      stock = NetsuiteIntegration::InventoryStock.new(@config, @payload)

      if stock.collection? && stock.inventory_units.present?
        stock.inventory_units.each { |unit| add_object :inventory, unit }
        count = stock.inventory_units.count
        summary = "#{count} #{"inventory units".pluralize count} fetched from NetSuite"

        add_parameter 'netsuite_poll_stock_timestamp', stock.last_modified_date

      elsif stock.sku.present?

        add_object :inventory, { id: stock.sku, sku: stock.sku, quantity: stock.quantity_available }
        count = stock.quantity_available
        summary = "#{count} #{"unit".pluralize count} available of #{stock.sku} according to NetSuite"
      end

      result 200, summary
    rescue NetSuite::RecordNotFound
      result 200
    end
  end

  post '/get_shipments' do
    shipment = NetsuiteIntegration::Shipment.new(@config, @payload)

    if !shipment.latest_fulfillments.empty?

      count = shipment.latest_fulfillments.count
      summary = "#{count} #{"shipment".pluralize count} found in NetSuite"

      add_parameter 'netsuite_poll_fulfillment_timestamp', shipment.last_modified_date
      shipment.messages.each { |s| add_object :shipment, s }

      result 200, summary
    else
      result 200
    end
  end

  post '/add_shipment' do
    order = NetsuiteIntegration::Shipment.new(@config, @payload).import
    result 200, "Order #{order.external_id} fulfilled in NetSuite # #{order.tran_id}"
  end

  private
  # NOTE move this somewhere else ..
  def create_or_update_order
    order = NetsuiteIntegration::Order.new(@config, @payload)

    error_notification = ""
    summary = ""

    if order.imported?
      if order.update
        summary << "Order #{order.existing_sales_order.external_id} updated on NetSuite # #{order.existing_sales_order.tran_id}"
      else
        error_notification << "Failed to update order #{order.sales_order.external_id} into Netsuite: #{order.errors}"
      end
    else
      if order.create
        summary << "Order #{order.sales_order.external_id} sent to NetSuite # #{order.sales_order.tran_id}"
      else
        error_notification << "Failed to import order #{order.sales_order.external_id} into Netsuite: #{order.errors}"
      end
    end

    if order.paid? && !error_notification.present?
      customer_deposit = NetsuiteIntegration::Services::CustomerDeposit.new(@config, @payload)
      records = customer_deposit.create_records order.sales_order

      errors = records.map(&:errors).compact.flatten
      errors = errors.map(&:message).flatten

      if errors.any?
        error_notification << " Failed to set up Customer Deposit for #{(order.existing_sales_order || order.sales_order).external_id}: #{errors.join(", ")}"
      end

      if customer_deposit.persisted
        summary << ". Customer Deposit set up for Sales Order #{(order.existing_sales_order || order.sales_order).tran_id}"
      end
    end

    if any_payments_void? && !error_notification.present?
      refund = NetsuiteIntegration::Refund.new(@config, @payload, order.existing_sales_order, "void")

      unless refund.service.find_by_external_id(refund.deposits)
        if refund.create
          summary << ". Customer Refund created for #{@payload[:order][:number]}"
        else
          error_notification << "Failed to create a Customer Refund for order #{@payload[:order][:number]}"
        end
      end
    end

    if error_notification.present?
      result 500, error_notification
    else
      result 200, summary
    end
  end

  def customer_record_exists?
    @payload[:order][:payments] && @payload[:order][:payments].any?
  end

  def sales_order_service
    @sales_order_service ||= NetsuiteIntegration::Services::SalesOrder.new(@config)
  end

  def any_payments_void?
    @payload[:order][:payments].any? do |p|
      p[:status] == "void"
    end
  end
end
