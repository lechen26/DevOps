#!/usr/bin/ruby
require 'rubygems'
require 'json'
require 'rest-client'
require 'securerandom'
require 'mongoid'
require './classes/TestsJsons'
require 'active_support/time'
class RestParser

	# Read Test Json file and GET attributes
	# prepare Server REST API based on those attributes
	def init(test_name,json_id,server_host,tf_start,tf_end)	
		# preapre attributes
		@analysis_id=SecureRandom.uuid
		utc_offset = +2
		zone = ActiveSupport::TimeZone[utc_offset].name
		Time.zone = zone
		@timestamp=Time.zone.now()
		#@timestamp = zone.at(time)
		@test_name=test_name
		@server_host=server_host		
		@json_id=json_id
		@time_frame="#{tf_start}-#{tf_end}"
		@tf_start_date=Time.at(tf_start.to_i/1000)
		@tf_end_date=Time.at(tf_end.to_i/1000)	
		json = TestsJsons.find_by({json_id: @json_id.to_i})	
		test_json = json['json_content'].to_json if json
		@testobj = JSON.parse(test_json,:symbolize_names => true)
		
		# prepare Server rest api 
		@optier_base_url = "http://#{server_host}:8082/ng-ui/entity"
		@order_filters = "trxSort=startTime&trxSortOrder=asc"
		@wu_filters = "pageSort=startTime&pageSortOrder=desc"
		@pages_restapi="#{@optier_base_url}/ePageInstance?tf=#{@time_frame}&#{@order_filters}"
		@transaction_restapi="#{@optier_base_url}/eTransactionInstance?tf=#{@time_frame}&#{@order_filters}"		
		@output=Hash.new
		return @testobj
	end


	# Helper method to get identifiers 	
	def get_identifier(arr,param)
		arr.each do |object|
			return object[:expected_result].select { |obj| obj[:output_param].key? param}[0]
		end
	end

	# Prepare Query paramers from json data
	def prepare_query_params(entity)
		params=Hash.new
		identifiers=[]
		
		# add application filter
		params["filters[0][key]"] = "application"
		params["filters[0][operation]"] ="eq"
		params["filters[0][value]"] = @testobj[:application]
		i=1

		# add query params to filters
		entity[:query_params].each do |key,value|
			params["filters[#{i}][key]"] = key.to_s
			params["filters[#{i}][operation]"] = "eq"
			params["filters[#{i}][value]"] = value.to_s
			i+=1
		end unless entity[:query_params].nil?
		puts "params #{params}"
		# add inherit query params to filters
		entity[:inherit_query_params].each do |param|					
			identifier=get_identifier(@output["#{param[:source]}".to_sym][:data], param[:id]) if (! @output["#{param[:source]}".to_sym].nil? )&& @output["#{param[:source]}".to_sym][:data].any?		
			if identifier
				if ! identifier.empty? and ! param[:url]
					params["filters[#{i}][key]"] = param[:identifier].to_s
					params["filters[#{i}][operation]"] = "eq"
					params["filters[#{i}][value]"]=identifier[:output_param].values[0]
				end
				identifiers.push({:type => param[:identifier], :id => identifier[:output_param].values[0]})
			end
			i+=1
		end unless entity[:inherit_query_params].nil?
		puts "idenfifiers #{identifiers}"
		return params,identifiers
	end


	# Process entity based on result from server and query from json
	def process_entity(result,query,identifiers,subtype)#,unordered,with_unexpected)
		i=0	
		out = { :expected_result =>[], :not_expected_result => [], :ids => identifiers, :total_count => result.length, :failed_count => 0}
		out[:ids] = identifiers	
		puts "result is #{result}"
		puts "Query is #{query}"
		# if unordered state , checking if query exist no matter the order
		# if unordered
		# 	while i < query.length
		# 		entity_hash=Hash.new
		# 		entity_hash[:expected]=query[i][:validators]
		# 		entity_hash[:actual]=result.select{|k,v| entity_hash[:expected].has_key?k}
		# 	end
		# end

		result.each do |resultInstance|
			rc="Success"
			entity_hash=Hash.new
			if i < query.length
				entity_hash[:expected]=query[i][:validators]
				entity_hash[:actual]=resultInstance.select{|k,v| entity_hash[:expected].has_key?k}
				rc="Failed" if ( entity_hash[:actual] != entity_hash[:expected])
				entity_hash[:status]="#{rc}"
				entity_hash[:output_param]={ query[i][:output_param].values[0] => resultInstance[query[i][:output_param].keys[0]]} if ! query[i][:output_param].nil?
				entity_hash[:subtype]=query[i][:subtype] if ! query[i][:subtype].nil?
				out[:expected_result].push(entity_hash)
			else
				entity_hash[:status]="Failed"
				entity_hash[:actual]=resultInstance
				out[:not_expected_result].push(entity_hash)
			end
			i+=1
			out[:failed_count]+=1  if ( entity_hash[:status] == "Failed")
		end
		return out
	end

	# Server RestAPI
	def server_rest_api(url,queries)		
		begin
			response = RestClient::Request.new(
				:method => :get,
				:url => url,
				:user => "optier",
				:password => "123",
				:headers => { :accept => :json,
				:content_type => :json,
				:params => queries}
			).execute		
			results = JSON.parse(response.to_str,:symbolize_names => true)[:data] if response.code == 200
			puts "No Response from Server!" if results.nil?
		rescue RestClient::ExceptionWithResponse => err
  			err.response
		end		
		return results
	end


	def parse_test()
		return  { :test_name=>@test_name, :analysis_id => @analysis_id, :json_id => @json_id, :timestamp => @timestamp, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :success_rate => 0 }		
	end
	
	# Process Pages
	def parse_test_pages()		
		@output[:pageInstances]={ :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => [], :total_count => 0, :success_count => 0, :failed_count => 0, :success_rate => 0 } unless @testobj[:pageInstances].nil?
		@testobj[:pageInstances].each do |query|

			params=prepare_query_params(query)
			result=server_rest_api(@pages_restapi,params)		
			out=process_entity(result,query[:data],nil,nil)
			@output[:pageInstances][:data].push(out)
			@output[:pageInstances][:total_count]+=out[:total_count]
			@output[:pageInstances][:failed_count]+=out[:failed_count]
		end	unless @testobj[:pageInstances].nil?
		@output[:pageInstances][:success_count] = @output[:pageInstances][:total_count] - @output[:pageInstances][:failed_count] unless @testobj[:pageInstances].nil?
		@output[:pageInstances][:success_rate]=(@output[:pageInstances][:total_count]  == 0) ? 0 : ( ( @output[:pageInstances][:success_count].to_f  / @output[:pageInstances][:total_count] ) * 100).round(2)	unless @testobj[:pageInstances].nil?
		return @output[:pageInstances]
	end

	# Process transactions
	def parse_test_tr()
		@output[:transactionInstances]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => [], :total_count => 0, :success_count => 0, :failed_count => 0, :success_rate => 0 } unless @testobj[:transactionInstances].nil?		
		@testobj[:transactionInstances].each do |query|				
			params,identifiers=prepare_query_params(query)
			result=server_rest_api(@transaction_restapi,params)							
			puts result
			out=process_entity(result,query[:data],identifiers,nil)
			@output[:transactionInstances][:data].push(out)
			@output[:transactionInstances][:total_count]+=out[:total_count]
			@output[:transactionInstances][:failed_count]+=out[:failed_count]
		end unless @testobj[:transactionInstances].nil?
		@output[:transactionInstances][:success_count] = @output[:transactionInstances][:total_count] - @output[:transactionInstances][:failed_count] unless @testobj[:transactionInstances].nil?
		@output[:transactionInstances][:success_rate]=(@output[:transactionInstances][:total_count] == 0) ? 0 : (( @output[:transactionInstances][:success_count].to_f  / @output[:transactionInstances][:total_count] ) * 100).round(2) unless @testobj[:transactionInstances].nil?	
		return @output[:transactionInstances]
	end

	# Process workunits
	def parse_test_wu()
		@output[:workUnits]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => [], :total_count => 0, :failed_count => 0, :success_count => 0, :success_rate => 0 }
		@testobj[:workUnits].each do |query|		
			params,identifiers=prepare_query_params(query)		
			uuid=identifiers.find { |field| field.value? "uuid"}[:id] if identifiers.any?		
			@workunit_restapi="#{@optier_base_url}/eTransactionInstance/#{uuid}/wu?tf=#{@time_frame}&#{@order_filters}&#{@wu_filters}"
			result=server_rest_api(@workunit_restapi,params)	
			puts result		
			out=process_entity(result,query[:data],identifiers,nil) if ! result.nil?
			if out
				@output[:workUnits][:data].push(out)
				@output[:workUnits][:total_count]+=out[:total_count]
				@output[:workUnits][:failed_count]+=out[:failed_count]
			end
		end unless @testobj[:workUnits].nil?
		@output[:workUnits][:success_count] = @output[:workUnits][:total_count] - @output[:workUnits][:failed_count]
		@output[:workUnits][:success_rate]=(@output[:workUnits][:total_count] == 0 ) ? 0 : (( @output[:workUnits][:success_count].to_f  / @output[:workUnits][:total_count] ) * 100).round(2) unless @testobj[:workUnits].nil?	
		return @output[:workUnits]
	end

	# Process workunits attributes
	def parse_test_wu_attr()
		@output[:workUnitAttributes]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => [], :total_count => 0, :failed_count => 0, :success_count => 0, :success_rate => 0 }				
		@testobj[:workUnitAttributes].each do |query|
			attrout= { :expected_result => [], :total_count => 0, :failed_count => 0, :ids => []}
			params,identifiers=prepare_query_params(query)	
			uuid=identifiers.find { |field| field.value? "uuid"}[:id]  if identifiers.any?
			asskey=identifiers.find { |field| field.value? "associationKey"}[:id]  if identifiers.any?
			@workunitattr_restapi="#{@optier_base_url}/eTransactionInstance/#{uuid}/wu/#{asskey}?tf=#{@time_frame}&#{@order_filters}"
			result=server_rest_api(@workunitattr_restapi,params)	
			if result 
				query[:data].each do |typequery|
					resultarr=[]
					queryarr=[]				
					resultarr.push(result[:attributes]["#{typequery[:subtype]}".to_sym])
					queryarr.push(typequery)
					out=process_entity(resultarr,queryarr,identifiers,nil)	 if ! result.nil?
					if out 			
						attrout[:expected_result].push(out[:expected_result][0])				
						attrout[:total_count]+=out[:total_count]
						attrout[:failed_count]+=out[:failed_count]												
						attrout[:ids]=out[:ids]
					end
				end			
			end
			@output[:workUnitAttributes][:data].push(attrout)
			@output[:workUnitAttributes][:total_count]+=attrout[:total_count]
			@output[:workUnitAttributes][:failed_count]+=attrout[:failed_count]			
		end unless @testobj[:workUnitAttributes].nil?	
		@output[:workUnitAttributes][:success_count]=(@output[:workUnitAttributes][:total_count] - @output[:workUnitAttributes][:failed_count])
		@output[:workUnitAttributes][:success_rate]= (@output[:workUnitAttributes][:total_count] == 0 ) ? 0 : (( @output[:workUnitAttributes][:success_count].to_f  / @output[:workUnitAttributes][:total_count] ) * 100).round(2)  unless  @output[:workUnitAttributes].nil?
		return @output[:workUnitAttributes]
	end
end