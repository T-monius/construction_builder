# construcion_builder.rb

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'
# require 'pry'

class Word
  attr_accessor :word, :type, :forms, :translation,
                :provisional_translation

  def initialize(word, type, forms={}, translation='')
    self.word = word
    self.type = type
    self.forms = forms
    self.translation = translation
    dictionary_form
  end

  def dictionary_form
    forms[:dictionary] = word
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def vocab_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data/vocab", __FILE__)
  else
    File.expand_path("../data/vocab", __FILE__)
  end
end

def main_env_vocab_path
  File.expand_path('../data/vocab', __FILE__)
end

def main_env_data_path
  File.expand_path("../data", __FILE__)
end

def content_from_main_program_file(filename)
  file = File.join(main_env_data_path, filename)
  File.read(file)
end

def main_env_config_path
  File.expand_path("../config", __FILE__)
end

def load_vocab_lists
  pattern = File.join(vocab_path, '*')
  Dir[pattern].map do |file|
    read_file = File.read(file)
    YAML.load(read_file)
  end  
end

def load_list(id)
  lists = load_vocab_lists
  lists.find { |list| list[:id] == id }
end

def word_from_list(id, word)
  list = load_list(id)
  list[:vocab].find do |word_object|
    word_object.word == word
  end
end

def encrypt(password)
  BCrypt::Password.create(password)
end

def valid?(password, encrypted_password)
  BCrypt::Password.new(encrypted_password) == password
end

def signed_in?
  session[:signed_in]
end

def users_hash
  user_filepath = File.join(data_path, 'users.yml')
  user_file = File.read(user_filepath)
  YAML.load(user_file)  
end

def authentic_credentials?(username, password)
  users = users_hash
  usernames = users[:passwords].keys.map(&:to_s)
  if usernames.include?(username)
    encrypted_password = users[:passwords][username.to_sym]
    valid?(password, encrypted_password)
  else
    false
  end
end

def user_type(username)
  users = users_hash
  return 'editor' if users[:editors].include?(username)
  return 'owner' if users[:owners].include?(username)
  'unknown'
end

def reroute(url, message)
  session[:message] = message
  redirect url
end

# route to view the index/ available lists
get '/' do
  @sample = load_list('001')
  @sample_word = @sample[:vocab][0].word
  @sample_word1 = @sample[:vocab][1].word

  erb :index
end

# Render the sign in page
get '/sign_in' do
  erb :sign_in
end

# Submit the sign in credentials
post '/sign_in' do
  password = params[:password]
  @username = params[:username]

  if authentic_credentials?(@username, password)
    session[:message] = "Welcome #{@username}!"
    session[:signed_in] = true
    session[:username] = @username
    session[:user_type] = user_type(@username)
    redirect '/'
  else
    session[:message] = 'Must provide valid credentials.'
    erb :sign_in
  end
end

post '/sign_out' do
  session.delete(session[:username])
  session.delete(session[:user_type])
  session[:signed_in] = false
  session[:message] = 'You are signed out.'
  redirect '/'
end

# Display all of the Words in a List
get '/vocab/:id' do
  @list = load_list(params[:id])

  erb :vocab_list
end

# Route to view a particular word
get '/vocab/:id/:word' do
  @list = load_list(params[:id])

  @word_object = @list[:vocab].find do |word_object|
    word_object.word == params[:word]
  end

  erb :word
end

# Show the translation of a word
post '/vocab/:id/:word/translation' do
  id = params[:id]
  @list = load_list(id)
  @word_object = word_from_list(id, params[:word])

  unless @word_object.translation.empty?
    session[:see_translation] = true
    redirect "/vocab/#{@list[:id]}/#{@word_object.word}"
  else
    session[:message] = 'Sorry, there is no translation available'
    status 422
    erb :word
  end
end

# *** Probably make a method that takes a block in order to
#     DRY up this route, the following, and any other like
#     them                                                 ***
# Add a new translation for a particular word
post '/vocab/:id/:word/add_translation' do
  id = params[:id]
  word = params[:word]
  reroute("/vocab/#{id}/#{word}", 'Sign in to do that') unless signed_in?
  new_translation = params[:new_translation]
  reroute("/vocab/#{id}/#{word}", 'You must provide a translation') if new_translation.empty?

  @list = load_list(id)
  @word_object = word_from_list(id, word)

  @word_object.translation = new_translation

  filepath = File.join(vocab_path, "list#{id}.yml")
  File.open(filepath, 'w') do |f|
    YAML.dump(@list, f)
  end

  redirect "/vocab/#{@list[:id]}/#{@word_object.word}"
end

# route to delete a word from the list
post '/vocab/:id/:word/delete' do
  id = params[:id]
  word = params[:word]
  unless signed_in? || session[:user_type] == 'owner'
    reroute("/vocab/#{id}/#{word}", 'Sign in to do that')
  end
  list = load_list(id)
  idx = list[:vocab].find_index do |word_object|
    word_object.word == word
  end
  list[:vocab].delete_at(idx)

  filepath = File.join(vocab_path, "list#{id}.yml")
  File.open(filepath, 'w') do |f|
    YAML.dump(list, f)
  end

  session[:message] = "The word '#{word}' was deleted."
  redirect "/vocab/#{list[:id]}"
end

# route to add a word to the list


# route to add a new word form

# route to delete a word form

# Route to sign in
