# TODO: This entire file can be removed once a pull request to wombat/netsuite is accepted

module NetSuite
	module Records
		class CustomFieldList
			# Only define this method if it is not already defined
			unless NetSuite::Records::CustomFieldList.instance_methods(false).include?(:create_or_update_custom_field)

				# Creates or updates the values of a given custom field (specified by interal id)
				# Takes the internal id as a string or symbol
				# Takes the type as a string
				# Takes the value (string, hash, datetime, time, boolean etc.)
				def create_or_update_custom_field(id,type,value)

					# TODO: Consider typechecking id to make sure it isn't a fixnum
					# or some other value that can't be converted to a symbol
					id_sym = id.to_sym

					if @custom_fields_assoc.include?(id_sym)
						# Custom field already exists, update it
						final_value = value

						if type=="platformCore:SelectCustomFieldRef" # Special case for select lists
							final_value = NetSuite::Records::CustomRecordRef.new({
								internal_id: value.first,
								type_id: value.last
							})
						end

						# Update values of the specified custom field (only the value should change)
						@custom_fields_assoc[id_sym].attributes[:value] = final_value
						@custom_fields_assoc[id_sym] # Return the CustomField object that was updated
					else
						# New custom field
						final_value = value

						if type=="platformCore:SelectCustomFieldRef" # Special case for select lists
							final_value = NetSuite::Records::CustomRecordRef.new({
								internal_id: value.first,
								type_id: value.last
							})
						end

						custom_field = CustomField.new(internal_id: id, value: final_value, type: type)
						custom_fields << custom_field
						@custom_fields_assoc[id_sym] = custom_field # Return the new CustomField Object
					end
				end
			end
		end
	end

	# For debugging bad responses
	# module Actions
	# 	class Update

	# 		def response_errors
 #        if response_hash[:status] && response_hash[:status][:status_detail]
 #          @response_errors ||= errors
 #        end
 #      end

 #      def errors
 #        error_obj = response_hash[:status][:status_detail]
 #        error_obj = [error_obj] if error_obj.class == Hash
 #        error_obj.map do |error|
 #          NetSuite::Error.new(error)
 #        end
 #      end

	# 		module Support
	# 			def update(options={})
	# 				puts "Called update method"
	# 				options.merge!(:internal_id => internal_id) if respond_to?(:internal_id) && internal_id
 #          options.merge!(:external_id => external_id) if respond_to?(:external_id) && external_id
 #          puts options.inspect
 #          puts self.class
 #          response = NetSuite::Actions::Update.call(self.class, options)
 #          @errors = response.errors
 #          puts @errors
 #          response.success?
 #        end
 #      end
 #    end
 #  end
end

# Search.request_body method cannot build an appropriate hash for all object types (e.g. PromotionCode)
# This patch allows skipping that method and allow passing a custom formatted message hash directly to Savon
module NetSuite
	module Actions
		class Search

			def request
				# https://system.netsuite.com/help/helpcenter/en_US/Output/Help/SuiteCloudCustomizationScriptingWebServices/SuiteTalkWebServices/SettingSearchPreferences.html
        # https://webservices.netsuite.com/xsd/platform/v2012_2_0/messages.xsd

        preferences = NetSuite::Configuration.auth_header
        preferences = preferences.merge(
          (@options[:preferences] || {}).inject({'platformMsgs:SearchPreferences' => {}}) do |h, (k, v)|
            h['platformMsgs:SearchPreferences'][k.to_s.lower_camelcase] = v
            h
          end
        )


        NetSuite::Configuration
          .connection(soap_header: preferences)
          .call((@options.has_key?(:search_id)? :search_more_with_id : :search), # Decide on method
          	:message => (@options.has_key?(:message)? @options[:message] : request_body)) # Decide on body
      end
    end
  end
end

# Add PromotionCode object so we can handle adding promotion codes to NetSuite
module NetSuite
	module Records
		class PromotionCode
			include Support::Fields
			include Support::Records
			include Support::Actions

			actions :initialize, :search

			fields :code, :description, :name, :rate, :startDate, :endDate

			attr_reader :internal_id
      attr_accessor :external_id
      attr_accessor :search_joins

      def initialize(attributes = {})
        @internal_id = attributes.delete(:internal_id) || attributes.delete(:@internal_id)
        @external_id = attributes.delete(:external_id) || attributes.delete(:@external_id)
        initialize_from_attributes_hash(attributes)
      end

      def record_namespace
      	"platformCommon"
      end

		end
	end
end



