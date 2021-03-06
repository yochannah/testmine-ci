#!/bin/bash

set -e

export MINE=biotestmine
# Use the biotestmine lite dataset instead of the full.
export LITE=true

SCRIPT_DIR=`pwd`/scripts
CONFIG_DIR=`pwd`/config/biotestmine

if [ -z $(which wget) ]; then
    # use curl
    GET='curl'
else
    GET='wget -O -'
fi

cd $HOME

# Pull in the server code.
git clone --single-branch --branch 'master' --depth 1 https://github.com/intermine/biotestmine.git biotestmine

export PSQL_USER=postgres

# Set up properties
PROPDIR=$HOME/.intermine
TESTMODEL_PROPS=$PROPDIR/biotestmine.properties
SED_SCRIPT='s/PSQL_USER/postgres/'

mkdir -p $PROPDIR

echo "#--- creating $TESTMODEL_PROPS"
cp biotestmine/data/biotestmine.properties $TESTMODEL_PROPS
sed -i -e $SED_SCRIPT $TESTMODEL_PROPS

# Initialise solr
echo '#---> Setting up solr search'
$SCRIPT_DIR/init-solr.sh

echo '#---> Setting up perl dependencies'
$SCRIPT_DIR/init-perl.sh

# Copy CI-specific config
cp $CONFIG_DIR/* biotestmine/

# We will need a fully operational web-application
echo '#---> Building and releasing web application to test against'
(cd biotestmine && ./setup.sh) &
# Gradle doesn't actually finish executing, so we daemonize it, wait and pray
# that it finishes in time.
sleep 600

# Warm up the keyword search by requesting results, but ignoring the results
$GET "http://localhost:8080/biotestmine/service/search" > /dev/null
# Start any list upgrades
$GET "http://localhost:8080/biotestmine/service/lists" > /dev/null
