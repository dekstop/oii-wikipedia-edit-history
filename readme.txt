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
$ ./loadwiki.sh $DB simplewiki 20180220
# ... repeat for any other wikis, then:
$ psql --set ON_ERROR_STOP=1 $DB < allwikis.sql

