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

unset LC_CTYPE

#VERSIONS="REL_14_5 REL_14_2 REL_13_6 REL_12_0 REL_12_10 REL_11_15 REL_14_STABLE REL_13_STABLE"

VERSIONS="REL_15_1 REL_14_5 REL_14_2 REL_13_6 REL_12_0 REL_12_10"
POSTGRES_GIT="https://github.com/postgres/postgres.git"
BASEDIR=$(dirname $(readlink -f $0))

BUILD_OPTIONS_DEBUG="--with-openssl --with-readline --with-zlib --with-libxml --enable-cassert --enable-debug"
BUILD_OPTIONS_RELEASE="--with-openssl --with-readline --with-zlib --with-libxml"

# -O0 can be replaced by -Og to preserve optimizations
CFLAGS_DEBUG="-ggdb -O0 -g3 -fno-omit-frame-pointer"
CFLAGS_RELEASE=""

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
git fetch --tags
cd ..

for version in $VERSIONS; do

   for build_type in DEBUG RELEASE; do
      echo "**************************"
      echo "Building $version $build_type"
      echo "**************************"

      dest_dir=${version}_${build_type}
      if [ -d $dest_dir ]; then
         echo "Version $version ($build_type) already exists, skipping"
         continue
      fi

      git clone postgres.git $dest_dir
      cd $dest_dir
      git checkout $version

      prefix="$BASEDIR/bin/$dest_dir"
      echo "Prefix is: $dest_dir"

      if [ "$build_type" = "RELEASE" ]; then
         echo "Using (Build: $BUILD_OPTIONS_RELEASE) (CFlags: $CFLAGS_RELEASE)"
         ./configure --prefix=$prefix $BUILD_OPTIONS_RELEASE CFLAGS="$CFLAGS_RELEASE"
      else
         echo "Using (Build: $BUILD_OPTIONS_DEBUG) (CFlags: $CFLAGS_DEBUG)"
         ./configure --prefix=$prefix $BUILD_OPTIONS_DEBUG CFLAGS="$CFLAGS_DEBUG"
      fi

      make -j $MAKE_JOBS
      make -j $MAKE_JOBS -C src/test/isolation
      make -j $MAKE_JOBS -C contrib/postgres_fdw
 
      make install
      make -C contrib/postgres_fdw install

      datadir=$BASEDIR/data/$dest_dir
      if [ ! -d $datadir ]; then 
          echo "Datadir $datadir for version $dest_dir does not exist, creating..."
          mkdir -p $datadir
          $prefix/bin/initdb -D $datadir
      fi

      cd ..
   done
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

