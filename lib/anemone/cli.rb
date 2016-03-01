module Anemone
  module CLI
    COMMANDS = %w[count cron mobile pagedepth serialize url-list]
    
    def self.run
      command = ARGV.shift
      
      if COMMANDS.include? command
        load "anemone/cli/#{command.tr('-', '_')}.rb"
      else
        puts <<-INFO
Anemone is a web spider framework that can collect
useful information about pages it visits.

Usage:
  anemone <command> [arguments]

Commands:
  #{COMMANDS.join(', ')}
INFO
      end
    end
  end
end