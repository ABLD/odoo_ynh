#
# Common variables
#

APPNAME="odoo"


# Package name for dependencies
DEPS_PKG_NAME="${APPNAME}-deps"

# Remote URL to fetch tarball
SOURCE_URL="http://download.gna.org/wkhtmltopdf/0.12/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz"

# Remote URL to fetch tarball checksum
SOURCE_SHA256="049b2cdec9a8254f0ef8ac273afaf54f7e25459a273e27189591edc7d7cf29db"

# App package root directory should be the parent folder
PKGDIR=$(cd ../; pwd)

#
# Common helpers
#

# # Execute a command as root user
#
# usage: ynh_psql_execute_as_root sql [db]
# | arg: sql - the SQL command to execute
# | arg: db - the database to connect to
ynh_psql_execute_as_root () {
        sudo su -c "psql" - postgres <<< ${1}
}

# Create a user
#
# usage: ynh_psql_create_user user pwd [host]
# | arg: user - the user name to create
# | arg: pwd - the password to identify user by
ynh_psql_create_user() {
        ynh_psql_execute_as_root \
        "CREATE USER ${1} WITH PASSWORD '${2}';"
}

# Create a database and grant optionnaly privilegies to a user
#
# usage: ynh_psql_create_db db [user [pwd]]
# | arg: db - the database name to create
# | arg: user - the user to grant privilegies
# | arg: pwd - the password to identify user by
ynh_psql_create_db() {
    db=$1
    # grant all privilegies to user
    if [[ $# -gt 1 ]]; then
        ynh_psql_create_user ${2} "${3}"
        sudo su -c "createdb -O ${2} $db" -  postgres
    else
        sudo su -c "createdb $db" -  postgres
    fi

}

# Drop a database
#
# usage: ynh_psql_drop_db db
# | arg: db - the database name to drop
ynh_psql_drop_db() {
    sudo su -c "dropdb ${1}" -  postgres
}

# Drop a user
#
# usage: ynh_psql_drop_user user
# | arg: user - the user name to drop
ynh_psql_drop_user() {
    sudo su -c "dropuser ${1}" - postgres
}


# Download and extract sources to the given directory
# usage: extract_sources DESTDIR [AS_USER]
extract_sources() {
  local DESTDIR=$1
  local AS_USER=${2:-admin}

  # retrieve and extract Roundcube tarball
  tarball="/tmp/${APPNAME}.tar.xz"
  rm -f "$tarball"
  wget -q -O "$tarball" "$SOURCE_URL" \
    || ynh_die "Unable to download tarball"
  echo "$SOURCE_SHA256 $tarball" | sha256sum -c >/dev/null \
    || ynh_die "Invalid checksum of downloaded tarball"
  exec_as "$AS_USER" tar xJf "$tarball" -C "$DESTDIR" --strip-components 1 \
    || ynh_die "Unable to extract tarball"
  rm -f "$tarball"

  # apply patches
  if [[ -d "${PKGDIR}/patches" ]]; then
      (cd "$DESTDIR" \
       && for p in ${PKGDIR}/patches/*.patch; do \
            exec_as "$AS_USER" patch -p1 < $p; done) \
        || ynh_die "Unable to apply patches"
  fi
}

# Execute a command as another user
# usage: exec_as USER COMMAND [ARG ...]
exec_as() {
  local USER=$1
  shift 1

  if [[ $USER = $(whoami) ]]; then
    eval "$@"
  else
    # use sudo twice to be root and be allowed to use another user
    sudo sudo -u "$USER" "$@"
  fi
}
