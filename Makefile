#
# Set to name of the database/schema, where you want to install SQL procedures
#
DATABASE = repl

MYSQLDUMP			= mysqldump --opt --routines
MYSQLDUMP_NODATA	= mysqldump --no-data --skip-dump-date --skip-comments --skip-set-charset

.PHONY: sql/%.sql dump backup

.FORCE:

all:
	@echo 'make dump      - dump triggers, procedures and table structures into sql/' 
	@echo 'make backup    - create backup' 
	@echo 'make install   - install procedures into `repl` schema' 

dump: sql/triggers.sql sql/procedures.sql sql/tables.sql

doc/crontab: .FORCE
	crontab -l > $@

%.sql: .FORCE

sql/triggers.sql: .FORCE
	$(MYSQLDUMP_NODATA) --no-create-info $(DATABASE) > $@
	@cat sql/_footer.sql >> $@

sql/procedures.sql: .FORCE
	$(MYSQLDUMP_NODATA) --routines --no-create-info --skip-triggers $(DATABASE) | grep -v -e '^/\*\![0-9]* SET ' > $@
	@cat sql/_footer.sql >> $@

sql/tables.sql: .FORCE
	$(MYSQLDUMP_NODATA) --skip-triggers $(DATABASE) > $@
	@cat sql/_footer.sql >> $@

backup:
	 @BACKUP_FILE=~/backup/$(DATABASE)-`date '+%Y-%m-%d-%X'`.sql; \
		 echo "Dumping database into $$BACKUP_FILE"; \
		 $(MYSQLDUMP) --databases $(DATABASE) > $$BACKUP_FILE && \
		 pbzip2 --best $$BACKUP_FILE

install:
	DATABASE="$(DATABASE)" ./install.sh

uninstall:
	DATABASE="$(DATABASE)" ./uninstall.sh
