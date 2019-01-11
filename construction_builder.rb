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
                :provisional_translation, :form_queue

  def initialize(word, type,translation='')
    self.word = word
    self.type = type
    self.forms = []
    self.translation = translation
    self.form_queue = []
  end

  def to_s
    word
  end
end

class Form
  attr_accessor :markers
  attr_writer :form

  def initialize(form, markers=[])
    self.form = form if form.is_a?(String)
    if markers.all? { |marker| APPROVED_MARKERS.include?(marker) }
      self.markers = markers
    else
      self.markers = []
    end
  end

  def add_marker(marker)
    self.markers << marker if APPROVED_MARKERS.include?(marker)
  end

  def to_s
    @form
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def current_editors
    users_hash[:editors]
  end

  def user_lists(username)
    load_vocab_lists.select do |list|
      list[:owner] == username ||
      list[:editors].include?(username)
    end
  end
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

def next_word_in_list(current_word, list)
  current_index = list[:vocab].find_index do |word|
    word.to_s == current_word
  end
  if current_index == list[:vocab].length - 1
    return list[:vocab][0].to_s
  end
  list[:vocab][current_index + 1].to_s
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

def modify_users
  users = users_hash
  yield(users) if block_given?

  filepath = File.join(data_path, 'users.yml')
  File.open(filepath, 'w') do |f|
    YAML.dump(users, f)
  end
  nil
end

def reroute(url, message)
  session[:message] = message
  redirect url
end

def list_owner?(list)
  session[:user_type] == 'owner' && list[:owner] == session[:username]
end

def redirect_unless_owner(url, list)
  unless signed_in? && list_owner?(list)
    reroute(url, 'Sign in as owner to do that')
  end
end

def list_editor?(list)
  session[:user_type] == 'editor' && list[:editors].include?(session[:username])
end

def redirect_unless_owner_or_editor(url, list)
  unless signed_in? && list_owner?(list) || list_editor?(list)
    reroute(url, 'Sign in as owner or editor to do that')
  end
end

def valid_username?(username)
  users = users_hash
  !username.empty? && username.is_a?(String) &&
  !users[:owners].include?(username) && !users[:editors].include?(username)
end

def redirect_if_bad_username(username)
  unless valid_username?(username)
    reroute('/new_user', 'Provide a unique username')
  end
end

def valid_password?(password)
  return false if password.length < 6
  return false if password.downcase.count('^a-z') < 1
  return false if password.count('A-Z') < 1
  true
end

