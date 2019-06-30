#!/bin/sh
BASE=$(dirname "$0")
ZK_UTIL=${BASE}/zk_util
LOG=${BASE}/util.log



#---------------------------------------------------------------------------------------------
# Check if solr collection exist on the ZK
#---------------------------------------------------------------------------------------------
is_collection_exist() {
	ZK_URL=$1
	COLLECTION=$2
	${ZK_UTIL}/zkcli.sh -zkhost ${ZK_URL} -cmd get /collections/${COLLECTION} > collection_info 2> ${LOG}
	IS_EXIST=`cat collection_info |wc -l `
	if [ ${IS_EXIST} -gt 0 ];then
		return 0
	fi
	return 1
}


#---------------------------------------------------------------------------------------------
# get nodes from base collection (for collection creation purposes
#---------------------------------------------------------------------------------------------
get_nodes_from_base() {
	local ZK_URL=$1
	local COLLECTION=$2

	${ZK_UTIL}/zkcli.sh -zkhost ${ZK_URL} -cmd getfile /collections/${COLLECTION}/state.json zkinfo > /dev/null 2>&1
	NODES=`cat zkinfo | ${ZK_UTIL}/jq ".[].shards[].replicas[] | .base_url" |tr -d '"'`
	echo ${NODES}
}

#---------------------------------------------------------------------------------------------
# create collection
#---------------------------------------------------------------------------------------------
create_collection() {
	local ZK_URL=$1
	local COLLECTION=$2
	local SOURCE_DIR=$3
	local BASE_COLLECTION=$4
	local REPLICAS=$5

	# get nodes from base collection
	echo "Get nodes from base collection for creation"
	get_nodes_from_base $ZK_URL $BASE_COLLECTION > nodes 

	# update ZK configuration with sources from server
	echo "create ZK configuration for collection"
	${ZK_UTIL}/zkcli.sh -cmd upconfig -zkhost ${ZK_URL} -confname ${COLLECTION} -confdir ${SOURCE_DIR}  >> ${LOG} 2>&1
        if [ $? != 0 ];then
                echo "Upload changes to ${COLLECTION} configuraiton to ZK - Failed"
                exit 1
        else
                echo "Upload changes to ${COLLECTION} configuraiton to ZK - OK"
        fi

	# create collection
	echo "Create collection"
	node=`cat nodes | awk '{print$1}'`
	echo "CMD: ${node}/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=${REPLICAS}"
	curl "${node}/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=${REPLICAS}" >> ${LOG} 2>&1
}
	

#---------------------------------------------------------------------------------------------
# create collection on specific node
#---------------------------------------------------------------------------------------------
create_collection_on_node() {
        local ZK_URL=$1
        local COLLECTION=$2
        local SOURCE_DIR=$3
        local NODE=$4
        local REPLICAS=$5

        # update ZK configuration with sources from server
        echo "create ZK configuration for collection"
        ${ZK_UTIL}/zkcli.sh -cmd upconfig -zkhost ${ZK_URL} -confname ${COLLECTION} -confdir ${SOURCE_DIR}  >> ${LOG} 2>&1
        if [ $? != 0 ];then
                echo "Upload changes to ${COLLECTION} configuraiton to ZK - Failed"
                exit 1
        else
                echo "Upload changes to ${COLLECTION} configuraiton to ZK - OK"
        fi

        # create collection
        echo "Create collection"
        echo "CMD: ${NODE}/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=${REPLICAS}"
        curl --noproxy '*' "${NODE}/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=${REPLICAS}" >> ${LOG} 2>&1
}

create_first_collection() {
	local ZK_URL=$1
        local SOURCE_DIR=$2
	local COLLECTION=$3
	local NODES=$4

        ${ZK_UTIL}/zkcli.sh -cmd upconfig -zkhost ${ZK_URL} -confname ${COLLECTION} -confdir ${SOURCE_DIR}  >> ${LOG} 2>&1
        if [ $? != 0 ];then
                echo "Upload changes to ${COLLECTION} configuraiton to ZK - Failed"
                exit 1
        else
                echo "Upload changes to ${COLLECTION} configuraiton to ZK - OK"
        fi

	 # create collection
        echo "Create collection"
        echo "CMD: ${NODE}/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=${REPLICAS}"
        curl --noproxy '*' "${NODE}/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=${REPLICAS}" >> ${LOG} 2>&1
 }
