$:.unshift File.dirname(__FILE__)

require 'netsuite'

require 'netsuite_integration/netsuite_extension'

require 'netsuite_integration/services/base'
require 'netsuite_integration/services/inventory_item'
require 'netsuite_integration/services/customer'
require 'netsuite_integration/services/non_inventory_item_service'
require 'netsuite_integration/services/sales_order'
require 'netsuite_integration/services/customer_deposit'
require 'netsuite_integration/services/customer_refund'
require 'netsuite_integration/services/country_service'
require 'netsuite_integration/services/state_service'
require 'netsuite_integration/services/item_fulfillment'

require 'netsuite_integration/base'
require 'netsuite_integration/customer_importer'
require 'netsuite_integration/product'
require 'netsuite_integration/order'
require 'netsuite_integration/inventory_stock'
require 'netsuite_integration/shipment'
require 'netsuite_integration/refund'
