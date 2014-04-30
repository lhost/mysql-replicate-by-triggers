/*!50003 DROP PROCEDURE IF EXISTS `repl_create_schema` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_create_schema`(IN dstdb VARCHAR(64))
BEGIN
	-- Declarations {{{
	DECLARE num_rows INT DEFAULT 0;

	-- Declare the cursor
	DECLARE get_schema_name_cur CURSOR FOR
		SELECT SCHEMA_NAME
		FROM information_schema.SCHEMATA
		WHERE SCHEMA_NAME = dstdb;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		ROLLBACK;
	END;

	-- Declarations }}}

	START TRANSACTION;

	OPEN get_schema_name_cur;
	SELECT FOUND_ROWS() INTO num_rows;
	IF num_rows THEN
		-- schema `mysql_$hostname` found
		CLOSE get_schema_name_cur;
	ELSE
		SET @sql = CONCAT('CREATE DATABASE `', dstdb, '`');
		SELECT @sql;
		PREPARE STMT FROM @sql;
		EXECUTE STMT;
		DEALLOCATE PREPARE STMT;
	END IF;

	-- now do the job
	COMMIT;
	-- ROLLBACK;

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_create_tables` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_create_tables`(IN srcdb VARCHAR(64), IN dstdb VARCHAR(64))
BEGIN
	-- Declarations {{{
	DECLARE tablename_val VARCHAR(32);
	DECLARE schema_name VARCHAR(64);
	DECLARE cmd_info VARCHAR(255);
	DECLARE cmd VARCHAR(255);
	DECLARE no_more_rows BOOLEAN;

	-- Declare the cursor
	DECLARE get_table_name_cur CURSOR FOR
		SELECT s.TABLE_NAME,
			IF(ISNULL(d.TABLE_NAME),
				CONCAT('/* CREATE TABLE `', dstdb, '`.`', s.TABLE_NAME, '` */'),
				CONCAT('/* table ', d.TABLE_NAME, ' already exists */')
			) AS cmd_info,
			IF(ISNULL(d.TABLE_NAME),
				/* generate CREATE TABLE commands for missing tables */
				CONCAT('CREATE TABLE `', dstdb, '`.`', s.TABLE_NAME, '` AS SELECT * FROM `', srcdb, '`.`', s.TABLE_NAME, '`'),
				''
			) AS cmd 
		FROM information_schema.TABLES AS s
		LEFT JOIN information_schema.TABLES AS d ON (s.TABLE_NAME = d.TABLE_NAME AND d.TABLE_SCHEMA = dstdb)
		WHERE s.TABLE_SCHEMA = srcdb;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		ROLLBACK;
	END;

	-- Declare 'handlers' for exceptions
	DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET no_more_rows = TRUE;

	-- Declarations }}}

	START TRANSACTION;

	OPEN get_table_name_cur;
	the_loop: LOOP

		FETCH get_table_name_cur
		INTO tablename_val, cmd_info, cmd;

		IF no_more_rows THEN
			CLOSE get_table_name_cur;
			LEAVE the_loop;
		END IF;

		-- SELECT cmd_info;
		IF cmd <> '' THEN
			SELECT cmd;
			SET @sql = cmd;
			PREPARE STMT FROM @sql;
			EXECUTE STMT;
			DEALLOCATE PREPARE STMT;
		END IF;
	END LOOP the_loop;

	SELECT CONCAT('-- ', COUNT(*)) AS '-- INFO: number of tables in replicated schema'
	FROM information_schema.TABLES WHERE TABLE_SCHEMA = dstdb;

	-- now do the job
	COMMIT;
	-- ROLLBACK;

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_create_triggers` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_create_triggers`(IN srcdb VARCHAR(64), IN dstdb VARCHAR(64))
BEGIN
	-- Declarations {{{
	DECLARE tablename_val VARCHAR(32);
	DECLARE schema_name VARCHAR(64);
	DECLARE cmd_info VARCHAR(255);
	DECLARE cmd VARCHAR(255);
	DECLARE t_type VARCHAR(16);
	DECLARE t_name VARCHAR(255);
	DECLARE no_more_rows BOOLEAN;

	SELECT 'SELECT SCHEMA() INTO @cur_schema;' AS '-- INFO: current schema is:'
	UNION
	SELECT CONCAT('USE `', srcdb, '`;');

	-- Declare the cursor
	DECLARE missing_triggers_cur CURSOR FOR
		SELECT s.TABLE_NAME,
			trigger_types.t_type,
			CONCAT('repl_', LOWER(trigger_types.t_type), '_', s.TABLE_NAME) AS t_name
		FROM information_schema.TABLES AS s
		INNER JOIN (
			SELECT 'INSERT' AS t_type UNION SELECT 'UPDATE' AS t_type UNION SELECT 'DELETE' AS t_type
		) AS trigger_types
		LEFT JOIN information_schema.TRIGGERS AS t ON (
			s.TABLE_SCHEMA = t.EVENT_OBJECT_SCHEMA
			AND s.TABLE_NAME = t.EVENT_OBJECT_TABLE
			AND trigger_types.t_type = t.EVENT_MANIPULATION
		)
		WHERE s.TABLE_SCHEMA = srcdb
		ORDER BY s.TABLE_NAME;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		ROLLBACK;
	END;

	-- Declare 'handlers' for exceptions
	DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET no_more_rows = TRUE;

	-- Declarations }}}

	START TRANSACTION;

	OPEN missing_triggers_cur;
	the_loop: LOOP

		FETCH missing_triggers_cur
		INTO tablename_val, t_type, t_name;

		IF no_more_rows THEN
			CLOSE missing_triggers_cur;
			LEAVE the_loop;
		END IF;

		CALL repl_execute(CONCAT(
				'SELECT "DROP TRIGGER IF EXISTS `', t_name,
				'`;" AS "SELECT \'-- INFO: drop & create trigger `', t_name,
				'`\' AS \'-- INFO:\';";')
		);

		/* build CREATE TRIGGER query based on trigger type */
		CASE t_type
			WHEN 'INSERT' THEN
				SELECT '-- INFO: create INSERT trigger' AS '-- INFO:';
				SELECT CONCAT("CREATE DEFINER = CURRENT_USER TRIGGER `", t_name,
					"` AFTER INSERT ON `", tablename_val,
					"` FOR EACH ROW BEGIN INSERT INTO `", dstdb,
					"`.`", tablename_val, "` SET "
				) AS 'DELIMITER ;;' ;

				CALL repl_get_table_cols(srcdb, tablename_val, 'INSERT', @tbl_columns, @tbl_prikeys);

				-- SELECT @tbl_prikeys AS '-- prikeys';
				IF LENGTH(@tbl_prikeys) > 0 THEN
					SELECT @tbl_columns AS '/* insert columns */'
					UNION
					SELECT ', /* --- PK separator --- */'
					UNION
					SELECT @tbl_prikeys;
				ELSE
					SELECT @tbl_columns AS '/* insert columns */';
				END IF;

				SELECT ' ; END ;' AS '/* end of insert trigger */'
				UNION
				SELECT ';;'
				UNION
				SELECT 'DELIMITER ;';
			WHEN 'UPDATE' THEN
				SELECT '-- INFO: create UPDATE trigger' AS '-- INFO:';
				SELECT CONCAT("CREATE DEFINER = CURRENT_USER TRIGGER `", t_name,
					"` AFTER UPDATE ON `", tablename_val,
					"` FOR EACH ROW BEGIN UPDATE `", dstdb,
					"`.`", tablename_val, "` SET "
				) AS 'DELIMITER ;;' ;

				CALL repl_get_table_cols(srcdb, tablename_val, 'UPDATE', @tbl_columns, @tbl_prikeys);

				SELECT @tbl_columns AS '/* update columns */'
				UNION
				SELECT ' WHERE /* --- PK separator --- */'
				UNION
				SELECT @tbl_prikeys;

				SELECT ' ; END ;' AS '/* end of update trigger */'
				UNION
				SELECT ';;'
				UNION
				SELECT 'DELIMITER ;';
			WHEN 'DELETE' THEN
				SELECT '-- INFO: create DELETE trigger' AS '-- INFO:';
				SELECT CONCAT("CREATE DEFINER = CURRENT_USER TRIGGER `", t_name,
					"` AFTER DELETE ON `", tablename_val,
					"` FOR EACH ROW BEGIN DELETE FROM `", dstdb,
					"`.`", tablename_val, "` "
				) AS 'DELIMITER ;;' ;

				CALL repl_get_table_cols(srcdb, tablename_val, 'DELETE', @tbl_columns, @tbl_prikeys);

				SELECT @tbl_prikeys AS ' WHERE /* --- PK separator --- */';

				SELECT ' LIMIT 1 ; END ;' AS '/* end of delete trigger */'
				UNION
				SELECT ';;'
				UNION
				SELECT 'DELIMITER ;';
			ELSE
					SELECT CONCAT('-- ERROR: wrong trigger type "', t_type, '"') AS '# error';
		END CASE;

		-- SELECT cmd_info;
		IF cmd <> '' THEN
			SELECT cmd;
			-- SET @sql = cmd;
			-- PREPARE STMT FROM @sql;
			-- EXECUTE STMT;
			-- DEALLOCATE PREPARE STMT;
		END IF;
	END LOOP the_loop;

	-- now do the job
	COMMIT;
	-- ROLLBACK;

	-- switch back to previous schema
	SELECT 'USE @cur_schema;' AS '-- INFO: which back to remembered schema';

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_drop` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_drop`(IN srcdb VARCHAR(64), IN dstdb VARCHAR(64))
    COMMENT 'drop replicated schema'
