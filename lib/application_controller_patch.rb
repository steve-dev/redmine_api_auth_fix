require_dependency 'application_controller'

module RedmineApiAuthFix
  module ApplicationControllerPatch
    def self.included(base)
      base.class_eval do

        # Returns the current user or nil if no user is logged in
        # and starts a session if needed
        def find_current_user_with_api_auth_fix

          user = nil
          unless api_request?
            if session[:user_id]
              # existing session
              user = (User.active.find(session[:user_id]) rescue nil)
            elsif autologin_user = try_to_autologin
              user = autologin_user
            elsif params[:format] == 'atom' && params[:key] && request.get? && accept_rss_auth?
              # RSS key authentication does not start a session
              user = User.find_by_rss_key(params[:key])
            end
          end
          if user.nil? && Setting.rest_api_enabled?
            if (key = api_key_from_request)
              # Use API key
              user = User.find_by_api_key(key)
            elsif request.authorization.to_s =~ /\ABasic /i
              # HTTP Basic, either username/password or API key/random
              authenticate_with_http_basic do |username, password|
                user = User.try_to_login(username, password) || User.find_by_api_key(username)
              end
              if user && user.must_change_password?
                render_error :message => 'You must change your password', :status => 403
                return
              end
            end
            # Switch user if requested by an admin user
            if user && user.admin? && (username = api_switch_user_from_request)
              su = User.find_by_login(username)
              if su && su.active?
                logger.info("  User switched by: #{user.login} (id=#{user.id})") if logger
                user = su
              else
                render_error :message => 'Invalid X-Redmine-Switch-User header', :status => 412
              end
            end
          end
          user
        end

        alias_method_chain :find_current_user, :api_auth_fix

      end
    end
  end
end
