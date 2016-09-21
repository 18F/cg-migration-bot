# cg-migration-botasdfasdfasdfasdfasdf
[![Code Climate](https://codeclimate.com/github/18F/cg-migration-bot/badges/gpa.svg)](https://codeclimate.com/github/18F/cg-migration-bot)

Monitor CF GovCloud controller users and migrate any associates orgs / spaces / roles.

The migration bot monitors the GovCloudUAA (User Account and Authentication) server for new accounts.
If a new account is created, it will look for that user's account in cloud.gov and migrate assets associated with that user.

## Creating UAA client

```shell
uaac client add [your-client-id] \
	--name "UAA Migration Monitor" \
	--scope "cloud_controller.admin, cloud_controller.read, cloud_controller.write, openid, scim.read" \
	--authorized_grant_types "authorization_code, client_credentials, refresh_token" \
	-s [your-client-secret]
```

## Public domain

This project is in the worldwide public domain. As stated in CONTRIBUTING:

> This project is in the public domain within the United States, and copyright
> and related rights in the work worldwide are waived through the CC0 1.0
> Universal public domain dedication.

All contributions to this project will be released under the CC0 dedication. By
submitting a pull request, you are agreeing to comply with this waiver of
copyright interest.