BEGIN
	-- XXX: CALL repl_help();

	SELECT 'START TRANSACTION;' AS '-- SQL command';
	CALL repl_drop_triggers();
	SELECT CONCAT('DROP DATABASE `', dstdb, '`;') AS '-- SQL command'
	UNION
	SELECT 'COMMIT;' AS '-- now do the job';

	CALL repl_msg_quote(CONCAT('database `', dstdb, '`, dropped'));

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_execute` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_execute`(IN `cmd` TEXT)
    MODIFIES SQL DATA
    COMMENT 'prepare and execute SQL statement'
BEGIN
	-- Declarations {{{
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		-- ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		-- ROLLBACK;
	END;

	-- SELECT cmd AS '# DEBUG';
	-- Declarations }}}
	IF cmd <> '' THEN
		-- SELECT cmd;
		SET @sql = cmd;
		PREPARE STMT FROM @sql;
		EXECUTE STMT;
		DEALLOCATE PREPARE STMT;
	ELSE
		SELECT "-- WARNING: empty command passed to CALL repl_execute('')" AS '# warning';
	END IF;
END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_help` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_help`()
    COMMENT 'print help message'
BEGIN
	DECLARE help_message TEXT;

	CALL repl_help_message(help_message);
	-- SELECT help_message AS '-- INFO:';
	SELECT CONCAT("SELECT '' AS '-- INFO' UNION SELECT'",
		REPLACE(help_message, '\n', "' UNION SELECT '"),
		"';"
	) INTO @sql;
	PREPARE STMT FROM @sql;
	EXECUTE STMT;
	DEALLOCATE PREPARE STMT;
	-- SELECT REPLACE(help_message, '\n', '\n-- INFO:') AS '-- INFO';

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_drop_triggers` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_drop_triggers`(IN srcdb VARCHAR(64), IN dstdb VARCHAR(64))
BEGIN
	-- Declarations {{{
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		ROLLBACK;
	END;
	-- Declarations }}}

	SELECT
		CONCAT('DROP TRIGGER IF EXISTS `repl_', LOWER(trigger_types.t_type), '_', s.TABLE_NAME, '`;')
			AS 'SELECT "-- INFO: Dropping triggers" AS "-- INFO:";'
	FROM information_schema.TABLES AS s
	INNER JOIN (
		SELECT 'INSERT' AS t_type UNION SELECT 'UPDATE' AS t_type UNION SELECT 'DELETE' AS t_type
	) AS trigger_types
	LEFT JOIN information_schema.TRIGGERS AS t ON (
		s.TABLE_SCHEMA = t.EVENT_OBJECT_SCHEMA
		AND s.TABLE_NAME = t.EVENT_OBJECT_TABLE
		AND trigger_types.t_type = t.EVENT_MANIPULATION
	)
	WHERE s.TABLE_SCHEMA = srcdb
	ORDER BY s.TABLE_NAME;

	SELECT 'SELECT "-- INFO: all triggers dropped" AS "-- INFO:";' AS '-- INFO';

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_get_table_cols` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_get_table_cols`(IN tbl_schema varchar(32), IN tbl_table varchar(32), IN trg_type CHAR(6), OUT tbl_columns TEXT, OUT tbl_prikeys TEXT)
BEGIN
	-- Declarations {{{
	DECLARE num_indexes INT DEFAULT 0;
	DECLARE colname VARCHAR(255);
	DECLARE column_key VARCHAR(3);
	DECLARE no_more_rows BOOLEAN;
	DECLARE col_sep VARCHAR(9);
	DECLARE key_sep VARCHAR(9);
	DECLARE nxt_sep VARCHAR(9);

	-- Declare the cursor
	DECLARE tbl_colums_cur CURSOR FOR
		SELECT c.COLUMN_NAME, c.COLUMN_KEY
		FROM information_schema.COLUMNS AS c
		WHERE c.TABLE_SCHEMA = tbl_schema
			AND c.TABLE_NAME = tbl_table
		ORDER BY c.COLUMN_KEY DESC, c.ORDINAL_POSITION;

	DECLARE indexes_count_cur CURSOR FOR
		SELECT c.COLUMN_NAME, c.COLUMN_KEY
		FROM information_schema.COLUMNS AS c
		WHERE c.TABLE_SCHEMA = tbl_schema
			AND c.TABLE_NAME = tbl_table
			AND c.COLUMN_KEY = 'PRI'
		ORDER BY c.ORDINAL_POSITION;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		ROLLBACK;
	END;

	-- Declare 'handlers' for exceptions
	DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET no_more_rows = TRUE;

	-- Declarations }}}

	SET tbl_columns = '';
	SET tbl_prikeys = '';

	SET col_sep = '` = NEW.`';
	SET key_sep = '` = OLD.`';
	SET nxt_sep = ' AND ';
	
	OPEN indexes_count_cur;
	SELECT FOUND_ROWS() INTO num_indexes;
	CLOSE indexes_count_cur;

	IF trg_type = 'INSERT' THEN
		-- SET col_sep = '` = NEW.`';
		SET key_sep = '` = NEW.`';
		SET nxt_sep = ', ';
	END IF;

	OPEN tbl_colums_cur;
	the_loop: LOOP

		FETCH tbl_colums_cur INTO colname, column_key;

		IF no_more_rows THEN
			CLOSE tbl_colums_cur;
			LEAVE the_loop;
		END IF;

		-- select '-- DEBUG: ', colname, column_key, tbl_columns;
		IF num_indexes = 0 AND trg_type != 'INSERT' THEN
			/* we don't have indexes, use all columns */ 
			SET tbl_prikeys = CONCAT(tbl_prikeys, IF(tbl_prikeys = '', '', nxt_sep), '`', colname, key_sep, colname, '`');
			SET tbl_columns = CONCAT(tbl_columns, IF(tbl_columns = '', '', ', '), '`', colname, col_sep, colname, '`');
		ELSE
			CASE column_key
				WHEN 'PRI' THEN
					SET tbl_prikeys = CONCAT(tbl_prikeys, IF(tbl_prikeys = '', '', nxt_sep), '`', colname, key_sep, colname, '`', ' /* PK */ ');
				ELSE
					SET tbl_columns = CONCAT(tbl_columns, IF(tbl_columns = '', '', ', '), '`', colname, col_sep, colname, '`');
			END CASE;
		END IF;

	END LOOP the_loop;

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_help_message` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_help_message`(OUT help_message TEXT)
    COMMENT 'internal function to return  help message'
