module NetsuiteIntegration
  module Services
    class Customer < Base
      attr_reader :customer_instance

      def find_by_external_id(email)
        NetSuite::Records::Customer.get(external_id: email)

      # Search on the customer email field if finding a customer record by
      # external_id returns the NetSuite::RecordNotFound exception
      rescue NetSuite::RecordNotFound
        NetSuite::Records::Customer.search({
          basic: [
            {
              field: 'email',
              operator: 'is',
              value: email
            }
          ]
        }).results.first
      end

      # entity_id -> Customer name
      def create(payload)
        @customer_instance = customer = NetSuite::Records::Customer.new
        customer.email       = payload[:email]
        customer.external_id = payload[:email]

        # Change from :shipping_address to :billing_address
        if payload[:billing_address]
          customer.first_name  = payload[:billing_address][:firstname] || 'N/A'
          customer.last_name   = payload[:billing_address][:lastname] || 'N/A'
          customer.phone       = payload[:billing_address][:phone]
          fill_address(customer, payload[:billing_address])
        else
          customer.first_name  = 'N/A'
          customer.last_name   = 'N/A'
        end

        handle_extra_fields customer, payload[:netsuite_customer_fields]

        # Defaults
        customer.is_person   = true
        # I don't think we need to make the customer inactive
        # customer.is_inactive = true

        if customer.add
          customer
        else
          false
        end
      end

      def handle_extra_fields(record, extra_fields)
        if extra_fields && extra_fields.is_a?(Hash)
          extra = {}
          extra_fields.each do |k, v|

            method = "#{k}=".to_sym
            ref_method = if k =~ /_id$/ || k =~ /_ref$/
                           "#{k[0..-4]}=".to_sym
                         end

            if record.respond_to? method
              extra[k.to_sym] = record.send method, v
            elsif ref_method && record.respond_to?(ref_method)
              extra[k[0..-4].to_sym] = record.send ref_method, NetSuite::Records::RecordRef.new(internal_id: v)
            end
          end

          extra
        end || {}
      end

      def update_attributes(customer, attrs)
        attrs.delete :id
        attrs.delete :created_at
        attrs.delete :updated_at

        # Converting string keys to symbol keys
        # Netsuite gem does not like string keys
        attrs = Hash[attrs.map{|(k,v)| [k.to_sym,v]}]

        if customer.update attrs
          customer
        else
          false
        end
      end

      def address_exists?(customer, payload)
        current = address_hash(payload)

        # Will not add another address record if the addressee name, default
        # shipping, or default billing information is different
        existing_addresses(customer).any? do |address|
          address.delete :default_shipping
          address.delete :default_billing
          address.delete :addressee
          current.delete :addressee
          address == current
        end
      end

      def set_or_create_default_address(customer, payload)
        # Forever logic: address is default billing but not the default shipping
        attrs = [ address_hash(payload).update({ default_billing: true, default_shipping: false }) ]

        existing = existing_addresses(customer).map do |a|
          a[:default_shipping] = false
          a[:default_billing] = false
          a
        end

        customer.update addressbook_list: { addressbook: attrs.push(existing).flatten }
      end

      # This method does not appear to be used anywhere
      def add_address(customer, payload)
        return if address_exists?(customer, payload)

        customer.update addressbook_list: {
          addressbook: existing_addresses(customer).push(address_hash(payload))
        }
      end

      private
        def existing_addresses(customer)
          customer.addressbook_list.addressbooks.map do |addr|
            {
              default_shipping: addr.default_shipping,
              default_billing: addr.default_billing,
              addressee: addr.addressee.to_s,
              addr1: addr.addr1.to_s,
              addr2: addr.addr2.to_s,
              zip: addr.zip.to_s,
              city: addr.city.to_s,
              state: addr.state.to_s,
              country: addr.country.to_s,
              phone: addr.phone.to_s.gsub(/([^0-9]*)/, "")
            }
          end
        end

        def fill_address(customer, payload)
          if payload[:address1].present?

            # Forever logic: address is default billing but not the default shipping
            customer.addressbook_list = {
              addressbook: address_hash(payload).update({ default_billing: true, default_shipping: false })
            }
          end
        end

        def address_hash(payload)
          addressee = nil
          if payload[:firstname].present? || payload[:lastname].present?
            addressee = payload[:firstname] + " " + payload[:lastname]
            addressee.rstrip.lstrip
          end
          hash = {
            addr1: payload[:address1],
            addr2: payload[:address2],
            zip: payload[:zipcode],
            city: payload[:city],
            state: StateService.by_state_name(payload[:state]),
            country: CountryService.by_iso_country(payload[:country]),
            phone: payload[:phone].to_s.gsub(/([^0-9]*)/, "")
          }
          hash[:addressee] = addressee if !addressee.blank?
          hash
        end
    end
  end
end
