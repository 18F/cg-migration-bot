module MonitorHelper

	def is_exempted_org?(org_name)

		return org_name.include?("sandbox") || org_name.include?("cf")

	end

	def sanitize_hash(hash, sanitized_keys)

		sanitized_keys.each { |k| hash.delete k }

	end

end
