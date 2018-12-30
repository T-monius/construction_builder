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

    get '/vocab/001/run'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'Home'
    assert_includes last_response.body, 'See Translation'
  end

  def test_showing_the_translation_of_a_word
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)
    
    post '/vocab/001/run/translation'

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Sorry, there is no translation'
  end

  def test_attempting_to_add_a_translation_signed_out
    sample_list = content_from_main_vocab_file('list001.yml')
    create_document(vocab_path, 'list001.yml', sample_list)
    
    post '/vocab/001/run/add_translation'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Sign in to do that'
  end
end
