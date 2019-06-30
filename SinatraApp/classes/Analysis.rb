class Analysis
      include Mongoid::Document
      store_in collection: "analysis"
      
      field :test_name,   	type: String
      field :analysis_id, 	type: String
      field :environment,     type: String
      field :json_id,         type: Integer
      field :timestamp,       type: DateTime
      field :server, 		type: String
      field :data,		type: Array
      field :tf_start, 		type: DateTime
      field :tf_end, 		type: DateTime     
      field :total_count, 	type: Integer
      field :success_count,   type: Integer
      field :failed_count, 	type: Integer
      field :success_rate, 	type: Float
      field :execution_status, type: String

end
