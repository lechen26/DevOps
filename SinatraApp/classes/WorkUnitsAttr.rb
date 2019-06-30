class WorkUnitsAttr

      include Mongoid::Document
      store_in collection: "workunits_attr"
    
      field :test_name,       type: String
      field :analysis_id,     type: String
      field :server,          type: String
      field :data,            type: Hash
      field :tf_start,        type: DateTime
      field :tf_end,          type: DateTime      
      field :total_count,     type: Integer
      field :success_count,   type: Integer
      field :failed_count,    type: Integer
      field :success_rate,    type: Float
      
end
