#!/usr/bin/env bash

DB_USER="root"
DB_PASS=""
DB_HOST="localhost"
DB_SKIP=( "information_schema" "mysql" )

BACKUPDIR="/home/backups/"


EXEC_MYSQL=`which mysql`
EXEC_MYSQLDUMP=`which mysqldump`

DATETIME=`date +%Y-%m-%d_%H%M`
TMPDIR=`mktemp -d --suffix=.simple-mysql-backup`

###
function skip_this_db()
{
  for DB in "${DB_SKIP[@]}"
  do
    if [ "$1" == "$DB" -o "$1.*" == "$DB" -o "*.$2" == "$DB" -o "$1.$2" == "$DB" ]
    then
      return 0
    fi
  done

  return 1
}

###
for DB in `${EXEC_MYSQL} --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --batch --skip-column-names -e "show databases"`
do
  # Prüfen ob diese Datenbank gesichert werden soll
  if ( skip_this_db "${DB}" )
  then
    #echo "${DB}.* übersprungen"
    continue
  fi

  # Temporäres Verzeichnis für die Dumps dieser Datenbank erstellen
  TMPDIR2="${TMPDIR}/${DB}"
  mkdir -p ${TMPDIR2}

  # Prüfen ob die diese Tablelle der Datenbank gesichert werden soll
  for DB_TBL in `${EXEC_MYSQL} --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" ${DB} --batch --skip-column-names -e "show tables"`
  do
    if ( skip_this_db "${DB}" "${DB_TBL}" )
    then
      #echo "${DB}.${DB_TBL} übersprungen"
      continue
    fi

    # Dump erstellen
    `${EXEC_MYSQLDUMP} --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --opt ${DB} ${DB_TBL} > ${TMPDIR2}/${DB_TBL}.sql`
  done

  # Dumps Zusammenpacken und Komprimieren
  cd ${TMPDIR2}
  tar -cf "../${DB}.${DATETIME}.tar" *.sql
  cd ..
  rm -rf "${DB}/"
  gzip -9 "${DB}.${DATETIME}.tar"
done

# MySQL Datenbank Dumps verschieben 
mv ${TMPDIR}/* ${BACKUPDIR}

# Temporäre Dateien entfernen 
rm -rf "${TMPDIR}"

### EOF ###