#---------------------------------------------------------------------------------------------
# delete collection
#---------------------------------------------------------------------------------------------
delete_collection() {
	local ZK_URL=$1
	local COLLECTION=$2

        # get nodes from collection
        echo "Get nodes from collection"
        get_nodes_from_base $ZK_URL $COLLECTION > nodes

	node=`cat nodes | awk '{print$1}'`
	echo "CMD: ${node}/admin/collections?action=DELETE&name=${COLLECTION}"
	curl --noproxy '*' "${node}/admin/collections?action=DELETE&name=${COLLECTION}" >> ${LOG} 2>&1
}

#---------------------------------------------------------------------------------------------
# Get ZooKeeper Urls, collection name and source configuration dir to update zk from
#---------------------------------------------------------------------------------------------
update_zk_config()
{
	ZK_URL=$1
	COLLECTION=$2
	SOURCE_DIR=$3

	# Get Configuration name
	${ZK_UTIL}/zkcli.sh -zkhost ${ZK_URL} -cmd get /collections/${COLLECTION} > collection_info 2> ${LOG}
	CONF_NAME=`cat collection_info |awk -F: '{print$2}' |tr -d '"' | tr -d '}'`
	CONF_DIR="${CONF_NAME}_dir"

	# Download current config
	${ZK_UTIL}/zkcli.sh -cmd downconfig -zkhost ${ZK_URL} -confname ${CONF_NAME} -confdir ${CONF_DIR}  >> ${LOG} 2>&1
	if [ $? != 0 ];then
       		echo "Downloading ${CONF_NAME} configuration from ZK - Failed"
        	exit 1
	else
        	echo "Downloading ${CONF_NAME} configuration from ZK - OK"
	fi

	# Copy current Schema.xml from server artifact to downloaded confdir
	cp ${SOURCE_DIR}/schema.xml  ${CONF_DIR}/ >> ${LOG} 2>&1
	if [ $? != 0 ];then
        	echo "Overwrite schema.xml with new content - Failed"
        	exit 1
	else
        	echo "Overwrite schema.xml with new content - OK"
	fi
	
	# Copy current solrconfig.xml from server artifact to downloaded confdir
	cp ${SOURCE_DIR}/solrconfig.xml  ${CONF_DIR}/ >> ${LOG} 2>&1
	if [ $? != 0 ];then
                echo "Overwrite solrconfig.xml with new content - Failed"
                exit 1
        else
                echo "Overwrite solrconfig.xml with new content - OK"
        fi

	# Upload changes to ZK
	${ZK_UTIL}/zkcli.sh -cmd upconfig -zkhost ${ZK_URL} -confname ${CONF_NAME} -confdir ${CONF_DIR} >> ${LOG} 2>&1
	if [ $? != 0 ];then
     		echo "Upload changes to ${CONF_NAME} configuraiton to ZK - Failed"
       		exit 1
	else
      		echo "Upload changes to ${CONF_NAME} configuraiton to ZK - OK"
	fi
}

#-------------------------------------------------------------------------------------
# Get ZooKeeper URLS and collection name and reload all releavnt solr cores
#-------------------------------------------------------------------------------------
restart_nodes() 
{
	ZK_URL=$1
        COLLECTION=$2

	echo "Get Solr nodes information"
	rm -f zkinfo
        ${ZK_UTIL}/zkcli.sh -zkhost ${ZK_URL} -cmd getfile /collections/${COLLECTION}/state.json zkinfo > /dev/null 2>&1
        NODES=`cat zkinfo | ${ZK_UTIL}/jq ".[].shards[].replicas[] | .base_url + \"=\" + .core "`

	for node in `echo ${NODES}`
	do
		NODE_URL=`echo ${node} | tr -d '"' |awk -F= '{print$1}'`
		NODE_CORE=`echo ${node} | tr -d '"' |awk -F= '{print$2}'`
		echo "Found ${NODE_URL} with core ${NODE_CORE}"
		curl "${NODE_URL}/admin/cores?action=reload&core=${NODE_CORE}" >> ${LOG} 2>&1
		if [ $? != 0 ];then
	        	echo "Reload core ${NODE_CORE} - Failed"
     			exit 1
		else
      			echo "Reload core ${NODE_CORE} - OK"
		fi
	done
}
