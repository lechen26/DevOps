 #require 'autoinc'
# require 'mongoid_auto_increment'

class TestsJsons
    include Mongoid::Document
  #  include Mongoid::Autoinc
    store_in collection: "test_jsons"

    field :json_content,  type: Object      	
    field :json_id, type: Integer
    # increments :json_id, seed: 1
end
