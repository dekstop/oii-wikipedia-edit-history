Init DB:
$ sudo su - postgres
$ DB=oiidg_wp_20180220
$ createuser oiidg --pwprompt
$ createdb $DB
$ psql $DB -c "CREATE EXTENSION postgis"
$ psql $DB -c "GRANT CREATE ON DATABASE \"${DB}\" TO oiidg"

Load data:
$ DB=oiidg_wp_20180220
$ ./initdb.sh $DB
$ time ./load_all_wikis.sh $DB 20180220

