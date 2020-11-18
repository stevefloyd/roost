# frozen_string_literal: true

require 'sinatra/contrib'
require_relative 'server'

require 'ap'

Dir.glob("#{__dir__}/../commands/**/*.rb").sort.each { |f| require f }

##
# The webserver. Sinatra HTML only server. Serves HTML and digests FORM-encoded
# requests
class WebServer < Server
  use Rack::MethodOverride

  helpers Sinatra::ContentFor

  enable :sessions

  error UnprocessableEntity do |error|
    body render_error(error.message)
    status 422
  end

  error BadRequest do |error|
    ## TODO: find out how to re-render a form with errors instead
    body render_error(error.message)
    status 400
  end

  get '/' do
    erb :home
  end

  get '/register' do
    erb :register
  end

  post '/register' do
    command = Commands::Registration::NewRegistration::Command.new(
      registration_params
    )
    Commands::Registration::NewRegistration::CommandHandler.new(
      command: command
    ).handle

    redirect '/register/success'
  rescue Aggregates::Registration::EmailAlreadySentError
    render_error(
      'Emailaddress is already registered. Do you want to login instead?'
    )
  end

  get '/register/success' do
    erb :register_success
  end

  get '/confirmation/:aggregate_id' do
    command = Commands::Registration::Confirm::Command.new(
      aggregate_id: params[:aggregate_id]
    )
    Commands::Registration::Confirm::CommandHandler.new(
      command: command
    ).handle

    erb :confirmation_success
  rescue Aggregates::Registration::AlreadyConfirmedError
    render_error(
      'Could not confirm. Maybe the link in the email expired, or was'\
      ' already used?'
    )
  end

  get '/login' do
    erb :login
  end

  post '/login' do
    command = Commands::Session::Start::Command.new(login_params)
    Commands::Session::Start::CommandHandler.new(command: command).handle
    erb :confirmation_success
    redirect '/contacts'
  end

  get '/contacts' do
    erb :contacts
  end

  private

  def registration_params
    params.slice('username', 'password', 'email')
  end

  def login_params
    params.slice('username', 'password')
  end

  def render_error(message)
    erb(:error, locals: { message: message })
  end

  def current_member
    OpenStruct.new(super)
  end

  def member_id
    session[:member_id]
  end
end
