#!/bin/bash
#
# This scripts downloads and compiles multiple PostgreSQL 
# version. 
#
# Example:
# ./postgres-sandbox.sh postgres_install
# ./postgres-sandbox.sh postgres_start REL_14_2
# ./postgres-sandbox.sh postgres_stop REL_14_2 
#
#########################################################

set -e

VERSIONS="REL_14_2 REL_13_6 REL_12_0 REL_12_10 REL_11_15 REL_14_STABLE REL_13_STABLE"
POSTGRES_GIT="https://github.com/postgres/postgres.git"
BASEDIR=$(dirname $(readlink -f $0))
BUILD_OPTIONS="--with-openssl --with-readline --with-zlib --with-libxml --enable-cassert --enable-debug"
CFLAGS="-ggdb -O0 -g3 -fno-omit-frame-pointer"
# -O0 can be replaced by -Og to preserve optimizations
MAKE_JOBS=8

cd $BASEDIR

echo "Welcome to the Postgres sandbox for $BASEDIR"

if [ ! -d src ]; then
   echo "Source directory does not exist, please create by executing: mkdir src"
   exit 1
fi

cd src

###
# Install postgreSQL
###
postgres_install() {
if [ ! -d postgres.git ]; then
   echo "Git repository not found"
   git clone --bare $POSTGRES_GIT

   echo "Install build dependencies"
   sudo apt-get -y build-dep postgresql
fi

cd postgres.git
git fetch $POSTGRES_GIT
cd ..

for version in $VERSIONS; do
   echo "**************************"
   echo "Building $version"
   echo "**************************"

   if [ -d $version ]; then
      echo "Version $version already exists, skipping"
      continue
   fi

   git clone postgres.git $version 
   cd $version
   git checkout $version

   prefix="$BASEDIR/bin/$version"
   echo "Prefix is: $prefix"

   ./configure --prefix=$prefix $BUILD_OPTIONS CFLAGS="$CFLAGS"

   make -j $MAKE_JOBS
   make -j $MAKE_JOBS -C src/test/isolation
   make -j $MAKE_JOBS -C contrib/postgres_fdw
 
   make install
   make -C contrib/postgres_fdw install

   datadir=$BASEDIR/data/$version
   if [ ! -d $datadir ]; then 
       echo "Datadir $datadir for version $version does not exist, creating..."
       mkdir -p $datadir
       $prefix/bin/initdb -D $datadir
   fi

   cd ..
done
}

###
# Start postgres with the given version
###
postgres_start() {
   if [ -z "$1" ]; then
      echo "Error: PostgreSQL version not specified!"
      exit 1
   fi

   version=$1

   echo "Starting PostgreSQL version $version"
   $BASEDIR/bin/$version/bin/pg_ctl -D $BASEDIR/data/$version -l $BASEDIR/logfile_$version start
}

###
# Stop postgres with the given version
###
postgres_stop() {
   if [ -z "$1" ]; then
      echo "Error: PostgreSQL version not specified!"
      exit 1
   fi

   version=$1

   echo "Starting PostgreSQL version $version"
   $BASEDIR/bin/$version/bin/pg_ctl -D $BASEDIR/data/$version -l $BASEDIR/logfile_$version stop
}

case "$1" in
postgres_install)
	postgres_install
;;
postgres_start)
	postgres_start $2
;;
postgres_stop)
	postgres_stop $2
;;
postgres_restart)
	postgres_stop $2
	postgres_start $2
;;
*)
   echo "Usage: $0 {postgres_install | postgres_start | postgres_stop | postgres_restart}"
   ;;  
esac

exit 0

