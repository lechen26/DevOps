class Executions
      include Mongoid::Document
      store_in collection: "executions"
      
	  field :execution_id,  type: String
      field :environment,   type: String
      field :test_name,   	type: String 
      field :tf_start,      type: Time
      field :tf_end,      	type: Time
      field :apm_server,	type: String
      field :console_url, 	type: String
      field :status,		type: String
      field :application,	type: String
end