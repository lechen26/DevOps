require 'sinatra'
require 'sinatra/json'
require 'sinatra/partial'
require 'httparty'
require "sinatra/config_file"
require 'mongoid'
require 'json'
require 'diffy'
require './classes/PageInstances'
require './classes/Analysis'
require './classes/Tests'
require './classes/TestsJsons'
require './classes/Executions'
require './classes/TransactionInstances'
require './classes/WorkUnits'
require './classes/WorkUnitsAttr'
require './classes/Nightly'
require './classes/UANightly'
require './classes/Latest'
require './RestParser'
require './AnalysisService'
require 'json-schema'
require 'active_support/time'

class ReportService < Sinatra::Base
	register Sinatra::Partial
		set :bind, '0.0.0.0'
		set :raise_sinatra_param_exceptions, true
	
	register Sinatra::ConfigFile	
		config_file './config.yml'

	Mongoid.load!('./mongoid.yml', environment=ENV["MONGO_ENV"])	
	HTTParty::Basement.default_options.update(verify: false)
 	parser = AnalysisService.new 	
 	

	###############################################
	# Helper method 
	# calculating properties for dashboard widgets
	###############################################
	def widgets
	   # Total tests widget
	  @analysis_total_count=Analysis.all.count
	  @weekly_analyzers_count=Analysis.between(timestamp: (7.days.ago..Time.now)).count	 
	  # Total Pages widget
	  @pages_total_count=PageInstances.where(:total_count.ne => nil).pluck(:total_count).sum	  
	  @pages_failed_count=PageInstances.where(:failed_count.ne => nil).pluck(:failed_count).sum  
	  # Total Transactions widget
	  @trans_total_count=TransactionInstances.where(:total_count.ne => nil).pluck(:total_count).sum	  
	  @trans_failed_count=TransactionInstances.where(:failed_count.ne => nil).pluck(:failed_count).sum
	  # Total WorkUnits widget
	  @wu_total_count=WorkUnits.where(:total_count.ne => nil).pluck(:total_count).sum 
	  @wu_failed_count=WorkUnits.where(:failed_count.ne => nil).pluck(:failed_count).sum
	  # Total WorkUnits Attributes widget
	  @wuattr_total_count=WorkUnitsAttr.where(:total_count.ne => nil).pluck(:total_count).sum 
	  @wuattr_failed_count=WorkUnitsAttr.where(:failed_count.ne => nil).pluck(:failed_count).sum
	end

	###############################################
	# GET
	# root redirects to list_tests
	###############################################
	get '/' do
		redirect '/list_tests'
	end

	###############################################
	# GET
	# show dashboard widgets and graphs
	###############################################
	get '/dashboard' do
		content_type :html
		widgets()	
		@analysis=Analysis.order(:timestamp => 'desc')
		@executions=Executions.order(:tf_start => 'desc')	
		erb(:dashboard)
	end
	
	get '/latest' do
                content_type :html
	        @latest_analysis_total=Latest.between(timestamp: (1.days.ago..Time.now)).order(:environment => 'desc', :success_rate => 'asc')
                @analysis_latest=@latest_analysis_total.group_by { |x| x[:environment] }
                erb :latest
        end

	get '/remove_old_data' do
		content_type :html
		Executions.where(:tf_start.lt => 60.days.ago).delete
		Analysis.where(:tf_start.lt => 60.days.ago).delete
		TransactionInstances.where(:tf_start.lt => 60.days.ago).delete
		PageInstances.where(:tf_start.lt => 60.days.ago).delete
		WorkUnits.where(:tf_start.lt => 60.days.ago).delete
		WorkUnitsAttr.where(:tf_start.lt => 60.days.ago).delete	
		erb :remove_old_data
	end

	get '/nightly' do
		content_type :html		
		@nightly_analysis_total=Nightly.order(:environment => 'desc', :success_rate => 'asc')
		@analysis_nightly=@nightly_analysis_total.group_by { |x| x[:environment] }
		if params[:service]
			erb :nightly_service, :layout => false	if params[:service]
		else
			erb :nightly
		end
	end


    get '/uanightly' do
		content_type :html
		@ua_nightly_total=UANightly.order(:environment => 'desc', :execution_status => 'asc')
		@ua_nightly=@ua_nightly_total.group_by { |x| x[:environment] }
		if params[:service]
			erb :uanightly_service, :layout => false	if params[:service]
		else
			erb :uanightly
		end
	end

	#############
	# Analysis
	#############

	###############################################
	# GET 
	# list all existing analysis
	###############################################
	get '/list_analysis' do
	  content_type :html  
	  widgets()	
	  mongo_query=Hash.new
	  mongo_query[:test_name]=params['test_name'] unless params['test_name'].nil?
	  mongo_query[:analysis_id]=params['analysis_id'] unless params['analysis_id'].nil?
	  mongo_query[:server_host]=params['server_host'] unless params['server_host'].nil?
	  mongo_query[:tf_start]={ :$gte => Time.at(params['tf_start'].to_i/1000) }  unless params['tf_start'].nil?
	  mongo_query[:tf_end]={ :$lte => Time.at(params['tf_end'].to_i/1000) }  unless params['tf_end'].nil?	 
	  mongo_query.any? ? @analysis=Analysis.where(mongo_query) : @analysis=Analysis.all
	  @analysis=@analysis.order(:tf_start => 'desc')	  	 
	  erb(:analysis)
	end

	###############################################
	# GET 
	# form to search analyzer based on criteria
	###############################################
	get '/analysis_search' do
		content_type :html  	
		widgets()	
		erb(:analysis_search)
	end	

	###############################################
	# GET 
	# form with tests list to trigger analysis 
	###############################################
	get '/trigger_analysis_form' do
		content_type :html
		  @tests=Tests.all()	
		erb(:trigger_analysis)		
	end

	get '/last_execution' do
		content_type :html  	
		test_name=params[:test_name]
		env=params[:environment]
		executions=Executions.where({:test_name => test_name, :environment => env})
		@execution=executions.order(:tf_start => 'desc')[0] unless executions.nil?			
		erb(:trigger_analysis_form)
	end

	###############################################
	# GET 
	# trigger analysis by test name
	# get tf_start,tf_end,apm_server from last execution
	###############################################
	get '/trigger_analysis' do		
		widgets()
		test=Tests.find_by({:test_name => params[:test_name]})		
		execution_id=test[:last_execution_id] unless test.nil?				
		@execution=Executions.find_by({:execution_id => execution_id})			
		service=params[:service]
		erb(:analysis_form)		
	end



	###############################################
        # GET
        # trigger analysis by test name
        # get tf_start,tf_end,apm_server from last execution
        ###############################################
	get '/purge_nightly' do
		widgets()
		Nightly.delete_all()
		erb(:nightly)
	end


	###############################################
    # POST
    # add a test to the nightly collection
    ###############################################
	get '/add_to_ua_nightly' do
	    execution_id=params[:execution_id]
        execution=Executions.find_by(:execution_id => execution_id)
        current_test=UANightly.find_by({:test_name => execution[:test_name], :environment => execution[:environment]})
        if current_test.nil?
			puts "No existing test of #{execution[:test_name]} and #{execution[:environment]}"
			UANightly.create({:test_name => execution[:test_name], :environment => execution[:environment], :timestamp => execution[:timestamp], :execution_id => execution[:execution_id], :execution_status => execution[:status]}) if ! execution.nil?
		else
			puts "Update current execution"
			current_test.update!(timestamp: execution[:timestamp], execution_id: execution[:execution_id], execution_status: execution[:status])
		end

	end

	###############################################
	# POST 
	# add a test to the nightly collection
	###############################################
	get '/add_to_nightly' do		
		analysis_id=params[:analysis_id]
		execution_id=params[:execution_id]
		analysis=Analysis.find_by(:analysis_id => analysis_id)
		execution=Executions.find_by(:execution_id => execution_id)
		current_test=Nightly.find_by({:test_name => analysis[:test_name], :environment => analysis[:environment]})
		if current_test.nil?
			puts "No existing test of #{analysis[:test_name]} and #{analysis[:environment]}"
			Nightly.create({:analysis_id => analysis[:analysis_id], :test_name => analysis[:test_name], :environment => analysis[:environment], :success_rate => analysis[:success_rate], :timestamp => analysis[:timestamp], :execution_id => execution[:execution_id], :execution_status => execution[:status]}) if ! analysis.nil? && ! execution.nil?
		else
			puts "Update current execution"
			current_test.update!(analysis_id: analysis[:analysis_id], success_rate: analysis[:success_rate], timestamp: analysis[:timestamp], execution_id: execution[:execution_id], execution_status: execution[:status])
		end
	end

	###############################################
        # POST
        # add a test to the latest collection
        ###############################################
        get '/add_to_latest' do
                analysis_id=params[:analysis_id]
                execution_id=params[:execution_id]
                analysis=Analysis.find_by(:analysis_id => analysis_id)
                execution=Executions.find_by(:execution_id => execution_id)
                current_test=Latest.find_by({:test_name => analysis[:test_name], :environment => analysis[:environment]})
                if current_test.nil?
                        puts "No existing test of #{analysis[:test_name]} and #{analysis[:environment]}"
                        Latest.create({:analysis_id => analysis[:analysis_id], :test_name => analysis[:test_name], :environment => analysis[:environment], :success_rate => analysis[:success_rate], :timestamp => analysis[:timestamp], :execution_id => execution[:execution_id], :execution_status => execution[:status]}) if ! analysis.nil? && ! execution.nil?
                else
                        puts "Update current execution"
                        current_test.update!(analysis_id: analysis[:analysis_id], success_rate: analysis[:success_rate], timestamp: analysis[:timestamp], execution_id: execution[:execution_id], execution_status: execution[:status])
                end
        end

	#############
	# Execution
	#############

	###############################################
	# GET 
	# list all existing executions
	get '/list_executions' do
	  content_type :html  
	  widgets()	
	  mongo_query=Hash.new
	  mongo_query[:execution_id]=params['execution_id'] unless params['execution_id'].nil?	
	  mongo_query[:test_name]=params['test_name'] unless params['test_name'].nil?	
	  mongo_query[:apm_server]=params['apm_server'] unless params['apm_server'].nil?
	  mongo_query.any? ? @executions=Executions.where(mongo_query) : @executions=Executions.all	  	 	  
	  erb(:executions)
	end

	###############################################
	# GET 
	# form to search execution based on criteria
	###############################################
	get '/execution_search' do
		content_type :html  	
		widgets()	
		erb(:execution_search)
	end

	###############################################
	## POST
	## update excection
	###############################################
	get '/update_execution' do 
		content_type :html	
		execution_id=params[:execution_id]
		status=params[:status]
		tf_end=(params[:tf_end].nil?) ? tf_end=nil  : tf_end=Time.at(params['tf_end'].to_i/1000)		
		execution=Executions.find_by({:execution_id => execution_id})		
		execution.update!(status: status, tf_end: tf_end) unless execution.nil?
	end

	###############################################
	# GET 
	# list all json tests from DB
	###############################################
	get '/list_tests' do
	  content_type :html  
	  widgets()	
	  @tests=Tests.all()	  
	  erb(:tests)
	end

	###############################################
	# GET 
	# new test form
	###############################################
	get '/test_form' do
		content_type :html  
		erb(:test_form)
	end

	###############################################
	# POST 
	# create a new test
	###############################################
	get '/create_test' do
		content_type :html  
		test_name=params[:test_name]
		type=params[:type]	
		check_test=Tests.find_by({:test_name => test_name})
		if ! check_test.nil?
			halt 200,  {"status": 500, "message": "Test with this name already exist"}.to_json
		end

		Tests.create({test_name: test_name, test_type: type, json_id: []})
		@test=Tests.find_by(:test_name => test_name)
		if @test 
			halt 200, {"status": 200, "message": "Success"}.to_json
		else
			halt 200,  {"status": 505, "message": "Faliure in creating test"}.to_json
		end
	end

	###############################################
	# GET 
	# form with tests list to trigger test 
	###############################################
	get '/trigger_test_form' do
		content_type :html		
		@test=Tests.find_by({:test_name => params[:test_name]})			
		erb(:trigger_test_form) if ! @test.nil?
	end

	get '/check_trigger' do
		content_type :html
		test_name=params['test_name']
		url="https://mo-70b603b3c.mo.sap.corp:8443/jenkins/job/checkTrigger/build?delay=0sec&token=CHECK"
		status_url="https://mo-70b603b3c.mo.sap.corp:8443/jenkins/job/checkTrigger/api/json"
		(1..10).each do |i|
			puts "About to execute test #{i}"
			response = HTTParty.get(url)
			if response.success?
				rs = HTTParty.get(status_url)			
				next_build=rs["lastBuild"]["number"]
				puts "Build_Number=#{next_build}"
			end		
		end
		erb(:no_test)
	end

	###############################################
	# POST 
	# trigger Test
	# operation will trigger jenkins job for specfic
	# type of test. (SAF/Selenium/TestApp)
	###############################################
	get '/trigger_test' do
		content_type :html			
		test_name=params['test_name']
		test=Tests.find_by({:test_name => test_name})		
		env=params[:environment]	
		test_type=test[:test_type]
		server=params[:server]
		application=params[:application]			
		execution_id=SecureRandom.uuid
		test.update!(last_execution_id: execution_id)
		tf_start=Time.now()	
		
		base_url=settings.jenkins_url + settings.triggerTestUrl	+ "&test_type=" + test_type + "&execution_id=" + execution_id + "&test_name=" + test_name + "&environment=" + env + "&server=" + server + "&application=" + application
		status_url=settings.jenkins_url + settings.statusTestUrl
		view_url=settings.jenkins_url + settings.viewTestUrl

		if test_type == "Selenium"
			selenium=params[:selenium]
			browser=params[:browser]
			scope=params[:scope]
			base_url=base_url + "&scope=" + scope +  "&seleniumenv=" + selenium + "&browser=" + browser
		end

		if params[:analysis]
			tf_start_int=tf_start.to_i*1000
			base_url=base_url + "&analysis=" + params[:analysis] + "&tf_start=" + tf_start_int.to_s
		end

		response = HTTParty.get(base_url)
		if response.success?														
			rs = HTTParty.get(status_url)			
			is_pending=rs["inQueue"]
			puts "is_pending=#{is_pending}"
			while is_pending do
				sleep 10
				rs = HTTParty.get(status_url)
				is_pending=rs["inQueue"]
				puts "is_pending=#{is_pending}"
			end
			next_build=rs["lastBuild"]["number"]	
			puts "XXXXXXXX   Build_Number=#{next_build} XXXXXXXXX"	
			output_url=view_url + "/" + next_build.to_s		
			@json_res={"status": 200, "url": output_url}		
			execution={:test_name => test_name, :environment => env, :application=> application, :execution_id => execution_id, :status => "Running", :tf_start => tf_start ,:tf_end => nil , :console_url => output_url , :apm_server => server}
			Executions.create(execution)	
			halt 200, @json_res.to_json					
		else		
			puts " XXXXXXX Wasnt able to trigger test XXXXXXX"	
			@json_res={"status": 500, "url": view_url} 
			halt 500, @json_res.to_json			
		end				
	end
	
	###############################################
	# GET 
	# get all tests jsons
	###############################################
	get '/get_test_jsons', :provides => :json do		
		content_type :html
		test_name=params['test_name']
		env=params['environment']
		@result=[]
		jsons=(env.nil?) ? TestsJsons.where({'json_content.testName': test_name}) : TestsJsons.where({'json_content.testName': test_name, 'json_content.environment': env})	
		jsons.each do |json|	
			@result.push({"json_id": json['json_id']})	
		end		
		halt 200, @result.to_json
	end

	###############################################
	# GET 
	# get all test envs
	###############################################
	get '/get_test_envs', :provides => :json do
		content_type :html
		puts "%%%%%%%%%%%%%%%%%%%%%%%%%%get env%%%%%%%%%%%"
		@result=[]
		jsons= TestsJsons.where({'json_content.testName': params['test_name']})
		jsons.each do |json|
			@result.push("environment": json['json_content.environment']) unless @result.include?("environment": json['json_content.environment'])
		end
		halt 200, @result.to_json
	end

	###############################################
	# GET 
	# view and edit test json
	###############################################
	get '/view_json' do
		content_type :html	
		@test_name=params['test_name']
		@env=params['environment'] if params.include?('environment')
		@json_id=params['json_id'] if params.include?('json_id')	 	 		  		
		@test=Tests.find_by({test_name: @test_name})
		if @test.nil?
			erb(:no_test)
		else
			json_env=@test[:json_id].find{|j| j['env']== @env } unless @test[:json_id].nil? || @env.nil?								
			@json_id=(@json_id.nil?) ? json_env['id'] : @json_id unless json_env.nil?			
			if @json_id.nil?	
					@testobj={"testName": @test_name, "environment": "","application": @test_name, "data": []}.to_json				
					@json_id=1
					@new_json=true															
			else			
				@json = TestsJsons.find_by({json_id: @json_id.to_i, 'json_content.testName': @test_name, 'json_content.environment': @env})
				@testobj = @json['json_content'].to_json if @json			
			end			

			test_id=@test[:json_id].find{|j| j['id'] == @json_id && j['env'] == @env } unless @test[:json_id].nil?
			(test_id['id'] == @json_id) ? @curr_id=nil : @curr_id=test_id['id']	unless test_id.nil?		
			erb(:view_json)
		end				
		
	end

	###############################################
	# GET 
	# list all jsons from DB	
	###############################################
	get '/list_jsons' do
	  content_type :html  
	  widgets()	
	  @tests=Tests.all()	  
	  @jsons=TestsJsons.find_by({:test_name => params['test_name']}) unless params['test_name'].nil?	
	  erb(:test_jsons)
	end

	###############################################
	# GET 
	# compare jsons
	###############################################
	get '/compare_jsons' do
		content_type :html	
		@test_name=params['test_name']	
		@json_id1=params['json_id1']		
		@json_id2=params['json_id2']

		@json1 = TestsJsons.find_by({json_id: @json_id1.to_i, 'json_content.testName': @test_name})
		@testobj1 = @json1['json_content'].to_json if @json1		
		@json2 = TestsJsons.find_by({json_id: @json_id2.to_i, 'json_content.testName': @test_name})
		@testobj2 = @json2['json_content'].to_json if @json2				
		erb(:compare_jsons)
	end

	###############################################
	# POST 
	# update test_json
	###############################################
	post '/update_json' , :provides => :json do
		content_type :html	
		payload = JSON.parse(request.body.read.to_s)
		newid=false
		found=TestsJsons.find_by({json_content: JSON.parse(payload['test_json'])})		
		puts found.to_json
		if found.nil?			
			num_of_jsons=TestsJsons.where({"json_content.testName": payload['test_name'],"json_content.environment": payload['env']}).pluck(:json_id).count			
			(num_of_jsons.nil?) ? nextid=1 : nextid=num_of_jsons + 1				
			TestsJsons.create(json_content: JSON.parse(payload['test_json']),json_id: nextid)					
			@json_res={"new": true, "json_id": nextid}
		
			if (nextid == 1)	
				Tests.where({:test_name => payload['test_name']}).push({:json_id => { "env" => payload['env'] , "id" => nextid }})				
			else
				Tests.where({:test_name => payload['test_name']}).elem_match(json_id: { env: payload['env']}).update("$set" => {"json_id.$.id" => nextid})				
			end	
		else			
			nextid=found['json_id'].to_s			
			@json_res={"new": false, "json_id": nextid	}				
			if (nextid == 1)			
				Tests.where({:test_name => payload['test_name']}).add_to_set({:json_id => { "env" => payload['env'] , "id" => nextid }})				
			else
				Tests.where({:test_name => payload['test_name']}).elem_match(json_id: { env: payload['env']}).update("$set" => {"json_id.$.id" => nextid})				
			end	
		end
		halt 200, @json_res.to_json		
	end

	###############################################
	# GET 
	# generate json data based on last execution 
	###############################################
	get '/generate_json' do
		content_type :html
		@test_name=params[:test_name]
		@environment=params[:environment]
		test=Tests.find_by({:test_name => @test_name})	
		#execution_id=test[:last_execution_id] unless test.nil?	

		executions=Executions.where({:test_name => @test_name, :environment => @environment})
		@execution=executions.order(:tf_start => 'desc')[0] unless executions.nil?			
		
		if @execution.nil?			
			@json_res={ "status": 201, "comment": "There is no execution for this test" }			
			halt 200, @json_res.to_json
		end
		data=parser.generate_expected(@execution[:application],@execution[:apm_server],@execution[:tf_start],@execution[:tf_end])
		@testobj={"testName": @test_name, "application": @execution[:application], "environment": @environment, "data": data}.to_json		
		
		@json_id=test[:json_id].find{|j| j['env']== @environment }['id'] unless test.nil? || test[:json_id].empty?						
		@json = TestsJsons.find_by({json_id: @json_id.to_i, 'json_content.testName': @test_name, 'json_content.environment': @environment})		
		if @json.nil?	
			puts "json is null"
			@json_id=1
			@new_json=true		
		end	
		@json_res={ "status": 200, "data": JSON.pretty_generate(JSON.parse(@testobj)), "comment": "Data generated" }		
		halt 200, @json_res.to_json
	end

	###############################################
	# GET 
	# show full report based on analysis_id
	###############################################
	get '/generate_report' do		
		content_type :html	
		widgets()
		@analysis_id=params['analysis_id']		
		if ! @analysis_id.nil?
			@analysis=Analysis.find_by({ analysis_id: @analysis_id})			
			@pages=PageInstances.find_by({ analysis_id: @analysis_id})
	    	@trans=TransactionInstances.find_by({ analysis_id: @analysis_id})	    		
	    	@workunits=WorkUnits.find_by({ analysis_id: @analysis_id})	    	
	    	@workunitsattr=WorkUnitsAttr.find_by({ analysis_id: @analysis_id})	   	    	    	
	    	@test=Tests.find_by({ test_name: @analysis[:test_name]}) if ! @analysis.nil?	
	    	test_id=@test[:json_id].find{|j| j['env'] == @analysis['environment'] } unless @test[:json_id].nil?	    	
			(test_id['id'].to_i == @analysis['json_id'].to_i) ? @curr_id=nil : @curr_id=test_id['id']	unless test_id.nil?					
			#test_id=@test[:json_id]
	    end	    
	    erb(:report)	 
	end

	###############################################
	# GET 
	# Rest service for analyzing test from server
	# required: test_name, test_json, server,
	# server_tf_start,server_tf_end	
	###############################################
	get '/service' do	
 		content_type :html
 		rates=[] 		
 		@test_name=params[:test_name] 	
 		@env=params[:environment] 		 	
		test = Tests.find_by({ test_name: @test_name})	
		@json_id=test[:json_id].find{|j| j['env']== @env }['id'] unless test.nil?				
		
		json=TestsJsons.find_by({json_id: @json_id, 'json_content.testName': @test_name,'json_content.environment': @env}) 		
		if json										
			@test=parser.init(@test_name,json,params[:server],params[:tf_start],params[:tf_end])
			@testname=@test[:test_name]
			@application=@test[:application]
			@analysis=parser.parse_test()				
			test.update!(last_analysis_id: @analysis[:analysis_id])

			# Process pages status			
			@pages=parser.parse_test_entity("pageInstances")											
			puts "PAGES=#{@pages}"
			rates.push(@pages[:success_rate]) if ! @pages.nil? && @pages[:total_count].nonzero?			
						
			# # Process transaction status			
			@trans=parser.parse_test_entity("transactionInstances")						
			rates.push(@trans[:success_rate]) if ! @trans.nil?
			rates.push(@trans[:dimensions][:success_rate]) if ! @trans.nil? && (! @trans[:dimensions].nil? && @trans[:dimensions][:total_count].nonzero?)
			
			# Process workunits status			
			@workunits=parser.parse_test_entity("workUnits")					
			rates.push(@workunits[:success_rate]) if ! @workunits.nil?
			

			#Process workunits attributes status			
			@workunitsattr=parser.parse_test_entity("workUnitAttributes")						
			rates.push(@workunitsattr[:success_rate]) if ! @workunitsattr.nil? && @workunitsattr[:total_count].nonzero?			

			# Calculate total success rate for test
			@test_rate= rates.empty? ? 0 : (rates.sum / rates.length).round(2)
		
			@analysis[:success_rate] = @test_rate
			@json_res={"status": "200", "json_id": json['json_id'],"id": @analysis[:analysis_id]} 	
			
			#Write data to mongo				
			Analysis.create(@analysis)			
			PageInstances.create(@pages)
			TransactionInstances.create(@trans)
			WorkUnits.create(@workunits)
			WorkUnitsAttr.create(@workunitsattr)			

			#add test to latest
			analysis=Analysis.find_by(:analysis_id => test[:last_analysis_id])
                	execution=Executions.find_by(:execution_id => test[:last_execution_id])
                	current_test=Latest.find_by({:test_name => analysis[:test_name], :environment => analysis[:environment]})	
                	if current_test.nil?
                        	Latest.create({:analysis_id => analysis[:analysis_id], :test_name => analysis[:test_name], :environment => analysis[:environment], :success_rate => analysis[:success_rate], :timestamp => analysis[:timestamp], :execution_id => execution[:execution_id], :execution_status => execution[:status]}) if ! analysis.nil? && ! execution.nil?
                	else
                        	current_test.update!(analysis_id: analysis[:analysis_id], success_rate: analysis[:success_rate], timestamp: analysis[:timestamp], execution_id: execution[:execution_id], execution_status: execution[:status])
               		end

			erb :service, :layout => false	if params[:service]			
			halt 200, @json_res.to_json
		else	
			erb :no_test, :layout => false	if params[:service]			
			halt 200, {"status": "500"}.to_json
		end
	end
end
ReportService.run!



