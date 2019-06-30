#!/bin/bash
STARTUP_LOG=/tmp/startup.log
export http_proxy=http://proxy.wdf.sap.corp:8080
export https_proxy=http://proxy.wdf.sap.corp:8080
export MONGO_TRUNK=$MONGO_TRUNK
ruby app.rb  >> $STARTUP_LOG 2>&1
