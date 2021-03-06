# construction_builder_test.rb

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require_relative '../construction_builder'
require 'fileutils'

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

  def create_sample_list_file
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)
  end

  def user_file
    user_file = content_from_main_data_path('users.yml')
    create_document(data_path, 'users.yml', user_file)
  end

  def create_sample_list_and_user_file
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)
    user_file = content_from_main_data_path('users.yml')
    create_document(data_path, 'users.yml', user_file)
  end

  def test_word_object
    word_object = Word.new('happy', 'adj')
    assert_equal('happy', word_object.word)
    assert_equal('adj', word_object.type)
    assert_equal([], word_object.forms)
    assert_equal('', word_object.translation)
  end

  def test_index
    create_sample_list_file

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'About'
    assert_includes last_response.body, 'sample'
  end

  def test_individual_vocab_list_page
    create_sample_list_file

    get '/vocab/001'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'About'
    assert_includes last_response.body, %q(>Sign in</a>)
  end

  def test_view_individual_word_page
    create_sample_list_file

    get '/vocab/001/walk'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'Home'
    assert_includes last_response.body, 'See Translation'
  end

  def test_cycling_words
    create_sample_list_file
    list = load_list('001')

    current_word = 'walk'
    get "/vocab/001/#{current_word}"
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Next Word'

    next_word = next_word_in_list(current_word, list)
    get "/vocab/001/#{next_word}"
    assert_equal 200, last_response.status
    assert_includes last_response.body, next_word

    current_word = next_word
    next_word = next_word_in_list(current_word, list)
    get "/vocab/001/#{next_word}"
    assert_equal 200, last_response.status
    assert_includes last_response.body, next_word
  end

  def test_showing_the_translation_of_a_word
    create_sample_list_file
    
    post '/vocab/001/walk/translation'

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Sorry, there is no translation'
  end

  def test_attempting_to_add_a_translation_signed_out
    create_sample_list_file
    
    post '/vocab/001/walk/add_translation'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Sign in as owner or editor to do that'
  end

  def test_sign_in_page
    get '/sign_in'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signing_in_as_owner
    create_sample_list_and_user_file

    post '/sign_in', username: 'owner', password: 'hello'

    assert_equal 302, last_response.status
    assert_equal 'Welcome owner!', session[:message]
    assert_equal 'owner', session[:user_type]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as owner'
  end

  def test_signing_in_as_editor
    create_sample_list_and_user_file

    post '/sign_in', username: 'editor', password: 'hello1'

    assert_equal 302, last_response.status
    assert_equal 'Welcome editor!', session[:message]
    assert_equal 'editor', session[:user_type]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as editor'
  end

  def test_signing_in_with_bad_credentials
    user_file

    post '/sign_in', username: 'ralph', password: 'yep'

    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, 'Must provide valid credentials.'
  end

  def test_sign_out
    create_sample_list_file

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
    create_sample_list_file

    get '/vocab/001/hamburger', {}, owner_session
    assert_includes last_response.body, 'Signed in as owner'

    post '/vocab/001/hamburger/translation'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Sorry, there is no translation available'
  end

  def test_adding_a_translation
    create_sample_list_file

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
    create_sample_list_file

    get 'vocab/001/hamburger', {}, owner_session
    assert_includes last_response.body, 'Signed in as owner'    

    post '/vocab/001/hamburger/delete'
    assert_equal 302, last_response.status
    assert_equal "The word 'hamburger' was deleted.", session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(verb</li>)
    refute_includes last_response.body, %q(>"hamburger"- noun)
  end

  def test_attempting_to_delete_a_word_while_signed_out
    create_sample_list_file
    
    get 'vocab/001/hamburger'
    assert_includes last_response.body, 'Sign in'

    post '/vocab/001/hamburger/delete'
    assert_equal 302, last_response.status
    assert_equal "Sign in as owner or editor to do that", session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(form of the word</a>)
    assert_includes last_response.body, %q(to do that</h4>)
  end

  def test_rendering_the_page_to_add_a_new_word_form
    create_sample_list_file
    
    get '/vocab/001/hamburger/add_word_form'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'first_person'
  end

  def test_attempting_to_add_a_new_word_form_signed_out
    create_sample_list_file
    
    post '/vocab/001/hamburger/add_word_form'
    assert_equal 302, last_response.status
    assert_equal 'Sign in as owner or editor to do that', session[:message]

    get last_response['Location']
    assert_includes last_response.body, %q(form of the word</a>)
    assert_includes last_response.body, %q(to do that</h4>)
  end

  def test_adding_a_new_word_form
    create_sample_list_file

    post '/vocab/001/hamburger/add_word_form', {word_form: 'hamburgers',
                                                markers: 'plural'},
                                               owner_session
    assert_equal 302, last_response.status
    assert_equal 'New word form has been added', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Signed in as owner'
    assert_includes last_response.body, 'plural'
  end

  def test_deleting_a_word_form
    create_sample_list_file

    post '/vocab/001/run/delete_word_form/ran', {}, owner_session
    assert_equal 302, last_response.status
    assert_equal 'The form ran was deleted', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'run'
  end

  def test_viewing_the_page_to_add_a_user
    get '/new_user'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, %q(vocab list:</label)
  end

  def test_adding_a_user
    create_sample_list_and_user_file

    post '/new_owner', username: 'robby', password: 'Hippop*tomus',
                      list_name: 'robbyzlist'

    assert_equal 302, last_response.status
    assert_equal 'The user robby has been created.', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'sample'
    assert load_vocab_lists.any? { |list| list[:name] == 'robbyzlist'}
  end

  def test_cannot_modify_non_owned_list
    create_sample_list_and_user_file

    post '/new_owner', username: 'robby', password: 'Hippop*tomus',
                      list_name: 'robbyzlist'

    assert_equal 302, last_response.status
    assert_equal 'The user robby has been created.', session[:message]

    post '/vocab/001/add_word', word: 'turkey',
                                "rack.session" => { username: "editor",
                                signed_in: true, user_type: 'editor' }

    assert_equal 302, last_response.status
    assert_equal 'Sign in as owner or editor to do that', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<h2>sample)
  end

  def test_add_a_new_word_as_editor
    create_sample_list_and_user_file

    post '/vocab/001/add_word', {word: 'turkey'}, editor_session
    assert_equal 302, last_response.status
    assert_equal 'Added turkey to new word queue', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<h2>sample)
    assert load_list('001')[:vocab].any? do |word_object|
      word_object.to_s == 'turkey'
    end
  end

  def test_queue_a_word_for_deletion_as_editor
    create_sample_list_and_user_file

    post '/vocab/001/hamburger/delete', {}, editor_session
    assert_equal 302, last_response.status
    assert_equal "Added 'hamburger' to deletion queue", session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<h2>sample)
    assert load_list('001')[:delete_queue].any? do |word_object|
      word_object.to_s == 'hamburger'
    end
  end

  def test_confriming_a_provisional_translation
    create_sample_list_and_user_file

    post 'vocab/001/hamburger/confirm_translation',
         {confirm_translation: 'гамбургер'},
         owner_session
    assert_equal 302, last_response.status
    assert_equal 'Translation added', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Translation added'
  end

  def test_confirming_a_queued_word
    create_sample_list_and_user_file

    post '/vocab/001/add_word', { word: 'crawl' }, owner_session
    assert_equal 302, last_response.status
    assert_equal 'Word crawl was added', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'crawl'
  end

  def test_confirming_a_new_word_form
    create_sample_list_and_user_file

    post '/vocab/001/walk/add_word_form', { word_form: 'walks' }, owner_session
    assert_equal 302, last_response.status
    assert_equal 'New word form has been added', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'walks'
  end

  def test_dequeue_new_word_form
    create_sample_list_and_user_file

    post '/vocab/001/walk/delete_word_form/walks', {}, owner_session
    assert_equal 302, last_response.status
    assert_equal session[:message], 'The form walks was deleted'

    get last_response['Location']
    assert_equal 200, last_response.status
    refute_includes last_response.body, 'Forms of the word'
  end

  def test_confirming_deletion
    create_sample_list_and_user_file

    post '/vocab/001/hamburger/delete', {}, owner_session
    assert_equal 302, last_response.status
    assert_equal "The word 'hamburger' was deleted.", session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(Add Editor</a>)
  end

  def test_dequeueing_a_new_word
    create_sample_list_and_user_file

    post '/vocab/001/crawl/dequeue_word/new_word_queue', {}, owner_session
    assert_equal 302, last_response.status
    assert_equal "The word 'crawl' no longer queued for addition.", session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<p>None</p>)
  end

  def test_reject_a_provisional_translation
    create_sample_list_and_user_file

    post '/vocab/001/hamburger/clear_provisional_translation', {}, owner_session
    assert_equal 302, last_response.status
    assert_equal 'Provisional Translation removed', session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    refute_includes last_response.body, 'Editor suggested translation'
  end

  def test_keep_a_word_and_deny_deletion_request
    create_sample_list_and_user_file

    post '/vocab/001/hamburger/dequeue_word/delete_queue', {}, owner_session
    assert_equal 302, last_response.status
    assert_equal "The word 'hamburger' no longer queued for deletion.",
                 session[:message]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(hamburger"</a>)
  end
end
