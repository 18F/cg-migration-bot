#!/usr/bin/env ruby
require 'rubygems'
require 'oauth2'

class CFMigrationClient

  @cf_api_domain = nil

	def initialize(client_id, client_secret, uaa_url, cf_api_domain)

    @client = OAuth2::Client.new(
      client_id,
      client_secret,
      :site => uaa_url)

		@token = @client.client_credentials.get_token;
    @cf_api_domain = cf_api_domain

	end

  def api_url

    return "https://api.#{@cf_api_domain}/v2"

  end

  def get_user_organizations(user_guid)

    response = @token.get("#{api_url}/users/#{user_guid}/organizations")
    orgs = response.parsed['resources']

  end

  def get_organization_by_name(org_name)

    org = nil

    response = @token.get("#{api_url}/organizations?q=name:#{org_name}")
    if response.parsed["total_results"] == 1
      org = response.parsed['resources'][0]
    end

    return org

  end

  def get_organization_spaces(org_guid)

    response = @token.get("#{api_url}/organizations/#{org_guid}/spaces")
    return response.parsed['resources']

  end

  def get_organization_space_by_name(org_guid, name)

    #todo - do we need to worry about paging?
    space = nil
    response = @token.get("#{api_url}/organizations/#{org_guid}/spaces")
    response.parsed['resources'].each do |org_space|
      if org_space['entity']['name'] = name
        space = org_space
        break
      end
    end

    return space

  end

  def get_organization_quota_by_name(org_name)

    quota = nil

    response = @token.get("#{api_url}/quota_definitions?q=name:#{org_name}")
    if response.parsed["total_results"] == 1
      quota = response.parsed['resources'][0]
    end

    return quota

  end

  def create_organization_quota_definition(quota_definition)

    response = @token.post("#{api_url}/quota_definitions", body: quota_definition.to_json)
    quota_definition = response.parsed

  end

  def delete_organization_quota_definition(quota_definition_guid)

    response = @token.delete("#{api_url}/quota_definitions/#{quota_definition_guid}")

  end

  def get_organization_roles(org_guid)

    response = @token.get("#{api_url}/organizations/#{org_guid}/user_roles")
    roles = response.parsed['resources']

  end

  def get_users

    #todo - do we need to worry about paging?
    response = @token.get("#{api_url}/users?order-direction=asc")
    users = response.parsed["resources"];

  end

  def get_user_by_username(username)

    result = nil
    page = 1
    results_per_page = 100
    more_results = true

    while result == nil && more_results
      response = @token.get("#{api_url}/users?results-per-page=#{results_per_page}&page=#{page}")
      if !response.parsed['next_url']
        more_results = false
      end

      response.parsed['resources'].each do |user|
        if user['entity']['username'] == username
          result = user
          break
        end
      end

      page += 1

    end

    result

  end

  def user_has_organization_role?(user_guid, org_guid, role)

    result = false
    page = 1
    results_per_page = 100
    more_results = true

    while result == false && more_results
      response = @token.get("#{api_url}/organizations/#{org_guid}/#{role}s?results-per-page=#{results_per_page}&page=#{page}")
      if !response.parsed['next_url']
        more_results = false
      end

      response.parsed['resources'].each do |user|
        if user['metadata']['guid'] == user_guid
          result = true
          break
        end
      end

      page += 1

    end

    result

  end

  def associate_user_role_with_organization(user_guid, org_guid, role)

    @token.put("#{api_url}/organizations/#{org_guid}/#{role}s/#{user_guid}")

  end

  def user_has_space_role?(user_guid, space_guid, role)

    result = false
    page = 1
    results_per_page = 100
    more_results = true

    while result == false && more_results
      response = @token.get("#{api_url}/spaces/#{space_guid}/#{role}s?results-per-page=#{results_per_page}&page=#{page}")
      if !response.parsed['next_url']
        more_results = false
      end

      response.parsed['resources'].each do |user|
        if user['metadata']['guid'] == user_guid
          result = true
          break
        end
      end

      page += 1

    end

    result

  end

  def associate_user_role_with_space(user_guid, space_guid, role)

    @token.put("#{api_url}/spaces/#{space_guid}/#{role}s/#{user_guid}")

  end

  def user_exists_in_org?(user_guid, org_guid)

    result = false

    response = @token.get("#{api_url}/users/#{user_guid}/organizations")
    response.parsed['resources'].each do |organization|
      if organization['metadata']['guid'] == org_guid
        result = true
        break
      end
    end

    result

  end

  def add_user_to_org(user_guid, org_guid)

    # Add user to org
    @token.put("#{api_url}/organizations/#{org_guid}/users/#{user_guid}")

  end


  def create_organization(org_name, quota_definition_guid)

    req = {
      name: org_name,
      quota_definition_guid: quota_definition_guid
    }

    response = @token.post("#{api_url}/organizations", body: req.to_json)
    org = response.parsed

  end

  def create_space(name, allow_ssh, organization_guid )

    req = {
      name: name,
      organization_guid: organization_guid,
      allow_ssh: allow_ssh,
    }

    sr = @token.post("#{api_url}/spaces",
        body: req.to_json)

  end

  def get_quota_definition(quota_definition_guid)

    response = @token.get("#{api_url}/quota_definitions/#{quota_definition_guid}")
    quota = response.parsed

  end

  def get_quota_definition_by_name(quota_definition_name)

    result = false
    page = 1
    results_per_page = 100
    more_results = true

    while result == false && more_results
      response = @token.get("#{api_url}/quota_definitions?results-per-page=#{results_per_page}&page=#{page}")
      if !response.parsed['next_url']
        more_results = false
      end

      response.parsed['resources'].each do |quota_definition|
        if quota_definition['entity']['name'] == quota_definition_name
          result = quota_definition
          break
        end
      end

      page += 1

    end

    result

  end

end
