#!/usr/bin/ruby
require 'rubygems'
require 'json'
require 'rest-client'
require 'securerandom'
require 'uuidtools'
require 'mongoid'
require './classes/TestsJsons'
require 'active_support/time'
class AnalysisService
	
	# Read Test Json file and GET attributes
	# prepare Server REST API based on those attributes
	def init(test_name,json,server_host,tf_start,tf_end)	
		@restuser="optier"
		@restpass="123"		
		@test_name=test_name
		@analysis_id=UUIDTools::UUID.timestamp_create.to_s
		#@analysis_id=SecureRandom.uuid		
		@timestamp=Time.now()
		
		@server_host=nil
		@time_frame="#{tf_start}-#{tf_end}"
		@tf_start_date=Time.at(tf_start.to_i/1000)
		@tf_end_date=Time.at(tf_end.to_i/1000)	

		test_json = json['json_content'].to_json if json	
		@testobj = JSON.parse(test_json,:symbolize_names => true)
		@json_id= json['json_id']	

		# prepare Server rest api 
		puts "server_host=#{server_host}"
		if ( server_host.include?(":") ) 
			@server_host=server_host.split(':')[0]
			@server_port=server_host.split(':')[1]
		else
			@server_host=server_host
			@server_port=8082
		end
		@optier_base_url = "http://#{@server_host}:#{@server_port}/ng-ui/entity"
		@order_filters = "trxSort=startTime&trxSortOrder=asc"
		@wu_filters = "pageSort=startTime&pageSortOrder=desc"
		@pages_restapi="#{@optier_base_url}/ePageInstance?tf=#{@time_frame}&#{@wu_filters}"
		@transaction_restapi="#{@optier_base_url}/eTransactionInstance?tf=#{@time_frame}&#{@order_filters}"		
		
		@optional=[]	
		@optional_pg=[]	
		@wu_keys=[]
		@pg_uuids=[]
		@tr_uuids=[]
		@pg_tr_uuids=[]

		# output hashes
		@output=Hash.new
		@output[:transactionInstances]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => { :expected_results => [], :not_expected_results => []}, :total_count => 0, :success_count => 0, :failed_count => 0, :success_rate => 0 , :dimensions => { :total_count => 0, :success_count => 0, :success_rate => 0} }		
		@output[:workUnits]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => [], :total_count => 0, :failed_count => 0, :success_count => 0, :success_rate => 0 }
		@output[:workUnitAttributes]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => [], :total_count => 0, :failed_count => 0, :success_count => 0, :success_rate => 0 }						
		return @testobj
	end
	

	# Server RestAPI
	def server_rest_api(url,queries)		
		begin
			response = RestClient::Request.new(
				:method => :get,
				:url => url,
				:user => @restuser,
				:password => @restpass,
				:headers => { :accept => :json,
				:content_type => :json,
				:params => queries}
			).execute		
			results = JSON.parse(response.to_str,:symbolize_names => true,:max_nesting => 300)[:data] if response.code == 200			
		rescue RestClient::ExceptionWithResponse => err
  			err.response
		end		
		return results
	end

	# add application parameter as filter
	def prepare_base_params()
		params=Hash.new
		params=add_params(params,"application",@testobj[:application])	
		return params
	end

	def add_params(params,key,value)
		i=params.length/3;
		params["filters[#{i}][key]"] = key.to_s
		params["filters[#{i}][operation]"] = "eq"
		params["filters[#{i}][value]"] = value.to_s		
		return params
	end

	def process_entity_params(entity)
		params=prepare_base_params()
		params=add_params(params,"name",entity[:name])
		return params
        end
        
	# add parameters as filters
	def process_params(entity)	
		params=prepare_base_params()
		entity.each do |key,value|					
			add_params(params,key.to_s,value.to_s)	if ! ( key.to_s.eql?("optional") || key.to_s.eql?("multiple"))
		end		
		return params
	end
	
	

	# initiate test parsing
	def parse_test()
		process_entry()
		test={ :test_name=>@test_name,  :environment => @testobj[:environment], :analysis_id => @analysis_id, :json_id => @json_id, :timestamp => @timestamp, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :success_rate => 0 }		
		return test
	end

	# helper method - parse specific entity for the test
	def parse_test_entity(entity)
		return @output["#{entity}".to_sym]
	end


	def process_entry()			
		@output[:pageInstances]={ :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => { :expected_results => [], :not_expected_results => []}, :total_count => 0, :success_count => 0, :failed_count => 0, :success_rate => 0 }		
		@output[:transactionInstances]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => { :expected_results => [], :not_expected_results => []}, :total_count => 0, :success_count => 0, :failed_count => 0, :success_rate => 0 , :dimensions => { :total_count => 0, :success_count => 0, :success_rate => 0, :failed_count => 0} }
		@output[:workUnits]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => { :expected_results => [], :not_expected_results => []}, :total_count => 0, :failed_count => 0, :success_count => 0, :success_rate => 0 }
		@output[:workUnitAttributes]={  :test_name=>@test_name, :analysis_id => @analysis_id, :server=> @server_host, :tf_start => @tf_start_date, :tf_end => @tf_end_date, :data => { :expected_results => [], :not_expected_results => []}, :total_count => 0, :failed_count => 0, :success_count => 0, :success_rate => 0 }				
		@possible_matches=[]
		@possible_pages_matches=[]
		# loop over test json file
		@testobj[:data].each do |entity|						
			@tr_exist=false
			@page_exist=false
			@page_status=true
			@trans_exist=false
			@tr_status=false
			@wu_status=false
			@wuattr_status=nil
			@tr_analysis=Hash.new
			# check if entity includes page identification
			if ! entity[:pageInstance].nil?			
				matches_pages_uuid=pageInstanceAnalysis(entity[:pageInstance])
				
				# check if page exist on the system
				if matches_pages_uuid.any?					
					puts "found poage"
					@page_exist=true					
					@output[:pageInstances][:success_count]+=1
				else
					puts "could find the page"
					if entity[:pageInstance][:optional].nil?						
						@output[:pageInstances][:failed_count]+=1	
						#TLS-7532
						if ! entity[:pageInstance][:label].nil?
							@page_entry={:name => entity[:pageInstance][:name], :label => entity[:pageInstance][:label] , :pageId => nil, :page_exist => @page_exist,:trans_exist => @trans_exist, :page_status => @page_status}
						else
							@page_entry={:name => entity[:pageInstance][:name], :label => nil, :pageId => nil, :page_exist => @page_exist,:trans_exist => @trans_exist, :page_status => @page_status}
					end	
						@output[:pageInstances][:data][:expected_results].push(@page_entry)					
					else
						@optional_pg.push({:name => entity[:pageInstance][:name]})
					end
				end

				# loop over possible matches for this existing page				
				matches_pages_uuid.each do |page_uuid|	
					@pg_tr_uuids=[]
			
					trans={:name => entity[:pageInstance][:name],:pageId => page_uuid, :trx=> [],:tr_count => 0 }					
					trx=[]
					entity[:transactionInstances].each do |trx|
						tr_entry,tr_wu=process_transaction(trx,page_uuid)	
						if ! tr_entry.nil? && ! tr_wu.nil? 
							trans[:tr_count]+=1 if tr_entry[:tr_exist] 							
						end																						
						trans[:trx].push({:tr_entry => tr_entry,:tr_wu => tr_wu})  unless @optional.any?{ |h| h[:name] == tr_entry[:name]}
					end

					# if we found all transactions for this page										
					if ! trans[:trx].nil? && ! trans[:trx].any?{ |t| t[:tr_entry][:tr_exist] == false} 												
						@trans_exist=true 
						@pg_uuids.push(page_uuid)

						trans[:trx].each do |tr|							
					    	@tr_uuids.push(tr[:tr_entry][:uuid])
						end
		
						if  trans[:trx].any?{ |t| ! t[:tr_entry][:tr_status] }
							@page_status=false
						end
						#TLS-5732
						if ! entity[:pageInstance][:label].nil?
							@page_entry={:name => entity[:pageInstance][:name], :label =>  entity[:pageInstance][:label] , :pageId => page_uuid, :page_exist => @page_exist,:trans_exist => @trans_exist, :page_status => @page_status}																		
						else
							@page_entry={:name => entity[:pageInstance][:name], :label => nil, :pageId => page_uuid, :page_exist => @page_exist,:trans_exist => @trans_exist, :page_status => @page_status}
						end
						@output[:pageInstances][:data][:expected_results].push(@page_entry)	
						@possible_pages_matches.delete_if {|t| t[:name] == entity[:pageInstance][:name]}						
						report_transactions(trans[:trx])
						break
					end
					if  ! trans[:trx].nil? && trans[:trx].any?{ |t| t[:tr_entry][:tr_status] == false}
                                            @page_status=false
                                        end
					@possible_pages_matches.push(trans)	
				end unless matches_pages_uuid.nil?
	
				# if we couldnt find a match, looking on the best we can get
				if ! matches_pages_uuid.empty? && ! @trans_exist 
					page_out=get_page_best_match(entity[:pageInstance][:name])						
					#TLS-5372
					if ! entity[:pageInstance][:label].nil?
                                                       @page_entry={:name => entity[:pageInstance][:name], :label =>  entity[:pageInstance][:label] , :pageId => page_out[:pageId], :page_exist => @page_exist,:trans_exist => @trans_exist, :page_status => @page_status}
                                                else
                                                        @page_entry={:name => entity[:pageInstance][:name], :label => nil, :pageId => page_out[:pageId] , :page_exist => @page_exist,:trans_exist => @trans_exist, :page_status => @page_status}
                                               end
					@pg_uuids.push(page_out[:pageId])	
					page_out[:trx].each do |tr|							
				    		@tr_uuids.push(tr[:tr_entry][:uuid])  unless tr[:tr_entry].nil?
					end					
					@output[:pageInstances][:data][:expected_results].push(@page_entry)															
					report_transactions(page_out[:trx])					
				end	
				
			else
				# Transaction validation (no page)		
				tr_entry,tr_wu=process_transaction(entity)
				if ! tr_entry.nil? && ! @optional.any?{ |h| h[:name] == tr_entry[:name]}
		    			@pg_tr_uuids.push(tr_entry[:uuid]) 
					report_transaction(tr_entry,tr_wu) 
				end
			end				
	 	end		 	
		process_unexpected_transactions()	
		process_unexpected_pages() 
		process_dimensions()
	end

	# return best possible match for pageid transactions
	def get_page_best_match(name)
		return @possible_pages_matches.select{|p| p[:name] == name && ! @pg_uuids.any?{ |t|t == p[:pageId] }}.max_by{|p| p[:tr_count]} 
	end

	def already_founded(name,page_uuid)
		return @multiple_tr.select{|p| p[:name] == name && p[:pageId] == page_uuid} if ! @multiple_tr.nil?				
	end

	 def dimensionsPagesAnalysis(entity,pgid)
                @dimension_found=false
                @dimensions=[]
                params=process_entity_params(entity)
                params=add_params(params,"pageId",pgid)
                result=server_rest_api(@pages_restapi,params)
                entity.each do |key,value|
                        if ! key.to_s.eql?("name") &&  ! key.to_s.eql?("optional")  &&  ! key.to_s.eql?("multiple")
                        if ! result[0][key].nil? && result[0][key].eql?(value.to_s)
                                @dimension_found=true
                        else
                                @dimension_found=false
                        end
                        @dimensions.push({:dimension_name => key, :dimension_expected_value => value, :dimension_actual_value => result[0][key].to_s, :dimension_status => @dimension_found })
                        end
                end
                return @dimensions
        end

	def dimensionsTransactionAnalysis(entity,pgid,uuid)
		@dimension_found=false
		@dimensions=[]
		params=process_entity_params(entity)
                params=add_params(params,"uuid",uuid)
                params=add_params(params,"pageId",pgid) if ! pgid.nil?
                result=server_rest_api(@transaction_restapi,params)
	  	entity.each do |key,value|
			if ! key.to_s.eql?("name") &&  ! key.to_s.eql?("optional")  &&  ! key.to_s.eql?("multiple")
				if ! result[0][key].nil? && result[0][key].eql?(value.to_s)
					@dimension_found=true
				else
					@dimension_found=false
				end
				@dimensions.push({:dimension_name => key, :dimension_expected_value => value, :dimension_actual_value => result[0][key].to_s, :dimension_status => @dimension_found })
			end
                end
		return @dimensions
	end

	# process single transactions (based on pageid or not)
	def process_transaction(entity,page_uuid=nil)
		@tr_status=false
		@tr_exist=false
		@wu_status=false
		@tr_dims_status=nil
		@wuattr_status=nil	
		@tr_entry=nil
		@tr_wu=nil
                @tr_dims=nil
		@possible_matches=[]

		puts "process #{entity[:transactionInstance][:name]}"
	
		matches_uuid=transactionInstanceAnalysis(entity[:transactionInstance],page_uuid)		
		puts "matches_uuid=#{matches_uuid}"
		matches_uuid.any? ? @tr_exist=true  : @tr_entry={:name => entity[:transactionInstance][:name], :uuid => nil, :pageId => page_uuid, :tr_dims => nil, :tr_dims_status => nil, :tr_exist => @tr_exist, :wu_status =>  @wu_status ,:wu_attr_status => @wuattr_status, :tr_status => @tr_status}																					
		matches_uuid.each do |uuid|									
			@tr_dims=dimensionsTransactionAnalysis(entity[:transactionInstance],page_uuid,uuid)
			@tr_wu = workUnitsAnalysis(entity[:workUnits],uuid,entity[:transactionInstance][:name])				
			@possible_matches.push(@tr_wu) if ! @tr_uuids.any?{ |t| t == uuid }					
			if @tr_wu[:wu_count] >= (entity[:workUnits].select{ |w| ! w.has_key?(:optional) }.count)
			 	@tr_status=true		
			 	if page_uuid.nil? 
			 		@tr_uuids.push(uuid) 
			 	else
			 		@pg_tr_uuids.push(uuid) 			 				 
			 	end

			 	@tr_entry={:name => entity[:transactionInstance][:name], :uuid => uuid, :pageId => page_uuid, :tr_dims => nil, :tr_dims_status => nil, :tr_exist => @tr_exist, :wu_status =>  @tr_wu[:wu_status] ,:wu_attr_status => @tr_wu[:wu_attr_status], :tr_status => @tr_status}													 	
			end
			break if @tr_status
		end unless matches_uuid.nil?

		# if we couldnt find a match, looking on the best we can get
	 	if ! matches_uuid.empty? && ! @tr_status			 	
	 		@tr_wu=get_uuid_best_match(entity[:transactionInstance][:name])		 				 		
	 		@tr_status=false				 	
		 	if page_uuid.nil? 
		 		 @tr_uuids.push(@tr_wu[:uuid]) 
	 		else	
	 		 	@pg_tr_uuids.push(@tr_wu[:uuid]) 	 				 		
	 		end
			@tr_entry={:name => entity[:transactionInstance][:name], :uuid => @tr_wu[:uuid],:pageId => page_uuid, :tr_dims => nil, :tr_dims_status => nil, :tr_exist => @tr_exist, :wu_status =>  @tr_wu[:wu_status] ,:wu_attr_status => @tr_wu[:wu_attr_status], :tr_status => @tr_status}													 		 			
	 	end

                                if ! @tr_dims.nil? && @tr_dims.any? 
					if @tr_dims.any? { |d| ! d[:dimension_status] }
						@tr_dims_status=false
                                        	@tr_status=false
                                	else
						@tr_dims_status=true
					end
					@tr_entry={:name => entity[:transactionInstance][:name], :uuid => @tr_wu[:uuid], :pageId => page_uuid, :tr_dims => @tr_dims,  :tr_dims_status => @tr_dims_status,  :tr_exist => @tr_exist, :wu_status =>  @tr_wu[:wu_status] ,:wu_attr_status => @tr_wu[:wu_attr_status], :tr_status => @tr_status}
				end

	 	if ! entity[:transactionInstance][:optional].nil? && ! @tr_exist
	 	 	#@tr_entry=nil
	 	 	#@tr_wu=nil
	 	 	@optional.push({:name => entity[:transactionInstance][:name], :pageId => page_uuid})
	 	 end
	 	

	 	if ! entity[:transactionInstance][:multiple].nil?	 	
	 		@optional.push({:name => entity[:transactionInstance][:name], :pageId => page_uuid})
	 	end	 	
		puts "Finish process TR"
	 	return @tr_entry ,@tr_wu	
	end

	# get all transActions of this application by this TimeFrame
	def process_unexpected_transactions()		
		unexpected_uuids=[]	
		params=prepare_base_params()	
		result=server_rest_api(@transaction_restapi,params)	
		result.each do |res|	
			if ! @output[:transactionInstances][:data][:expected_results].any?{ |h| ! h.nil? && ! h[:uuid].nil? && h[:uuid] == res[:uuid]} && ! @optional.any?{ |h| ! h.nil? && h[:name] == res[:name]}
				@output[:transactionInstances][:data][:not_expected_results].push({:name => res[:name], :uuid=> res[:uuid], :tr_exist => true, :tr_status => false})		
				@output[:transactionInstances][:failed_count]+=1		
			end			
		end	unless result.nil?
		@output[:transactionInstances][:total_count]=@output[:transactionInstances][:failed_count] + @output[:transactionInstances][:success_count]
		@output[:transactionInstances][:success_rate]=(@output[:transactionInstances][:total_count]  == 0) ? 0 : ( ( @output[:transactionInstances][:success_count].to_f  / @output[:transactionInstances][:total_count] ) * 100).round(2)
		@output[:workUnits][:total_count]=@output[:workUnits][:failed_count] + @output[:workUnits][:success_count]
		@output[:workUnits][:success_rate]=(@output[:workUnits][:total_count]  == 0) ? 0 : ( ( @output[:workUnits][:success_count].to_f  / @output[:workUnits][:total_count] ) * 100).round(2)		
		@output[:workUnitAttributes][:total_count]=@output[:workUnitAttributes][:failed_count] + @output[:workUnitAttributes][:success_count]
		@output[:workUnitAttributes][:success_rate]=(@output[:workUnitAttributes][:total_count]  == 0) ? 0 : ( ( @output[:workUnitAttributes][:success_count].to_f  / @output[:workUnitAttributes][:total_count] ) * 100).round(2)		
	end

	def process_unexpected_pages()		
		unexpected_pgids=[]	
		params=prepare_base_params()
		result=server_rest_api(@pages_restapi,params)	
		result.each do |res|	
			if ! @output[:pageInstances][:data][:expected_results].any?{ |p| p[:pageId] == res[:pageId]} && ! @optional_pg.any?{ |h| h[:name] == res[:name]}		 					
				#TLS-5732
				@output[:pageInstances][:data][:not_expected_results].push({:name => res[:name], :label => res[:label], :pageId=> res[:pageId], :page_status => false, :tr_status => nil})		
				@output[:pageInstances][:failed_count]+=1		
			end			
		end	unless result.nil?
		@output[:pageInstances][:total_count]=@output[:pageInstances][:failed_count] + @output[:pageInstances][:success_count]
		@output[:pageInstances][:success_rate]=(@output[:pageInstances][:total_count]  == 0) ? 0 : ( ( @output[:pageInstances][:success_count].to_f  / @output[:pageInstances][:total_count] ) * 100).round(2)		
	end

	def report_page(page)
		if page[:page_exist]
			@output[:pageInstances][:data][:expected_results].push(page)
		else
			@output[:pageInstances][:data][:expected_results].push(page)
		end
	end

	def process_dimensions() 
		@output[:transactionInstances][:data][:expected_results].each do |tran| 
			if ! tran[:tr_dims].nil? 
				tran[:tr_dims].each do |dim|
					if dim[:dimension_status] 
						@output[:transactionInstances][:dimensions][:success_count]+=1
					else
						@output[:transactionInstances][:dimensions][:failed_count]+=1
					end
				end
			end
		end
		@output[:transactionInstances][:dimensions][:total_count]= @output[:transactionInstances][:dimensions][:success_count] +  @output[:transactionInstances][:dimensions][:failed_count]
		@output[:transactionInstances][:dimensions][:success_rate]=(@output[:transactionInstances][:dimensions][:total_count]  == 0) ? 0 : ( @output[:transactionInstances][:dimensions][:success_count].to_f  / @output[:transactionInstances][:dimensions][:total_count] * 100).round(2)
        end

	# report transaction and workunits 
	def report_transaction(tran,wu)			
		! tran.nil? && tran[:tr_exist] &&  ( tran[:tr_dims_status].nil? || tran[:tr_dims_status]) && tran[:wu_status] && ( tran[:wu_attr_status].nil? ||  tran[:wu_attr_status]) ? @output[:transactionInstances][:success_count]+=1 : @output[:transactionInstances][:failed_count]+=1	
		@output[:transactionInstances][:data][:expected_results].push(tran)
		report_workunits(wu)
		report_workunits_attr(wu)
	end
    
	# report transactions
	def report_transactions(transactions)	
		transactions.each do |tran|			
			report_transaction(tran[:tr_entry],tran[:tr_wu])			
		end unless transactions.nil?
	end

	def report_workunits(uuid_out)
		if ! uuid_out.nil?	
			uuid_out[:workunits].each do |wu|
				@output[:workUnits][:data][:expected_results].push(wu)	
				( wu[:wu_status].eql?(false) || wu[:wuattr_status].eql?(false) ) ? @output[:workUnits][:failed_count]+=1 : @output[:workUnits][:success_count]+=1							
			end unless uuid_out[:workunits].nil?
			uuid_out[:not_expected_workunits].each do |wu|
				@output[:workUnits][:failed_count]+=1
				@output[:workUnits][:data][:not_expected_results].push(wu)	
			end		
		end
	end


	def report_workunits_attr(uuid_out)		
		if ! uuid_out.nil?
			uuid_out[:wu_attr].each do |wu|			
			 	@output[:workUnitAttributes][:data][:expected_results].push(wu)
			 end unless uuid_out[:wu_attr].nil?	 		 
			 @output[:workUnitAttributes][:success_count]+=uuid_out[:wu_attr_success_count]		
			 @output[:workUnitAttributes][:failed_count]+=uuid_out[:wu_attr_failed_count]		
		end
	end

	def get_uuid_best_match(name)
		return @possible_matches.select{|p| p[:name] == name }.max_by{|p| p[:wu_count]}
	end

	# TLS-7532
	def getLabelOfPage(type,value)
	        params=prepare_base_params()
                params=add_params(params,type,value)
		result=server_rest_api(@pages_restapi,params)
		page=result.find { |h| h[type.to_sym] == value }
		return page[:label]
	end

	# check if PageInstance exist on the Server
	def pageInstanceAnalysis(entity) 
		puts "search for page #{entity}"
		params=process_params(entity)
		result=server_rest_api(@pages_restapi,params)
		puts "result=#{result}"
		pages_uuids=[]
		puts "#{@pg_uuids}"
		matches=result.select{ |h| ! @pg_uuids.any?{ |t| t == h[:pageId] && h[:name] == entity[:name]}  }	if ! result.nil?
		puts "matches=#{matches}"
		matches.each do |tr|
			pages_uuids.push(tr[:pageId])
		end unless matches.nil?
		return pages_uuids
	end

	# Check if TransactionInstance exist on the Server
	def transactionInstanceAnalysis(entity,pgid=nil)		
		#14-08-17
		#params=process_params(entity)
		params=process_entity_params(entity)
		params=add_params(params,"pageId",pgid)	if ! pgid.nil?
		result=server_rest_api(@transaction_restapi,params)		
		tr_uuids=[]		
		matches=result.select{ |h| ! @pg_tr_uuids.any?{ |t| t == h[:uuid] } && ! @tr_uuids.any?{ |t| t == h[:uuid] }  } unless result.nil?	
		matches.each do |tr|
			tr_uuids.push(tr[:uuid])
		end unless matches.nil?		
		return tr_uuids
	end

	
	# Check if expected workunits found for specific TransactionInstance
	def workUnitsAnalysis(entities,tr_uuid,name)			
		@total_wu_status=true
		@uuid_result={:name => name,:uuid => tr_uuid, :wu_count => 0 ,:workunits => [], :not_expected_workunits => [],:wu_attr => [], :wu_status => false, :wu_attr_status => nil , :wu_attr_success_count => 0,:wu_attr_failed_count => 0}
		
		params=prepare_base_params()
		@workunit_restapi="#{@optier_base_url}/eTransactionInstance/#{tr_uuid}/wu?tf=#{@time_frame}&#{@order_filters}&#{@wu_filters}"	
		result=server_rest_api(@workunit_restapi,params)	
	
		# search for each uuid if it includes the wanted wu & attributes we are looking for	
		entities.each do |entity|						
			wuattr_status=false
			wu_status=false
			wu_attr=nil
			wukey=nil
			invoking=entity[:invokingTier]
			executing=entity[:executingTier]			
			wu=Hash.new
			#ToDo# check about the AK
			matches_wu=result.select{ |h| entity[:invokingTier].include?(h[:invokingTier]) && entity[:executingTier].include?(h[:executingTier]) && h[:rawProtocol] == entity[:rawProtocol] && ! @uuid_result[:workunits].any?{ |w| w[:assKey] == h[:associationKey] } }				
			# looping over all resulst for the following invocation	
			@total_wu_status=false if matches_wu.empty?
			matches_wu.each do |r|	
				wukey=r[:associationKey]					
				wu_status=true				
				invoking=r[:invokingTier]	
				executing=r[:executingTier]
				if entity[:attributes].nil? 					
					wuattr_status=nil									
					@uuid_result[:wu_count]+=1
				else
					wu_attr=workUnitsAttributesAnalysis(entity[:attributes],tr_uuid,wukey)					
					if (wu_attr[:success_count].eql?(entity[:attributes].length))
						wuattr_status=true										
						@uuid_result[:wu_count]+=1
						@uuid_result[:wu_attr_status]=true														
						
					else				
						wuattr_status=false	
						@uuid_result[:wu_attr_status]=false
						@uuid_result[:wu_status]=false					
					end
					#ToDo# should be outside the loop. wil be incremented even for bad ones
					@uuid_result[:wu_attr_success_count]+=wu_attr[:success_count]
					@uuid_result[:wu_attr_failed_count]+=wu_attr[:failed_count]
				end
				break if wu_status && (wuattr_status.nil? || wuattr_status)										
			end unless matches_wu.nil?			
			wu={:name => name, :uuid => tr_uuid,:assKey => wukey, :invokingTier => invoking, :executingTier => executing, :rawProtocol => entity[:rawProtocol], :wu_status=> wu_status, :wuattr_status => wuattr_status}											
			if ! entity[:optional].nil? 
				if wu_status					
					@uuid_result[:workunits].push(wu)					
					@uuid_result[:wu_attr].push(wu_attr) unless wu_attr.nil?										
				else
					@total_wu_status=true					
				end
			else
				if ! wu_status
					@total_wu_status=false
				end
				@uuid_result[:workunits].push(wu)					
				@uuid_result[:wu_attr].push(wu_attr) unless wu_attr.nil?														
			end

			if ! entity[:multiple].nil? 
				multiples=matches_wu.select{ |h| h[:associationKey] != wukey }
				multiples.each do |w| 
					wu={:name => name, :uuid => tr_uuid,:assKey => w[:associationKey], :invokingTier => invoking, :executingTier => executing, :rawProtocol => entity[:rawProtocol], :wu_status=> true, :wuattr_status => nil}											
					@uuid_result[:workunits].push(wu)					
					@uuid_result[:wu_attr].push(wu_attr) unless wu_attr.nil?				
				end
			end				
		end		

		# not expected	
		result.each do |res|			
			if ! @uuid_result[:workunits].any?{|h| h[:assKey] == res[:associationKey]}			
				@uuid_result[:not_expected_workunits].push({:uuid => tr_uuid, :assKey => res[:associationKey], :invokingTier => res[:invokingTier], :executingTier => res[:executingTier], :rawProtocol => res[:rawProtocol],:wu_status => false, :wuattr_status => nil})
				@total_wu_status=false			
			end
		end unless result.nil?
		@uuid_result[:wu_status]=@total_wu_status		
		return @uuid_result		
	end


	def process_wuattr_of_best_match(uuid_out)
		uuid_wu_attr=[]
		uuid_out[:workunits].each do |wu|
			if ( wu[:wuattr_status].eql?(false) )
				wu={:uuid => uuid_out[:uuid], :wukey => wu[:wukey], :attrs => []}
				params=prepare_base_params()		
				@workunitattr_restapi="#{@optier_base_url}/eTransactionInstance/#{wu[:uuid]}/wu/#{wu[:wukey]}?tf=#{@time_frame}&#{@order_filters}"		
				result=server_rest_api(@workunitattr_restapi,params)
				resultp[:attributes]
				@output[:workUnits][:data][:not_expected_results].push(wu)	
				@output[:workUnits][:data][:failed_count]+=1
			else
				@output[:workUnits][:data][:expected_results].push(wu)	
				@output[:workUnits][:data][:success_count]+=1
			end
		end unless uuid_out[:workunits].nil?

	end

	# Check if exepcted attributes found on specific Tr and Wu
	def workUnitsAttributesAnalysis(entities,tr_uuid,wu_key)
		@wu_attr_result={:uuid => tr_uuid, :wukey => wu_key, :attrs => [], :success_count => 0, :failed_count => 0 }
		params=prepare_base_params()	
		@workunitattr_restapi="#{@optier_base_url}/eTransactionInstance/#{tr_uuid}/wu/#{wu_key}?tf=#{@time_frame}&#{@order_filters}"		
		result=server_rest_api(@workunitattr_restapi,params)		
	

		@found_attr=false	
		entities.each do |entity|							
			attrtype={:attrType => entity[:attrType], :attrs => [],:status => nil, :success_count => 0, :failed_count => 0}				
			attributes=[]			
			result[:attributes].each do |res|						
				@found_attr=false					
				if ! res[0][entity[:attrType]].nil?
					entity[:attrs].each do |k,v|
        				if ( ( res[1].has_key?(k)) && (( v == "key_only") || (res[1][k].eql?(v) ) ))               			
							attrtype[:status]=true
							attrtype[:success_count]+=1						
							@found_attr=true																													
							actual=(v.eql?("key_only")) ? "found" : res[1][k]								
						else			
							@found_attr=false						
							attrtype[:failed_count]+=1
							attrtype[:status]=false							
							actual=(v.eql?("key_only")) ? "not_found" : res[1][k]							
						end				
						attrtype[:attrs].push({:param=> k, :expected_value=> v, :actual_value=> actual})						
					end											
					@wu_attr_result[:attrs].push(attrtype)
				end
			end unless result[:attributes].nil?
			@wu_attr_result[:status]=attrtype[:status]
			@wu_attr_result[:success_count]+=attrtype[:success_count]
			@wu_attr_result[:failed_count]+=attrtype[:failed_count]
			break if @found_attr	
		end
		return @wu_attr_result
	end

	def generate_expected(application,server_host,tf_start,tf_end)
                data=[]
                tf_start=tf_start.to_i*1000
                tf_end=tf_end.to_i*1000

                # prepare time frames
                @time_frame="#{tf_start}-#{tf_end}"
                @tf_start_date=Time.at(tf_start.to_i/1000)
                @tf_end_date=Time.at(tf_end.to_i/1000)


                # prepare Server rest api
                @restuser="optier"
                @restpass="123"
                if ( server_host.include?(":") )
                        @server_host=server_host.split(':')[0]
                        @server_port=server_host.split(':')[1]
                else
                        @server_host=server_host

                        @server_port=8082
                end
                @optier_base_url = "http://#{@server_host}:#{@server_port}/ng-ui/entity"
                @order_filters = "trxSort=startTime&trxSortOrder=asc"
                @wu_filters = "pageSort=startTime&pageSortOrder=desc"
                @pages_restapi="#{@optier_base_url}/ePageInstance?tf=#{@time_frame}&#{@wu_filters}"
                @transaction_restapi="#{@optier_base_url}/eTransactionInstance?tf=#{@time_frame}&#{@order_filters}"

                baseparams=add_params(Hash.new,"application",application)
                tr_uuids=[]
                pg_result=server_rest_api(@pages_restapi,baseparams)
                pg_result.each do |page|
                        params=Hash.new
                        baseparams=add_params(Hash.new,"application",application)
                        params=add_params(baseparams,"pageId",page[:pageId])
                        trs_entry={ "pageInstance" => { "name": page[:name] }, "transactionInstances" => [] }
                        tr_result=server_rest_api(@transaction_restapi,params)
                        tr_result.each do |tran|
                                tr_uuids.push(tran[:uuid])
                                tr_entry={"transactionInstance" => { "name" => tran[:name] }, "workUnits" => []}
                                @workunit_restapi="#{@optier_base_url}/eTransactionInstance/#{tran[:uuid]}/wu?tf=#{@time_frame}&#{@order_filters}&#{@wu_filters}"
                                wu_result=server_rest_api(@workunit_restapi,baseparams)
                                wu_result.each do |wu|
                                        wu_entry={"invokingTier" => wu[:invokingTier], "executingTier" => wu[:executingTier], "rawProtocol" => wu[:rawProtocol]}
                                        tr_entry["workUnits"].push(wu_entry)
                                end
                                trs_entry["transactionInstances"].push(tr_entry)
                        end unless tr_result.nil?
                        data.push(trs_entry)
                end unless pg_result.nil?

                baseparams=add_params(Hash.new,"application",application)
                tr_result=server_rest_api(@transaction_restapi,baseparams)
                tr_result_none_pages=tr_result.select { |tr| ! tr_uuids.include?(tr[:uuid]) } if ! tr_result.nil?
                tr_result_none_pages.each do |tran|
                        tr_entry={"transactionInstance" => { "name" => tran[:name] }, "workUnits" => []}
                        @workunit_restapi="#{@optier_base_url}/eTransactionInstance/#{tran[:uuid]}/wu?tf=#{@time_frame}&#{@order_filters}&#{@wu_filters}"
                        wu_result=server_rest_api(@workunit_restapi,baseparams)
                        wu_result.each do |wu|
                                wu_entry={"invokingTier" => wu[:invokingTier], "executingTier" => wu[:executingTier], "rawProtocol" => wu[:rawProtocol]}
                                tr_entry["workUnits"].push(wu_entry)
                        end     unless wu_result.nil?
                        data.push(tr_entry)
                end unless tr_result_none_pages.nil?
                return data
        end
end
