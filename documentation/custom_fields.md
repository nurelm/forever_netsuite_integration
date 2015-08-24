Support has been added to the Wombat Netsuite integration to handle receiving Sales Orders with data for Custom Transaction Body fields and Promotions (coupon codes).

## Wombat Configuration
The Wombat webhoook "Send new Orders to Netsuite"  should have a configuration parameter called "Custom Body Fields Map" of the "Mappings" type. In the actual POST request, this field will appear under the "parameters" section as "custom_body_fields_map".

Each key value pair of this mapping is used to provide supproting information that is necessary for Netsuite to import custom field data provided by other integrations. The key of each pair should specify the "externalId" of a Custom Transaction Body field in Netsuite. The value of each pair will then specify both the "internalId" and the "type" of the custom field.

A specific type of custom field requires additional key value pairs to supply even more supporting information. Custom fields of the type "platformCore:SelectCustomFieldRef" require 2 additional key value pairs. The key names for these pairs follow the format of "#{externalId}_list_map" and "#{externalId}_list_id". The "_list_id" key's corresponding value must specify the internalId of the Custom List created in Netsuite to specify the values available the Custom Transaction Body Field. The "_list_map" key's corresponding value must supply an exhaustive list of each option in the Custom List. This will follow the format of "ListValueString;;ListValueInternalId||ListValueString2;;ListvalueInteralId2".

### Example Mapping Values
	"custbody_customer_id" => "500;;platformCore:StringCustomFieldRef",

	// These 3 fields are for Custom fields with a Custom select list
	"custbody_payment_option" => "505;;platformCore:SelectCustomFieldRef",
	"custbody_payment_option_list_id" => "72",
	"custbody_payment_option_list_map" => "Subscription;;1||Pay Today;;2"

There is no required configuration for Coupon Codes. However, the Netsuite integration expects the given coupon code to match a single Promotion object's "coupon_code" value in Netsuite. Additionally, the Netsuite integration expects to find the coupon code in a specific location of the "/add_orders" POST request. The updates to the OpenCart integration allow you to specify custom field data (see OpenCart section for details).


### Required Location of Coupon Code in Wombat's request to the Netsuite Integration
	"order": {
		...
		"custom_fields": {
			"netsuite_custbody": {
				"coupon_code": "valuehere"
			}
		}
		...
	}
