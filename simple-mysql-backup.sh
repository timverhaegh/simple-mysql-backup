#!/usr/bin/env bash

# MySQL Zugangsdaten
DB_USER="root"
DB_PASS=""
DB_HOST="localhost"
DB_PORT="3306"

# Datenbanken und Tabellen die nicht gesichert werden sollen
DB_SKIP=( "information_schema.*" "mysql.*" )

# Verzeichnisse
DIR_BACKUP="/var/backups/mysqldumps/"
DIR_TEMPORARY=`mktemp -d --suffix=.simple-mysql-backup`

# Programme
EXEC_MYSQL=`which mysql`
EXEC_MYSQLDUMP=`which mysqldump`

# Optionen
OPTIONS_MYSQLDUMP="--complete-insert --opt --skip-comments"

DATETIME=`date +%Y-%m-%d_%H%M`

###
function skip_this_db()
{
  for DB in "${DB_SKIP[@]}"
  do
    if [ "$1.*" == "$DB" -o "*.$2" == "$DB" -o "$1.$2" == "$DB" ]
    then
      return 0
    fi
  done

  return 1
}

###
for DB in `${EXEC_MYSQL} --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --port="${DB_PORT}" --batch --skip-column-names -e "show databases"`
do
  # Prüfen ob diese Datenbank gesichert werden soll
  if ( skip_this_db "${DB}" )
  then
    #echo "${DB}.* übersprungen"
    continue
  fi

  # Temporäres Verzeichnis für die Dumps dieser Datenbank erstellen
  DIR_TEMPORARY2="${DIR_TEMPORARY}/${DB}"
  mkdir -p ${DIR_TEMPORARY2}

  # Prüfen ob die diese Tablelle der Datenbank gesichert werden soll
  for DB_TBL in `${EXEC_MYSQL} --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --port="${DB_PORT}" ${DB} --batch --skip-column-names -e "show tables"`
  do
    if ( skip_this_db "${DB}" "${DB_TBL}" )
    then
      #echo "${DB}.${DB_TBL} übersprungen"
      continue
    fi

    # Dump erstellen
    `${EXEC_MYSQLDUMP} --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --port="${DB_PORT}" ${OPTIONS_MYSQLDUMP} ${DB} ${DB_TBL} > ${DIR_TEMPORARY2}/${DB_TBL}.sql`
  done

  # Dumps Zusammenpacken und Komprimieren
  cd ${DIR_TEMPORARY2}
  tar -cf "../${DB}.${DATETIME}.tar" *.sql
  cd ..
  rm -rf "${DB}/"
  gzip -9 "${DB}.${DATETIME}.tar"
done

# MySQL Datenbank Dumps verschieben 
mv ${DIR_TEMPORARY}/* ${DIR_BACKUP}

# Temporäre Dateien entfernen 
rm -rf "${DIR_TEMPORARY}"

### EOF ###
