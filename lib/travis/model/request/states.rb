require 'active_support/concern'
require 'simple_states'

class Request
  module States
    extend ActiveSupport::Concern

    included do
      include SimpleStates, Branches

      states :created, :started, :finished
      event :start,     :to => :started
      event :configure, :to => :configured, :after => :finish
      event :finish,    :to => :finished

      def approved?
        branch_included?(commit.branch) && !branch_excluded?(commit.branch) && !blacklisted?
      end

      def configure(data)
        update_attributes!(extract_attributes(data))
        create_build! if approved?
      end

      class << self
        def whitelist_rules
          @@whitelist_rules ||= YAML.load_file('whiteblacklist.yml')['whitelist_rules'].map{|r| Regexp.new(r)} rescue []
        end

        def blacklist_rules
          @@blacklist_rules ||= YAML.load_file('whiteblacklist.yml')['blacklist_rules'].map{|r| Regexp.new(r)} rescue []
        end
      end

      protected

        def extract_attributes(attributes)
          attributes.symbolize_keys.slice(*attribute_names.map(&:to_sym))
        end

        def blacklisted?
          # whitelist trumps blacklist
          self.class.whitelist_rules.each do |rule|
            return false if repository.slug =~ rule
          end

          self.class.blacklist_rules.each do |rule|
            return true if repository.slug =~ rule
          end

          return false
        end
    end
  end
end
