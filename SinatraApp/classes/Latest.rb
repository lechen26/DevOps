class Latest
      include Mongoid::Document
      store_in collection: "latest"
      
      field :analysis_id, 	type: String
      field :test_name,       type: String
      field :environment,       type: String
      field :success_rate,    type: Float 
      field :timestamp,       type: DateTime
      field :execution_id,	type: String
      field :execution_status,	type: String
end
