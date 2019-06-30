class UANightly
      include Mongoid::Document
      store_in collection: "uanightly"

      field :execution_id,	type: String
      field :test_name,       type: String
      field :environment,       type: String
      field :timestamp,       type: DateTime
      field :execution_status,	type: String
end
