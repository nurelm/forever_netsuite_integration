module NetsuiteIntegration
  module Services
    class NonInventoryItemService < Base
      attr_reader :errors

      def find_or_create_by_name(name, extra_fields = {})
        unless item = inventory_item_service.find_by_exact_name(name)
          new_item = NetSuite::Records::NonInventorySaleItem.new(
            item_id: name,
            display_name: name,
            external_id: name
          )

          handle_extra_attributes new_item, extra_fields || {}

          if new_item.add
            # unfortunately, we have to reload the object
            item = inventory_item_service.find_by_exact_name(name)
          else
            @errors = new_item.errors
          end
        end

        item
      end

      def handle_extra_attributes(record, extra_fields)
        extra_fields.each do |k, v|
          method = "#{k}=".to_sym
          ref_method = if k =~ /_id$/ || k =~ /_ref$/
                         "#{k[0..-4]}=".to_sym
                       end

          if record.respond_to? method
            record.send method, v
          elsif ref_method && record.respond_to?(ref_method)
            record.send ref_method, NetSuite::Records::RecordRef.new(internal_id: v)
          end
        end
      end

      def error_messages
        if errors && errors.is_a?(Array)
          errors.map(&:message).join(", ")
        end
      end
    end
  end
end
