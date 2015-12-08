require 'redmine'
require 'application_controller_patch'

Redmine::Plugin.register :redmine_api_auth_fix do
  name 'Api Auth Fix'
  author 'Steve'
  description 'Fixes conditional fail in application controller find_current_user to support http auth autoreg via ldap'
  version '0.0.1'

  Rails.configuration.to_prepare do
    ApplicationController.send(:include, RedmineApiAuthFix::ApplicationControllerPatch)
  end

end