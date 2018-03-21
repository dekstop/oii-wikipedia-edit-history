Init DB:
$ sudo su - postgres
$ DB=simplewiki_20180220
$ createuser oiidg --pwprompt
$ createdb $DB
$ psql -d $DB -c "CREATE EXTENSION postgis;"
$ psql -d $DB -c "GRANT CREATE ON DATABASE \"${DB}\" TO oiidg;"

