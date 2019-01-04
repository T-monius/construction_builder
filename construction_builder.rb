# construcion_builder.rb

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'
# require 'pry'

APPROVED_MARKERS = [:first_person, :second_person, :third_person,
           :plural, :singular, :neuter, :masculine,
           :feminine, :genetive, :imperative, :dative,
           :instrumenal, :accusative, :nominative, :prepositional,
           :vocative, :dictionary, :formal, :informal]

class Word
  attr_accessor :word, :type, :forms, :translation,
                :provisional_translation

  def initialize(word, type,translation='')
    self.word = word
    self.type = type
    self.forms = []
    self.translation = translation
  end
end

class Form
  attr_accessor :form, :markers

  def initialize(form, markers=[])
    self.form = form
    if markers.all? { |marker| APPROVED_MARKERS.include?(marker) }
      self.markers = markers
    else
      self.markers = []
    end
  end

  def add_marker(marker)
    self.markers << marker if APPROVED_MARKERS.include?(marker)
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

def content_from_main_data_path(filename)
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
  load_vocab_lists.find { |list| list[:id] == id }
end

def word_from_list(word, list)
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

def redirect_unless_owner(url)
  unless signed_in? && session[:user_type] == 'owner'
    reroute(url, 'Sign in as owner to do that')
  end
end

def modify_list(list)
  yield(list) if block_given?

  filepath = File.join(vocab_path, "list#{list[:id]}.yml")
  File.open(filepath, 'w') do |f|
    YAML.dump(list, f)
  end
end

def unique_word?(list, word)
  list[:vocab].any? { |word_object| word_object.word == word }
end

# route to view the index/ available lists
get '/' do
  @sample = load_list('001')
  list = @sample[:vocab]
  @word, @word1 = @sample[:vocab][0..1].map(&:word) unless list.empty?
  @word, @word1 = ['..', '..'] if list.empty?

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
    status 422
    erb :sign_in
  end
end

post '/sign_out' do
  session.delete(:username)
  session.delete(:user_type)
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
  pass if params[:word] == 'add_word'
  id = params[:id]
  @list = load_list(params[:id])

  @word_object = word_from_list(params[:word], @list)

  erb :word
end

# Show the translation of a word
post '/vocab/:id/:word/translation' do
  id = params[:id]
  @list = load_list(id)
  @word_object = word_from_list(params[:word], @list)

  unless @word_object.translation.empty?
    session[:see_translation] = true
    redirect "/vocab/#{@list[:id]}/#{@word_object.word}"
  else
    session[:message] = 'Sorry, there is no translation available'
    status 422
    erb :word
  end
end

# route to add a word to the list
get '/vocab/:id/add_word' do
  @id = params[:id]
  redirect_unless_owner("/vocab/#{@id}")

  erb :new_word
end

post '/vocab/:id/add_word' do
  id = params[:id]
  redirect_unless_owner("/vocab/#{id}")
  word = params[:word]
  @list = load_list(id)
  unless unique_word?(@list, word)
    session[:message]= 'Sorry, that word is already in the list'
    status 422
    erb :vocab_list
  end
  word_object = Word.new(word, params[:word_type])

  modify_list(@list) do |list|
    list[:vocab] << word_object
  end
  
  erb :vocab_list
end


# *** Probably make a method that takes a block in order to
#     DRY up this route, the following, and any other like
#     them                                                 ***
# Add a new translation for a particular word
post '/vocab/:id/:word/add_translation' do
  id = params[:id]
  word = params[:word]
  redirect_unless_owner("/vocab/#{id}/#{word}")
  new_translation = params[:new_translation]
  reroute("/vocab/#{id}/#{word}", 'You must provide a translation') if new_translation.empty?

  @list = load_list(id)
  @word_object = word_from_list(word, @list)

  @word_object.translation = new_translation

  filepath = File.join(vocab_path, "list#{id}.yml")
  File.open(filepath, 'w') do |f|
    YAML.dump(@list, f)
  end

  redirect "/vocab/#{id}/#{word}"
end

# route to delete a word from the list
post '/vocab/:id/:word/delete' do
  id = params[:id]
  word = params[:word]
  redirect_unless_owner("/vocab/#{id}/#{word}")

  list = load_list(id)
  modify_list(list) do |list|
    word_object = list[:vocab].find do |word_object|
      word_object.word == word
    end
    list[:vocab].delete(word_object)
  end

  session[:message] = "The word '#{word}' was deleted."
  redirect "/vocab/#{id}"
end

# Render the form for adding a new form of a word
get '/vocab/:id/:word/add_word_form' do
  @id = params[:id]
  @word = params[:word]

  erb :add_word_form
end

def array_of_markers(markers_string)
  markers_string.scan(/[\w_]+/).map(&:to_sym).select do |marker|
    APPROVED_MARKERS.include?(marker)
  end
end

# route to add a new word form
post '/vocab/:id/:word/add_word_form' do
  id = params[:id]
  word = params[:word]
  redirect_unless_owner("/vocab/#{id}/#{word}")

  markers = array_of_markers(params[:markers])
  form = Form.new(params[:word_form], markers)

  list = load_list(id)
  modify_list(list) do |list|
    word_object = list[:vocab].find do |word_object|
      word_object.word == word
    end
    word_object.forms << form
  end

  session[:message] = 'New word form has been added'
  redirect "/vocab/#{id}/#{word}"
end

# route to delete a word form
post '/vocab/:id/:word/delete_word_form/:form' do
  id = params[:id]
  word = params[:word]
  word_form = params[:form]
  redirect_unless_owner("/vocab/#{id}/#{word}")

  list = load_list(id)
  modify_list(list) do |list|
    word_object = list[:vocab].find do |word_object|
      word_object.word == word
    end

    form = word_object.forms.find do |form|
      form.form == word_form
    end

    word_object.forms.delete(form)
  end

  session[:message] = "The form #{word_form} was deleted"
  redirect "/vocab/#{id}/#{word}"
end

# Route to sign in
