require_relative './cf_migration_client'
require_relative './monitor_helper'

include MonitorHelper

$stdout.sync = true

@cf_source_client = CFMigrationClient.new(ENV["SOURCE_CLIENT_ID"],
  ENV["SOURCE_CLIENT_SECRET"],
  ENV["SOURCE_UAA_URL"],
  ENV["SOURCE_CF_API_URL"])

@cf_destination_client = CFMigrationClient.new(ENV["DESTINATION_CLIENT_ID"],
  ENV["DESTINATION_CLIENT_SECRET"],
  ENV["DESTINATION_UAA_URL"],
  ENV["DESTINATION_CF_API_URL"])

@last_user_date = nil

def message(message)

  puts message

end

def migrate_org(source_org)

# create a new org quota based on the exising org quota in the source CF instance

  source_quota = @cf_source_client.get_quota_definition(source_org['entity']['quota_definition_guid'])
  destination_quota = @cf_destination_client.get_quota_definition_by_name(source_quota['entity']['name'])

  if destination_quota == nil
    message("Creating org quota named #{source_quota['entity']['name']} for org #{source_org['entity']['name']}")
    destination_quota = @cf_destination_client.create_organization_quota_definition(source_quota['entity'])
  end
  message("Creating org #{source_org['entity']['name']}")
  destination_org = @cf_destination_client.create_organization(source_org['entity']['name'], destination_quota['metadata']['guid'])

end

def migrate_org_roles(source_org, source_user, destination_org, destination_user)

  #re-create org roles in destination CF instance
  ['auditor', 'manager', 'billing_manager'].each do |role|
    if @cf_source_client.user_has_organization_role?(source_user['metadata']['guid'], source_org['metadata']['guid'], role)
      #todo - check to make sure they don't have role in destination already
      message("Associating user #{source_user['entity']['username']} with #{role} role in org #{source_org['entity']['name']}")
      @cf_destination_client.associate_user_role_with_organization(destination_user['metadata']['guid'], destination_org['metadata']['guid'], role)
    end
  end

end

def migrate_org_space(source_space, destination_org)

  message("Creating space #{source_space['entity']['name']} in org #{destination_org['entity']['name']}")
  space = @cf_destination_client.create_space(source_space['entity']['name'], source_space['entity']['allow_ssh'], destination_org['metadata']['guid'])


end

def migrate_space_roles(source_space, source_user, destination_space, destination_user, destination_org)

  #re-create org roles in destination CF instance
  ['auditor', 'developer', 'manager'].each do |role|
    if @cf_source_client.user_has_space_role?(source_user['metadata']['guid'], source_space['metadata']['guid'], role)
      #todo - should check to see if they already have role in space first, but cf doesn't seem to care
      # if you associate it twice
      message("Associating user #{source_user['entity']['username']} with #{role} role in space #{destination_space['entity']['name']} in org #{destination_org['entity']['name']} ")
      @cf_destination_client.associate_user_role_with_space(destination_user['metadata']['guid'], destination_space['metadata']['guid'], role)
    end
  end

end

def migrate_user_assets(destination_user)
  #find this user in the source CF instance - if not there, skip (nothing to migrate)

  source_user = @cf_source_client.get_user_by_username(destination_user['entity']['username'])
  if source_user == nil
    message("Could not find user #{destination_user['entity']['username']} in source CF")
    return
  end

  message("Migrating assets for user #{source_user['entity']['username']}")

  # find all the orgs this user belongs to in the source CF instance
  source_orgs = @cf_source_client.get_user_organizations(source_user['metadata']['guid'])

  # check if each organization exists in the destination CF instance - if not, create
  source_orgs.each do |source_org|
    next if is_exempted_org?(source_org['entity']['name'])

    destination_org = @cf_destination_client.get_organization_by_name(source_org['entity']['name'])
    if destination_org == nil
      destination_org = migrate_org(source_org)
    end

    #add user to the existing or newly created org if not there already
    if !@cf_destination_client.user_exists_in_org?(destination_user['metadata']['guid'], destination_org['metadata']['guid'])
        @cf_destination_client.add_user_to_org(destination_user['metadata']['guid'], destination_org['metadata']['guid'])
    end

    # migrate all the existing roles
    migrate_org_roles(source_org, source_user, destination_org, destination_user)

    #get all the spaces for this org in the source CF instance

    source_spaces = @cf_source_client.get_organization_spaces(source_org['metadata']['guid'])

    source_spaces.each do |source_space|
      destination_space = @cf_destination_client.get_organization_space_by_name(destination_org['metadata']['guid'], source_space['entity']['name'])
      if destination_space == nil
        destination_space = migrate_org_space(source_space, destination_org)
      end

      # migrate any space roles for this user
      migrate_space_roles(source_space, source_user, destination_space, destination_user, destination_org)

    end
  end

end

def migrate_users

  last_user_date = nil

  # check for new users on CF destination instance
  users = @cf_destination_client.get_users
  users.each do |destination_user|

    if last_user_date.nil? || last_user_date < destination_user["metadata"]["created_at"]
      last_user_date = destination_user["metadata"]["created_at"]
    end

    #break out of processing if we already processed this user in previous run
    break if @last_user_date && @last_user_date >= destination_user["metadata"]["created_at"]

    migrate_user_assets(destination_user)

    @last_user_date = last_user_date

  end

end

while true
  if @last_user_date
    message("Looking for users added after #{@last_user_date}")
  else
    message("Looking for new users")
  end

  migrate_users
  sleep(ENV["SLEEP_TIMEOUT"].to_i)

end
