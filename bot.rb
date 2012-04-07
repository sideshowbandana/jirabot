require 'rubygems'
require 'summer'
require 'jira4r'
require 'multi_json'
require 'commit2jira'

class String
  BOLD = "\x02"
  COLOR = "\x03"

  def bold
    return BOLD + self + BOLD
  end

  def color(code)
    return COLOR + code.to_i.to_s + self + COLOR
  end
end

class Bot < Summer::Connection

  STATUS_COLORS = {
    'NEW' => 10, # Fuschia
    'ABANDONED' => 4, # Red
    'MERGED' => 9, # Green
    'SUBMITTED' => 8, # Yellow
  }


  attr_reader :data

  def initialize(*args)
    load_yml
    jira_login
    super(*args)
  end

  def prefixes
    @prefixes ||= begin
                    data['jira']['projects'] + ['cr']
                  end
  end

  def load_yml
    @data = YAML.load(File.open('config/bot.yml'))
  end

  def jira_login
    @jira = Jira4R::JiraTool.new(2, data['jira']['url'])
    # Disable jira4r logging
    #@jira.logger = Logger.new(nil)
    @jira.login(data['jira']['username'], data['jira']['password'])
  end

  def respond_gerrit(channel, ticket)
    url = "#{data['gerrit']['url']}/#{ticket}"

    begin
      ssh = IO.popen("ssh #{data['gerrit']['ssh_host']} gerrit query --format=JSON change:#{ticket}")
      data = ssh.readlines.first
      ssh.close

      json = MultiJson.decode(data)
      if json['type'] == 'stats'
        return if json['rowCount'].zero?
      else
        status = json['status'].color(STATUS_COLORS[json['status']])
        extra = "#{json['project'].bold}/#{json['branch'].bold}: #{json['subject']} [#{status}]"
        url = json.fetch('url', url)
      end
    rescue
      puts "respond_gerrit exception: #{$!.inspect}"
    end

    response("PRIVMSG #{channel} Gerrit: #{url} #{extra}")
  end

  def channel_message(sender, channel,  message)
    return if sender['nick'] == 'jenkins'

    Commit2Jira.from_message(prefixes, message) do |category, ticket|
      if category == 'CR'
        respond_gerrit(channel, ticket)
      else
        extra = nil
        begin
          issue = @jira.getIssue("#{category}-#{ticket}")
          assignee = issue.assignee
          assignee = 'unassigned' if assignee.nil?
          extra = "Assigned: ".bold + assignee + " Summary: ".bold + issue.summary
        rescue SOAP::FaultError => error
          if error.message.include?('RemotePermissionException')
            puts "jira.getIssue doesn't exist: #{$!.inspect}"
            next
          elsif error.message.include?("RemoteAuthenticationException")
            jira_login
            retry
          else
            puts "jira.getIssue exception: #{$!.inspect}"
          end
        end

        response("PRIVMSG #{channel} JIRA: #{data['jira']['url']}/browse/#{category}-#{ticket} #{extra}")
      end
    end
  end
end

host = ARGV.first
if host.nil? || host.empty?
  puts 'Please pass the hostname as the first argument'
  exit 1
end
Bot.new host