BEGIN
	SELECT
'You can create fresh replica by shell command
     DATABASE="name_of_db"; echo "CALL repl_init(\'srcdb\' ,\'dstdb\');" | mysql "$DATABASE" | mysql "$DATABASE"
and stop your replica by shell command
     DATABASE="name_of_db"; echo "CALL repl_drop(\'srcdb\' ,\'dstdb\');" | mysql "$DATABASE" | mysql "$DATABASE"
' INTO help_message;
END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_init` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_init`(IN srcdb VARCHAR(64), IN dstdb VARCHAR(64))
BEGIN
	-- Declarations {{{
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		ROLLBACK;
	END;

	-- Declarations }}}

	START TRANSACTION;

	CALL repl_create_schema(dstdb);
	CALL repl_create_tables(srcdb, dstdb);
	CALL repl_sync_table_engines(srcdb, dstdb);
	CALL repl_create_triggers(srcdb, dstdb);

	CALL repl_msg_quote(CONCAT('schema `', srcdb, '` is now replicated into schema `', dstdb, '`'));
	SELECT "SELECT '' AS 'xxxxxx' UNION SELECT REPLACE('" AS '/* msg begin */';
	CALL repl_help;
	SELECT "', '\n', \"' UNION SELECT '\") AS '-- ============================================================';" AS '/* msg end */';

	-- now do the job
	COMMIT;
	-- ROLLBACK;

