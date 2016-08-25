require_relative '../monitor_helper'
require 'spec_helper'

describe MonitorHelper do

	let(:monitor_helper_test) { Class.new { extend MonitorHelper} }

	it "should check if org is a sandbox org" do

		expect(monitor_helper_test.is_exempted_org?('sandbox-gsa.gov')).to be true
		expect(monitor_helper_test.is_exempted_org?('cf')).to be true

	end


end
