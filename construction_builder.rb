# construcion_builder.rb

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'yaml'
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

def signed_in?
  session[:signed_in]
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

get '/sign_in' do
  erb :sign_in
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
  @list = load_list(params[:id])
  @word_object = @list[:vocab].find do |word_object|
    word_object.word == params[:word]
  end

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
  reroute("/vocab/#{id}/#{word}", 'Sign in to do that') unless signed_in?
  new_translation = params[:new_translation]
  reroute("/vocab/#{id}/#{word}", 'You must provide a translation') if new_translation.empty?

  @list = load_list(params[:id])
  @word_object = @list[:vocab].find do |word_object|
    word_object.word == params[:word]
  end

  @word_object.translation = new_translation

  filepath = File.join(vocab_path, "list#{params[:id]}.yml")
  File.open(filepath, 'w') do |f|
    YAML.dump(@list, f)
  end

  redirect "/vocab/#{@list[:id]}/#{@word_object.word}"
end


# route to add a word to the list

# route to delete a word from the list

# route to add a new word form

# route to delete a word form

# Route to sign in
