require 'irc_client'

module Travis
  module Notifications
    class Irc
      EVENTS = 'build:finished'

      def notify(event, build, *args)
        send_irc_notifications(build) if build.send_irc_notifications?
      end

      protected
        def send_irc_notifications(build)
          # Notifications to the same host are grouped so that they can be sent with a single connection
          build.irc_channels.each do |server, channels|
            host, port = *server
            send_notifications(host, port, channels, build)
          end
        end

        def send_notifications(host, port, channels, build)
          commit = build.commit
          build_url = self.build_url(build)

          irc(host, nick, :port => port) do |irc|
            channels.each do |channel|
              join(channel)
              say "[travis-ci] #{build.repository.slug}##{build.number} (#{commit.branch} - #{commit.commit[0, 7]} : #{commit.author_name}): #{build.human_status_message}"
              say "[travis-ci] Change view : #{commit.compare_url}"
              say "[travis-ci] Build details : #{build_url}"
              leave
            end
          end
        end

        def irc(host, nick, options, &block)
          IrcClient.new(host, nick, options).tap do |irc|
            irc.run(&block) if block_given?
            irc.quit
          end
        end

        def nick
          Travis.config.irc.try(:nick) || 'travis-ci'
        end

        def build_url(build)
          [Travis.config.host, build.repository.owner_name, build.repository.name, 'builds', build.id].join('/')
        end
    end
  end
end

