require_relative './cf_migration_client'
require_relative './monitor_helper'
require 'slack-notifier'

include MonitorHelper

$stdout.sync = true

#todo what about security groups

@notifier = Slack::Notifier.new ENV["SLACK_HOOK"],
              channel: "#cloud-gov",
              username: "sandboxbot"

@cf_source_client = CFMigrationClient.new(ENV["SOURCE_CLIENT_ID"],
  ENV["SOURCE_CLIENT_SECRET"],
  ENV["SOURCE_UAA_URL"],
  ENV["SOURCE_CF_API_URL"])

@cf_destination_client = CFMigrationClient.new(ENV["DESTINATION_CLIENT_ID"],
  ENV["DESTINATION_CLIENT_SECRET"],
  ENV["DESTINATION_UAA_URL"],
  ENV["DESTINATION_CF_API_URL"])

@last_user_date = nil

def migrate_org(source_org)

# create a new org quota based on the exising org quota in the source CF instance

  source_quota = @cf_source_client.get_quota_definition(source_org['entity']['quota_definition_guid'])
  destination_quota = @cf_destination_client.get_quota_definition_by_name(source_quota['entity']['name'])
  if destination_quota == nil
    destination_quota = @cf_destination_client.create_organization_quota_definition(source_quota['entity'])
  end
  destination_org = @cf_destination_client.create_organization(source_org['entity']['name'], destination_quota['metadata']['guid'])

end

def migrate_org_roles(source_org, source_user, destination_org, destination_user)

  #re-create org roles in destination CF instance
  ['auditor', 'manager', 'billing_manager'].each do |role|
    if @cf_source_client.user_has_organization_role?(source_user['metadata']['guid'], source_org['metadata']['guid'], role)
      #todo - check to make sure they don't have role in destination already
      @cf_destination_client.associate_user_role_with_organization(destination_user['metadata']['guid'], destination_org['metadata']['guid'], role)
    end
  end

end

def migrate_org_space(source_space, destination_org)

  space = @cf_destination_client.create_space(source_space['entity']['name'], source_space['entity']['allow_ssh'], destination_org['metadata']['guid'])

end

def migrate_space_roles(source_space, source_user, destination_space, destination_user)

  #re-create org roles in destination CF instance
  ['auditor', 'developer', 'manager'].each do |role|
    if @cf_source_client.user_has_space_role?(source_user['metadata']['guid'], source_space['metadata']['guid'], role)
      #todo - should check to see if they already have role in space first, but cf doesn't seem to care
      # if you associate it twice
      @cf_destination_client.associate_user_role_with_space(destination_user['metadata']['guid'], destination_space['metadata']['guid'], role)
    end
  end

end

def migrate_user_assets(destination_user)
  #find this user in the source CF instance - if not there, skip (nothing to migrate)

  source_user = @cf_source_client.get_user_by_username(destination_user['entity']['username'])
  if source_user == nil
    puts "Could not find user #{destination_user['entity']['username']} in source CF"
    return
  end

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
        migrate_org_space(source_space, destination_org)
      end

      # migrate any space roles for this user
      migrate_space_roles(source_space, source_user, destination_space, destination_user)

    end
  end

end

def migrate_users

  last_user_date = nil

  # check for new users on CF destination instance
  users = @cf_destination_client.get_users
  users.each do |destination_user|

    if last_user_date.nil? || last_user_date < user["metadata"]["created_at"]
      last_user_date = user["metadata"]["created_at"]
    end

    #break out of processing if we already processed this user in previous run
    break if @last_user_date && @last_user_date >= user["metadata"]["created_at"]

    migrate_user_assets(destination_user)

    @last_user_date = last_user_date

  end

end

while true
  puts "Looking for new users"
  migrate_users
  puts @last_user_date
  sleep(ENV["SLEEP_TIMEOUT"].to_i)
end
