# construction_builder_test.rb

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require_relative '../construction_builder'
require 'fileutils'
# require 'pry'

class ConstructionBuilderTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    FileUtils.mkdir_p(vocab_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
    FileUtils.rm_rf(vocab_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def owner_session
    { "rack.session" => { username: "owner", signed_in: true,
                          user_type: 'owner' } }
  end

  def editor_session
    { "rack.session" => { username: "editor", signed_in: true,
                          user_type: 'editor' } }
  end

  def content_from_main_vocab_file(filename)
    file = File.join(main_env_vocab_path, filename)
    File.read(file)
  end

  def create_document(filepath, name, content = "")
    File.open(File.join(filepath, name), "w") do |file|
      file.write(content)
    end
  end

  def test_word_object
    word_object = Word.new('happy', 'adj')
    assert_equal('happy', word_object.word)
    assert_equal('adj', word_object.type)
    assert_equal({dictionary: 'happy'}, word_object.forms)
    assert_equal('', word_object.translation)
  end

  def test_index
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'About'
    assert_includes last_response.body, 'sample'
  end

  def test_individual_vocab_list_page
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    get '/vocab/001'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'About'
    assert_includes last_response.body, ': dictionary form'
  end

  def test_view_individual_word_page
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    get '/vocab/001/walk'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'Home'
    assert_includes last_response.body, 'See Translation'
  end

  def test_showing_the_translation_of_a_word
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)
    
    post '/vocab/001/walk/translation'

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Sorry, there is no translation'
  end

  def test_attempting_to_add_a_translation_signed_out
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)
    
    post '/vocab/001/walk/add_translation'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Sign in to do that'
  end

  def test_sign_in_page
    get '/sign_in'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signing_in_as_owner
    content = content_from_main_data_path('users.yml')
    create_document(data_path, 'users.yml', content)

    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    post '/sign_in', username: 'owner', password: 'hello'

    assert_equal 302, last_response.status
    assert_equal 'Welcome owner!', session[:message]
    assert_equal 'owner', session[:user_type]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as owner'
  end

  def test_signing_in_as_editor
    content = content_from_main_data_path('users.yml')
    create_document(data_path, 'users.yml', content)

    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    post '/sign_in', username: 'editor', password: 'hello1'

    assert_equal 302, last_response.status
    assert_equal 'Welcome editor!', session[:message]
    assert_equal 'editor', session[:user_type]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as editor'
  end

  def test_signing_in_with_bad_credentials
    content = content_from_main_data_path('users.yml')
    create_document(data_path, 'users.yml', content)

    post '/sign_in', username: 'ralph', password: 'yep'

    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, 'Must provide valid credentials.'
  end

  def test_sign_out
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    get '/', {}, owner_session
    assert_includes last_response.body, "Signed in as owner"

    post '/sign_out'
    assert_equal 'You are signed out.', session[:message]

    get last_response['Location']
    assert_nil session[:username]
    assert_nil session[:user_type]
    assert_includes last_response.body, 'You are signed out.'
    assert_includes last_response.body, 'Sign in'
  end

  def test_viewing_a_non_existent_translation
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    get '/vocab/001/hamburger', {}, owner_session
    assert_includes last_response.body, 'Signed in as owner'

    post '/vocab/001/hamburger/translation'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Sorry, there is no translation available'
  end

  def test_adding_a_translation
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    get '/vocab/001/walk', {}, owner_session
    assert_includes last_response.body, 'Signed in as owner'

    post '/vocab/001/walk/add_translation', new_translation: 'ходить'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type='submit'>Sign Out)
    assert_includes last_response.body, 'See Translation'

    post '/vocab/001/walk/translation'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body,'ходить'
  end

  def test_deleting_a_word_from_a_list
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)

    get 'vocab/001/hamburger', {}, owner_session
    assert_includes last_response.body, 'Signed in as owner'    

    post '/vocab/001/hamburger/delete'
    assert_equal 302, last_response.status
    assert_equal "The word 'hamburger' was deleted.", session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(form</li>)
    refute_includes last_response.body, %q(>"hamburger"- noun)
  end
end
