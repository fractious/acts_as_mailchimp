require 'xmlrpc/client'
module Terra
  module Acts #:nodoc:
    module MailChimp #:nodoc:
      class MailChimpConfigError < StandardError; end
      class MailChimpConnectError < StandardError; end

      def self.included(base)
        base.extend ClassMethods
        mattr_reader :monkeybrains
        begin
          @@monkeybrains = YAML.load(File.open("#{RAILS_ROOT}/config/monkeybrains.yml"))[RAILS_ENV].symbolize_keys        
        end
      end

      module ClassMethods
        def acts_as_mailchimp(opts={})
          include Terra::Acts::MailChimp::InstanceMethods
          extend Terra::Acts::MailChimp::SingletonMethods
          write_inheritable_attribute :email_column, opts[:email] || 'email'
          write_inheritable_attribute :type_column, opts[:type] || 'email_type'
          write_inheritable_attribute :fname_column, opts[:fname] || 'first_name'
          write_inheritable_attribute :lname_column, opts[:lname] || 'last_name'
          class_inheritable_reader    :email_column
          class_inheritable_reader    :type_column
          class_inheritable_reader    :fname_column
          class_inheritable_reader    :lname_column
        end
      end

      module SingletonMethods
        # Add class methods here
      end

      module InstanceMethods
        # Add a user to a MailChimp mailing list
        def add_to_mailchimp(list_name, double_opt = false)
          apikey ||= chimpLogin(monkeybrains[:username], monkeybrains[:password])
          list_id ||= find_mailing_list(apikey, list_name)
          vars = {}
          vars.merge!({"FNAME" => self[fname_column]}) if self.has_attribute?(fname_column)
          vars.merge!({"LNAME" => self[lname_column]}) if self.has_attribute?(lname_column)
          chimpSubscribe(apikey, list_id["id"], self[email_column], vars, self.class.type_column, double_opt)
        rescue XMLRPC::FaultException
        end
        
        # Remove a user from a MailChimp mailing list
        def remove_from_mailchimp(list_name)
          apikey ||= chimpLogin(monkeybrains[:username], monkeybrains[:password])
          list_id ||= find_mailing_list(apikey, list_name)
          chimpUnsubscribe(apikey, list_id["id"], self[email_column])
        rescue XMLRPC::FaultException
        end
        
        # Update user information at MailChimp
        def update_mailchimp(list_name, old_email = self[email_column])
          apikey ||= chimpLogin(monkeybrains[:username], monkeybrains[:password])
          list_id ||= find_mailing_list(apikey, list_name)
          vars = {}
          vars.merge!({"FNAME" => self[fname_column]}) if self.has_attribute?(fname_column)
          vars.merge!({"LNAME" => self[lname_column]}) if self.has_attribute?(lname_column)
          vars.merge!({"EMAIL" => self[email_column]})
          chimpUpdate(apikey, list_id["id"], old_email, vars, self[type_column], true)
        rescue XMLRPC::FaultException
        end
        
        # Log in to MailChimp
        def chimpLogin(username, password)
          raise MailChimpConfigError("Please provide a valid username and password") if (username.nil? || password.nil?) 
          chimpAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.1/")
          chimpAPI.call("login", username, password)
        end
        
        # Subscribe the provided email to a list
        def chimpSubscribe(apikey, list_id, email, merge_vars, content_type = 'html', double_opt = true)
          raise_errors(apikey, list_id)
          chimpAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.1/")
          chimpAPI.call("listSubscribe", apikey, list_id, email, merge_vars, content_type, double_opt)
        end
        
        def chimpUnsubscribe(apikey, list_id, email, delete_user = false, send_goodbye = true, send_notify = true)
          raise_errors(apikey, list_id)
          chimpAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.1/")
          chimpAPI.call("listUnsubscribe", apikey, list_id, email, delete_user, send_goodbye, send_notify)
        end
        
        def chimpUpdate(apikey, list_id, email, merge_vars, content_type = 'html', replace_interests = true)
          raise_errors(apikey, list_id)
          chimpAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.1/")
          chimpAPI.call("listUpdateMember", apikey, list_id, email, merge_vars, content_type, replace_interests)
        end
        
        def find_mailing_list(apikey, list_name)
          raise MailChimpConfigError("Please provide a mailing list name") if list_name.nil?
          mailing_lists ||= get_all_mailing_lists(apikey)
          unless mailing_lists.nil?  
            mailing_lists.find { |list| list["name"] == list_name }
          end
        end
        
        def get_all_mailing_lists(apikey)
          raise MailChimpConnectError("Please login to MailChimp and make sure you have a valid API key") if (apikey.nil?) 
          chimpAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.1/")
          chimpAPI.call("lists", apikey)
        end
        
        def raise_errors(apikey, list_id)
          raise MailChimpConnectError("Please login to MailChimp and make sure you have a valid API key") if apikey.nil?
          raise MailChimpConfigError("Please provide a valid mailing list ID") if list_id.nil?
        end
        
      end
    end
  end
end