def redirect_if_bad_password(password)
  unless valid_password?(password)
    reroute('/new_user', 'The password must be at least six characters,
                 have a special character, 
                 and at least one capital letter.')
  end
end

def valid_list_name?(list_name)
  !list_name.empty?
end

def redirect_if_bad_list_name(list_name)
  unless valid_list_name?(list_name)
    reroute('/new_user', 'Please provide a name for your list.')
  end
end

def modify_list(list)
  yield(list) if block_given?

  filepath = File.join(vocab_path, "list#{list[:id]}.yml")
  File.open(filepath, 'w') do |f|
    YAML.dump(list, f)
  end
  nil
end

# Return the next consecutive id in format '00x' (i.e. 002 after
# 001) or fill a gap returning '003' if lists '002' and '004'
# exist but not '003' (this could happen if a user was deleted)
def new_list_id
  pattern = File.join(vocab_path, '*')
  list_filenames = Dir[pattern].map { |filepath| File.basename(filepath) }

  ids = list_filenames.map { |filename| filename.scan(/\d/).join.to_i }
  ids.sort!
  ids.each_with_index do |current_id, idx|
    next_id = ids[idx + 1]
    return current_id + 1 if next_id != current_id + 1
  end
end

def add_list(username, list_name)
  new_id = format("%03d", new_list_id)
  new_user_list = { id: new_id, vocab: [],
                    name: list_name, owner: username,
                    editors: [], delete_queue: [],
                    new_word_queue: [] }
  filename = "list#{new_id}.yml"
  userlist_filepath = File.join(vocab_path, filename)

  File.open(userlist_filepath, 'w') do |f|
    YAML.dump(new_user_list, f)
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

  if signed_in?
    @user_lists = user_lists(session[:username])
  end

  erb :index
end

get '/new_user' do
  erb :new_user
end

post '/new_owner' do
  @username = params[:username]
  password = params[:password]
  list_name = params[:list_name]
  redirect_if_bad_password(password)
  redirect_if_bad_username(@username)
  redirect_if_bad_list_name(list_name)

  modify_users do |users|
    users[:owners] << @username
    users[:passwords][@username.to_sym] = encrypt(password).to_s
  end

  # Can extract this for a path to simply add a new list
  add_list(@username, list_name)

  reroute('/', "The user #{@username} has been created.")
end

# Render the page to create an editor account
get '/new_editor' do
  erb :new_editor
end

# Create a new editor
post '/new_editor' do
  @username = params[:username]
  password = params[:password]
  redirect_if_bad_password(password)
  redirect_if_bad_username(@username)

  modify_users do |users|
    users[:editors] << @username
    users[:passwords][@username.to_sym] = encrypt(password).to_s
  end
  
  reroute('/', "The user #{@username} has been created.")
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

# Route to sign in
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

# Display the page for adding an editor to the list
get '/vocab/:id/add_editor' do
  @list = load_list(params[:id])
  redirect_unless_owner("/vocab/#{@id}", @list)

  erb :add_editor
end

post '/vocab/:id/add_editor' do
  list = load_list(params[:id])
  editor = params[:editor_name]

  modify_list(list) do |list|
    list[:editors] << editor
  end

  reroute("/vocab/#{list[:id]}", "Editor #{editor} was added.")
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

# Add a new translation for a particular word
post '/vocab/:id/:word/add_translation' do
  id = params[:id]
  word = params[:word]
  list = load_list(id)
  translation = params[:new_translation]
  redirect_unless_owner_or_editor("/vocab/#{id}/#{word}", list)
  reroute("/vocab/#{id}/#{word}", 'You must provide a translation') if translation.empty?

  word_object = word_from_list(word, list)
  modify_list(list) do |list|
    word_object.translation = translation if list_owner?(list)
    word_object.provisional_translation = translation if list_editor?(list)
  end

  message = 'Translation added' if list_owner?(list)
  message = 'Translation provisionally added' if list_editor?(list)

  reroute("/vocab/#{id}/#{word}", message)
end

# Accept and add the editor's suggested translation
post '/vocab/:id/:word/confirm_translation' do
  id = params[:id]
  word = params[:word]
  list = load_list(id)
  translation = params[:confirm_translation]
  redirect_unless_owner("/vocab/#{id}/#{word}", list)
  reroute("/vocab/#{id}/#{word}", 'You must provide a translation') if translation.empty?

  word_object = word_from_list(word, list)
  modify_list(list) do |list|
    word_object.translation = translation
    word_object.provisional_translation = ''
  end

  reroute("/vocab/#{id}/#{word}", 'Translation added')
end

# Reject and clear the editor's provisional translation
post '/vocab/:id/:word/clear_provisional_translation' do
  id = params[:id]
  word = params[:word]
  list = load_list(id)
  redirect_unless_owner("/vocab/#{id}/#{word}", list)
  word_object = word_from_list(word, list)
  modify_list(list) do |list|
    word_object.provisional_translation = ''
  end

  reroute("/vocab/#{id}/#{word}", 'Provisional Translation removed')
end

# Render the form to add a new word
get '/vocab/:id/add_word' do
  @id = params[:id]
  redirect_unless_owner_or_editor("/vocab/#{@id}", load_list(@id))

  erb :new_word
end

def already_in_new_word_queue?(list, word)
  list[:new_word_queue].any? do |word_object|
    word.to_s == word
  end
end

# route to add a word to the list
post '/vocab/:id/add_word' do
  id = params[:id]
  @list = load_list(id)
  redirect_unless_owner_or_editor("/vocab/#{id}", @list)
  word = params[:word]
  unless unique_word?(@list, word)
    session[:message]= 'Sorry, that word is already in the list'
    status 422
    erb :vocab_list
  end

  # Replace with word_object = `new_or_queued_word`
  # If word objects compared to one another, this wouldn't be
  # necessary...
  if already_in_new_word_queue?(@list, word)
    word_object = @list[:new_word_queue].find do |word_object|
      word_object.to_s == word
    end
  else
    word_object = Word.new(word, params[:word_type])
  end

  modify_list(@list) do |list|
    list[:vocab] << word_object if list_owner?(@list)
    list[:new_word_queue].delete(word_object) if list_owner?(@list)
    list[:new_word_queue] << word_object if list_editor?(@list)
  end

  session[:message] = "Word #{word} was added" if list_owner?(@list)
  session[:message] = "Added #{word} to new word queue" if list_editor?(@list)
  redirect "/vocab/#{id}"
end

# route to delete a word from the list
post '/vocab/:id/:word/delete' do
  id = params[:id]
  word = params[:word]
  list = load_list(id)
  redirect_unless_owner_or_editor("/vocab/#{id}/#{word}", list)

  modify_list(list) do |list|
    word_object = list[:vocab].find do |word_object|
      word_object.word == word
    end
    list[:vocab].delete(word_object) if list_owner?(list)
    list[:delete_queue].delete(word_object) if list_owner?(list)
    list[:delete_queue] << word_object if list_editor?(list)
  end

  session[:message] = "The word '#{word}' was deleted." if list_owner?(list)
  session[:message] = "Added '#{word}' to deletion queue" if list_editor?(list)
  redirect "/vocab/#{id}"
end

# Dequeue a word from the vocab list
post '/vocab/:id/:word/dequeue_word/:queue' do
  id = params[:id]
  word = params[:word]
  queue = params[:queue].to_sym
  list = load_list(id)
  redirect_unless_owner("/vocab/#{id}/#{word}", list)

  modify_list(list) do |list|
    word_object = list[queue].find do |word_object|
      word_object.word == word
    end
    list[queue].delete(word_object)
  end

  str = "The word '#{word}' no longer queued for deletion."
  str1 = "The word '#{word}' no longer queued for addition."
  queue == :delete_queue ? message = str : message = str1

  session[:message] = message
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

def retrieve_word_from_list(word, list)
  list[:vocab].find do |word_object|
    word_object.word == word
  end
end

def form_already_queued?(pending_form, word)
  word.form_queue.any? { |form| form.to_s == pending_form }
end

# route to add a new word form
post '/vocab/:id/:word/add_word_form' do
  id = params[:id]
  list = load_list(id)
  word = retrieve_word_from_list(params[:word], list)
  pending_form = params[:word_form]
  redirect_unless_owner_or_editor("/vocab/#{id}/#{word}", list)

  if form_already_queued?(pending_form, word)
    form = word.form_queue.find do |form|
      form.to_s == pending_form
    end
  else
    markers = array_of_markers(params[:markers])
    form = Form.new(pending_form, markers)
  end

  modify_list(list) do |list|
    word.forms << form if list_owner?(list)
    word.form_queue.delete(form) if list_owner?(list)
    word.form_queue << form if list_editor?(list)
  end

  session[:message] = 'New word form has been added' if list_owner?(list)
  session[:message] = 'Word form was queued for addition' if list_editor?(list)
  redirect "/vocab/#{id}/#{word}"
end

# Delete a word form or dequeue it
post '/vocab/:id/:word/delete_word_form/:form' do
  id = params[:id]
  word_form = params[:form]
  list = load_list(id)
  word_object = retrieve_word_from_list(params[:word], list)
  redirect_unless_owner("/vocab/#{id}/#{word_object}", list)

  # This is ugly, and a refactoring could be separating to
  # two routes
  if params[:dequeue_word_form]
    modify_list(list) do |list|
      form = word_object.form_queue.find do |form|
        form.to_s == word_form
      end

      word_object.form_queue.delete(form)
    end
  else
    modify_list(list) do |list|
      form = word_object.forms.find do |form|
        form.to_s == word_form
      end

      word_object.forms.delete(form)
    end
  end

  session[:message] = "The form #{word_form} was deleted"
  redirect "/vocab/#{id}/#{word_object}"
end
