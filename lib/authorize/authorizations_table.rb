require File.dirname(__FILE__) + '/identity'

module Authorize
  module AuthorizationsTable

    module TrusteeExtensions
      def self.included(recipient)
        recipient.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_trustee(key = :authorization_token)
          if key
            unless respond_to?(:find_by_authorization_token)
              define_method(:find_by_authorization_token) do |token|
                finder = "find_by_#{key}".to_sym
                send(finder, token)
              end
            end
            define_method(:permissions) do
              token = send(key)
              Authorization.with(token).scoped(:conditions => {:trustee_type => self.class.base_class.name})
            end
            before_destroy do |trustee|
              trustee.permissions.delete_all
            end
            class_eval do
              alias :authorizations :permissions 
            end
          end
          include Authorize::AuthorizationsTable::TrusteeExtensions::InstanceMethods
          include Authorize::Identity::TrusteeExtensions::InstanceMethods   # Provides all kinds of dynamic sugar via method_missing
        end
      end

      module InstanceMethods
        def authorized?(role, subject = nil)
          !!permissions.as(role).for(subject).any?
        end

        def authorize(role, subject = nil, parent = nil)
          unless auth = permissions.as(role).for(subject).first
            attrs = respond_to?(:parent) ? {:parent => parent} : {} # Support tree-structured authorizations.
            auth = permissions.as(role).for(subject).create(attrs)
            Authorization.logger.debug "#{self} authorized as #{role} over #{subject} (derived from #{parent})"
          end
          auth
        end

        def unauthorize(role, subject = nil)
          permissions.as(role).for(subject).delete_all
        end
      end 
    end

    module SubjectExtensions
      ConditionClause = "a.subject_type IS NULL OR (a.subject_type = %s AND (a.subject_id = %s.%s OR a.subject_id IS NULL))"

      def self.included(recipient)
        recipient.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_subject
          has_many :subjections, :as => :subject, :class_name => 'Authorization', :dependent => :delete_all
          include Authorize::AuthorizationsTable::SubjectExtensions::InstanceMethods
          include Authorize::Identity::SubjectExtensions::InstanceMethods   # Provides all kinds of dynamic sugar via method_missing
          extend Authorize::AuthorizationsTable::SubjectExtensions::SingletonMethods
          subject_condition_clause = ConditionClause % [connection.quote(base_class.name), table_name, primary_key]
          named_scope :authorized, lambda {|tokens, roles|
            scope = Authorization.scoped(:conditions => subject_condition_clause).with(tokens)
            scope = scope.as(roles) if roles
            c = scope.construct_finder_sql({:select => 1, :from => 'authorizations a'}).gsub('"authorizations"', 'a')
            {:conditions => "EXISTS (%s)" % c}
          }
        end
      end

      module SingletonMethods
        def subjected?(role, trustee)
          trustee.authorized?(role, self)
        end

        def subject(role, trustee, parent = nil)
          trustee.authorize(role, self, parent)
        end

        def unsubject(role, trustee)
          trustee.unauthorize(role, self)
        end

        def subjections
          Authorization.for(self)
        end
      end

      module InstanceMethods
        def subjected?(role, trustee)
          trustee.authorized?(role, self)
        end

        def subject(role, trustee, parent = nil)
          trustee.authorize(role, self, parent)
        end

        def unsubject(role, trustee)
          trustee.unauthorize(role, self)
        end
      end    
    end
  end
end