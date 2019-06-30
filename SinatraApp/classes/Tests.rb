class Tests

      include Mongoid::Document
      store_in collection: "tests"

      field :test_name,   		type: String
      field :test_type,   		type: String
      field :json_id, 			type: Array
      field :last_execution_id, type: String
      field :last_analysis_id,	type: String
end
