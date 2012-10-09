require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module KwAppDistribution
    class Client
      HOSTNAME = 'app-distribution.herokuapp.com'
      #HOSTNAME = 'localhost:3000'
      def initialize(api_token, project_id)
        @api_token, @project_id = api_token, project_id
        @connection = Faraday.new(:url => "http://#{HOSTNAME}") do |builder|
          builder.request :multipart
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options.update({
          :api_token => @api_token,
          :project_id => @project_id,
          :file => Faraday::UploadIO.new(ipa, 'application/octet-stream')
        })

        @connection.post("/api/v1/builds.json", options).on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      end
    end
  end
end

command :'distribute:kw-app-distribution' do |c|
  c.syntax = "ipa distribute:kw-app-distribution [options]"
  c.summary = "Distribute an .ipa file over KW App Distribution"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-a', '--api_token TOKEN', "API Token."
  c.option '-i', '--project_id TOKEN', "Team Token. Available at https://app-distribution.herokuapp.com/projects/"
  c.option '-m', '--notes NOTES', "Release notes for the build"
  c.option '-b', '--build_type BUILD_TYPE', "Build Type (developer or customer)"
  c.option '-x', '--build_version VERSION', "Build Version"

  #c.option '--notify', "Notify permitted teammates to install the build"
  #c.option '--replace', "Replace binary for an existing build if one is found with the same name/bundle version"
  c.option '-q', '--quiet', "Silence warning and success messages"

  if Shenzhen::CONFIG && Shenzhen::CONFIG['distribution'] && Shenzhen::CONFIG['distribution']['kw_app_distribution']
    config = Shenzhen::CONFIG['distribution']['kw_app_distribution']
  else
    config = {}
  end

  c.action do |args, options|
    determine_file! unless @file = options.file || config['file']
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_api_token! unless @api_token = options.api_token || config['api_token']
    say_error "Missing API Token" and abort unless @api_token

    determine_project_id! unless @project_id = options.project_id || config['project_id']
    say_error "Missing project id" and abort unless @project_id

    determine_notes! unless @notes = options.notes
    say_error "Missing release notes" and abort unless @notes

    determine_build_type! unless @build_type = options.build_type || config['build_type']
    say_error "Missing build_type" and abort unless @build_type

    determine_version! unless @version = options.build_version || config['version']
    say_error "Missing version" and abort unless @version

    parameters = {}
    parameters[:file] = @file
    parameters[:description] = @notes
    parameters[:version] = @version
    parameters[:build_type] = @build_type
    #parameters[:notify] = "true" if options.notify
    #parameters[:replace] = "true" if options.replace
    #parameters[:distribution_lists] = options.lists if options.lists

    client = Shenzhen::Plugins::KwAppDistribution::Client.new(@api_token, @project_id)
    response = client.upload_build(@file, parameters)
    case response.status
    when 200...300
      say_ok "Build successfully uploaded to KW App Distribution"
    else
      say_error "Error uploading to Kw App Distribution: #{response.body}"
    end
  end

  private

  def determine_build_type!
    @build_type ||= ask "Build Type (customer|developer):"
  end

  def determine_api_token!
    @api_token ||= ask "API Token:"
  end

  def determine_project_id!
    @project_id ||= ask "Project Token:"
  end

  def determine_version!
    @version ||= ask "Version:"
  end

  def determine_file!
    files = Dir['*.ipa']
    @file ||= case files.length
              when 0 then nil
              when 1 then files.first
              else
                @file = choose "Select an .ipa File:", *files
              end
  end

  def determine_notes!
    placeholder = %{What's new in this release: }
    
    @notes = ask_editor placeholder
    @notes = nil if @notes == placeholder
  end
end
