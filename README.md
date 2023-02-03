# PostgreSQL Sandbox Installer

This project provides a sandbox installer for PostgreSQL. It can be used to download, compile, and install multiple PostgreSQL versions in parallel on a single system. All PostgreSQL installations are compiled with different configurations (`RELEASE`, `DEBUG`, and `SANITIZER`). The `RELEASE` build is an optimized PostgreSQL like the build that is provided by Linux Distributions, `DEBUG` is an unoptimized build that contains debug symbols. `SANITIZER` is a build that is compiled and statically linked against an address sanitizer (libasan) and a leak analyzer (liblsan).

For example, such a collection of local PostgreSQL installations is helpful if you develop PostgreSQL extensions and you have to test them on different versions (e.g., 12, 13, 14, and 15).

## Usage

### PostgreSQL Installation
Install the PostgreSQL sandbox by executing the following commands:

```
git clone git@github.com:jnidzwetzki/postgresql-sandbox.git
```

Create a `src` directory inside of the downloaded sandbox to indicate that this directory should be used as the sandbox directory:

```
cd postgresql-sandbox
mkdir src
```

Adjust the `VERSIONS` setting inside of the script. This contains the PostgreSQL installations that should be installed. For example, if you set the variable to `VERSIONS="REL_12_10 REL_13_6 REL_14_2 REL_15_1 REL_14_STABLE"` PostgreSQL 12.10, 14.2, 15.1 and the latest 14 PostgreSQL versions are installed. These strings are the [branches](https://github.com/postgres/postgres/branches) and [tags](https://github.com/postgres/postgres/tags) of the [PostgreSQL git repository](https://github.com/postgres/postgres/).

Afterward, the PostgreSQL installations can be downloaded and installed by executing:

```
./postgres-sandbox.sh postgres-sandbox.sh
```

In addition, the `initdb` binary is invoked for each of the installations. 

_Note:_ Only new PostgreSQL installations are downloaded by this command. Only new versions are handled, and the remaining installations stay untouched. So, you can add further PostgreSQL versions to the `VERSIONS` setting and re-run the command.

After the command is complete, the `src` folder contains the sources of all of these PostgreSQL installations:

```
jan@debian11-work:~/postgresql-sandbox$ ls -l src/
total 64
drwxr-xr-x 7 jan jan 4096 Apr  1  2022 postgres.git
drwxr-xr-x 7 jan jan 4096 Oct 31 12:33 REL_12_10_DEBUG
drwxr-xr-x 7 jan jan 4096 Oct 31 12:37 REL_12_10_RELEASE
drwxr-xr-x 7 jan jan 4096 Dec  8 08:32 REL_12_10_SANITIZE
drwxr-xr-x 7 jan jan 4096 Oct 31 12:20 REL_13_6_DEBUG
drwxr-xr-x 7 jan jan 4096 Oct 31 12:23 REL_13_6_RELEASE
drwxr-xr-x 7 jan jan 4096 Dec  7 11:16 REL_14_2_DEBUG
drwxr-xr-x 7 jan jan 4096 Oct 31 12:17 REL_14_2_RELEASE
drwxr-xr-x 7 jan jan 4096 Dec  7 16:04 REL_14_2_SANITIZE
drwxr-xr-x 7 jan jan 4096 Dec 10 13:47 REL_15_1_DEBUG
drwxr-xr-x 7 jan jan 4096 Nov 17 09:53 REL_15_1_RELEASE
drwxr-xr-x 7 jan jan 4096 Dec 10 13:51 REL_15_1_SANITIZE
```

The `bin` folder contains the binaries of these PostgreSQL installations and in `data` folder are the databases located.

### Use the PostgreSQL Installations

To start a PostgreSQL installation, the command `postgres_start` together with the PostgreSQL installation name can be used. The following command starts the debug build of the PostgreSQL 15.1 installation.

```
~/postgresql-sandbox/postgres-sandbox.sh postgres_start REL_15_1_DEBUG
```

To stop the PostgreSQL installation, the `postgres_stop` command has to be used:

```
~/postgresql-sandbox/postgres-sandbox.sh postgres_stop REL_15_1_DEBUG
```

To get the PostgreSQL binaries (e.g., `initdb` or `psql`) into the path of the current shell, the path variable has to be adjusted. The following command adds the binaries of the PostgreSQL 14.2 release build to the path:

```
export PATH=~/postgresql-sandbox/bin/REL_14_2_RELEASE/bin:$PATH
```

To create a database and connect to the PostgreSQL server, the following commands can be used:

```
createdb mydb
psql mydb
```
