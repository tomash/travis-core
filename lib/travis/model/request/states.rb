require 'active_support/concern'
require 'simple_states'

class Request
  module States
    extend ActiveSupport::Concern

    included do
      include SimpleStates, Branches

      BLACKLIST_RULES = [
        /\/rails$/
      ]

      WHITELIST_RULES = [
        /^rails\/rails/
      ]

      states :created, :started, :finished
      event :start,     :to => :started
      event :configure, :to => :configured, :after => :finish
      event :finish,    :to => :finished

      def approved?
        branch_included?(commit.branch) && !branch_excluded?(commit.branch) && !is_blacklisted?
      end

      def configure(data)
        update_attributes!(extract_attributes(data))
        create_build! if approved?
      end

      protected

        def extract_attributes(attributes)
          attributes.symbolize_keys.slice(*attribute_names.map(&:to_sym))
        end

        def is_blacklisted?
          # whitelist trumps blacklist
          WHITELIST_RULES.each do |rule|
            return false if repository.slug =~ rule
          end

          BLACKLIST_RULES.each do |rule|
            return true if repository.slug =~ rule
          end

          return false
        end
    end
  end
end