END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_msg_quote` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_msg_quote`(IN msg VARCHAR(255))
    COMMENT 'quote message for user by "-- INFO:" prefix'
BEGIN
	/* add prefix '-- INFO' to message */
	SELECT CONCAT('SELECT "-- INFO: ', msg, '" AS "-- INFO:";') AS '-- INFO:';
END ;;
DELIMITER ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_sync_table_engines` */;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_sync_table_engines`(IN srcdb VARCHAR(64), IN dstdb VARCHAR(64))
BEGIN
	-- Declarations {{{
	DECLARE num_rows INT DEFAULT 0;
	DECLARE tablename_val VARCHAR(32);
	DECLARE schema_name VARCHAR(64);
	DECLARE cmd_info VARCHAR(255);
	DECLARE cmd VARCHAR(255);
	DECLARE no_more_rows BOOLEAN;

	-- Declare the cursor
	DECLARE sync_engine_cur CURSOR FOR
		SELECT s.TABLE_NAME,
			CONCAT('/* ALTER TABLE `', dstdb, '`.`', s.TABLE_NAME, '` */') AS cmd_info,
			CONCAT('ALTER TABLE `', dstdb, '`.`', s.TABLE_NAME, '` ENGINE = ', s.ENGINE) AS cmd 
		FROM information_schema.TABLES AS s
		INNER JOIN information_schema.TABLES AS d ON (
			s.TABLE_NAME = d.TABLE_NAME
			AND d.TABLE_SCHEMA = dstdb
			AND s.ENGINE <> d.ENGINE
		)
		WHERE s.TABLE_SCHEMA = srcdb;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SHOW ERRORS;
		ROLLBACK;
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		SHOW WARNINGS;
		ROLLBACK;
	END;

	-- Declare 'handlers' for exceptions
	DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET no_more_rows = TRUE;

	-- Declarations }}}

	START TRANSACTION;

	OPEN sync_engine_cur;
	SELECT FOUND_ROWS() INTO num_rows;
	the_loop: LOOP

		FETCH sync_engine_cur
		INTO tablename_val, cmd_info, cmd;

		IF no_more_rows THEN
			CLOSE sync_engine_cur;
			LEAVE the_loop;
		END IF;

		-- SELECT cmd_info;
		IF cmd <> '' THEN
			SELECT cmd;
			SET @sql = cmd;
			PREPARE STMT FROM @sql;
			EXECUTE STMT;
			DEALLOCATE PREPARE STMT;
		END IF;
	END LOOP the_loop;

	-- now do the job
	COMMIT;
	-- ROLLBACK;

END ;;
DELIMITER ;



/* _footer.sql */
-- vim: fdm=marker fdl=0 fdc=0 fmr=DELIMITER\ ;;,DELIMITER\ \; foldtext=getline(v\:foldstart\+1)

