require 'spec_helper'

module NetsuiteIntegration
  module Services
    describe CustomerDeposit do
      include_examples "config hash"
      include_context "connect to netsuite"

      subject { described_class.new config }

      let(:sales_order) { double("SalesOrder", internal_id: 7279) }
      let(:total) { 20 }
      let(:order_number) { 'R123456789' }

      it "creates customer deposit give sales order id" do
        VCR.use_cassette("customer_deposit/add") do
          expect(subject.create sales_order, total, order_number).to be_true
        end
      end

      it "finds customer deposit given order id" do
        VCR.use_cassette("customer_deposit/find_by_external_id") do
          item = subject.find_by_external_id(order_number)
          expect(item.internal_id).to eq "10498"
        end
      end      
    end
  end
end
