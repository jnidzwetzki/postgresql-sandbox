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

#VERSIONS="REL_15_1 REL_14_5 REL_14_2 REL_13_6 REL_12_0 REL_12_10"
VERSIONS="REL_15_1" # REL_14_2 REL_14_9 REL_15_1"

POSTGRES_GIT="https://github.com/postgres/postgres.git"
BASEDIR=$(dirname $(readlink -f $0))

BUILD_OPTIONS_SANITIZE="--with-openssl --with-readline --with-zlib --with-libxml --enable-cassert --enable-debug --enable-dtrace "
BUILD_OPTIONS_DEBUG="--with-openssl --with-readline --with-zlib --with-libxml --enable-cassert --enable-debug --enable-dtrace --with-llvm"
BUILD_OPTIONS_RELEASE="--with-openssl --with-readline --with-zlib --with-libxml --with-llvm"

# CFlags
CFLAGS_SANITIZE="-g -fsanitize=address,undefined -fno-omit-frame-pointer -O1 -fno-inline"
CFLAGS_DEBUG="-ggdb -O0 -g3 -fno-omit-frame-pointer"
CFLAGS_RELEASE="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -fno-omit-frame-pointer" # Debian values

# LDflags
LDFLAGS_SANITIZE="-fsanitize=address,undefined -static-libasan -static-liblsan -static-libubsan"
LDFLAGS_DEBUG=""
LDFLAGS_RELEASE="-Wl,-z,relro -Wl,-z,now" # Debian values

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

   for build_type in DEBUG RELEASE SANITIZE; do
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
         export BUILD_OPTIONS=$BUILD_OPTIONS_RELEASE
         export CFLAGS=$CFLAGS_RELEASE
         export LDFLAGS=$LDFLAGS_RELEASE
      elif [ "$build_type" = "SANITIZE" ]; then
         export BUILD_OPTIONS=$BUILD_OPTIONS_SANITIZE
         export CFLAGS=$CFLAGS_SANITIZE
         export LDFLAGS=$LDFLAGS_SANITIZE
      else
         export BUILD_OPTIONS=$BUILD_OPTIONS_DEBUG
         export CFLAGS=$CFLAGS_DEBUG
         export LDFLAGS=$LDFLAGS_DEBUG
      fi
      
      echo "Using (Build: $BUILD_OPTIONS) (CFlags: $CFLAGS) (LDFlags $LDFLAGS)"
      ./configure --prefix=$prefix $BUILD_OPTIONS CFLAGS="$CFLAGS"

      make -j $MAKE_JOBS
      make -j $MAKE_JOBS -C src/test/isolation
      make -j $MAKE_JOBS -C contrib/postgres_fdw
 
      make install
      make -C contrib/postgres_fdw install

      datadir=$BASEDIR/data/$dest_dir
      if [ ! -d $datadir ]; then 
          echo "Datadir $datadir for version $dest_dir does not exist, creating..."
          mkdir -p $datadir

          # Initdb could fail in sanitizer builds. '|| true' ignores these failures
          $prefix/bin/initdb -D $datadir || true
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
# Parameter 1 - Version
# Parameter 2 - Allow fail (optional)
###
postgres_stop() {
   if [ -z "$1" ]; then
      echo "Error: PostgreSQL version not specified!"
      exit 1
   fi

   version=$1

   # Allow stop fail
   fail="/bin/false"
   if [ -n "$2" ]; then
      fail="/bin/true"
   fi

   echo "Starting PostgreSQL version $version"
   $BASEDIR/bin/$version/bin/pg_ctl -D $BASEDIR/data/$version -l $BASEDIR/logfile_$version stop || $fail
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
	postgres_stop $2 true
	postgres_start $2
;;
*)
   echo "Usage: $0 {postgres_install | postgres_start | postgres_stop | postgres_restart}"
   ;;  
esac

exit 0

