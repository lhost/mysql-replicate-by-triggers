DATABASE = mysql

MYSQLDUMP_NODATA = mysqldump --no-data --skip-dump-date

.PHONY: sql/%.sql dump backup

.FORCE:

all:
	@echo "make dump      - dump triggers, procedures and table structures into sql/" 
	@echo "make backup    - create backup" 

dump: sql/triggers.sql sql/procedures.sql sql/tables.sql

doc/crontab: .FORCE
	crontab -l > $@

%.sql: .FORCE

sql/triggers.sql: .FORCE
	$(MYSQLDUMP_NODATA) --no-create-info $(DATABASE) > $@

sql/procedures.sql: .FORCE
	$(MYSQLDUMP_NODATA) --routines --no-create-info --skip-triggers $(DATABASE) > $@

sql/tables.sql: .FORCE
	$(MYSQLDUMP_NODATA) --skip-triggers $(DATABASE) > $@

backup:
	 @BACKUP_FILE=~/backup/$(DATABASE)-`date '+%Y-%m-%d-%X'`.sql; \
		 echo "Dumping database into $$BACKUP_FILE"; \
		 mysqldump --opt --routines --databases $(DATABASE) > $$BACKUP_FILE && \
		 pbzip2 --best $$BACKUP_FILE

