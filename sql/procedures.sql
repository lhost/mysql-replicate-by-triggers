/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!50003 DROP FUNCTION IF EXISTS `GetHostName` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `GetHostName`() RETURNS varchar(64) CHARSET utf8
    DETERMINISTIC
BEGIN
	DECLARE local_hostname VARCHAR(64);

	SELECT variable_value INTO local_hostname
	FROM information_schema.global_variables
	WHERE variable_name = 'hostname';

	RETURN local_hostname;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `repl_get_schema_name` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `repl_get_schema_name`() RETURNS varchar(64) CHARSET utf8
    DETERMINISTIC
BEGIN
	DECLARE schema_name VARCHAR(64);

	SELECT CONCAT('mysql_', variable_value) INTO schema_name
	FROM information_schema.global_variables
	WHERE variable_name = 'hostname';

	RETURN schema_name;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_create_schema` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_create_schema`()
BEGIN
	-- Declarations {{{
	DECLARE num_rows INT DEFAULT 0;

	-- Declare the cursor
	DECLARE get_schema_name_cur CURSOR FOR
		SELECT SCHEMA_NAME
		FROM information_schema.SCHEMATA
		WHERE SCHEMA_NAME = repl_get_schema_name();

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
		SET @sql = CONCAT('CREATE DATABASE `', repl_get_schema_name(), '`;');
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
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_create_tables` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_create_tables`()
BEGIN
	-- Declarations {{{
	DECLARE num_rows INT DEFAULT 0;
	DECLARE tablename_val VARCHAR(32);
	DECLARE schema_name VARCHAR(64);
	DECLARE cmd_info VARCHAR(255);
	DECLARE cmd VARCHAR(255);
	DECLARE no_more_rows BOOLEAN;

	-- Declare the cursor
	DECLARE get_table_name_cur CURSOR FOR
		SELECT s.TABLE_NAME,
			IF(ISNULL(d.TABLE_NAME),
				CONCAT('/* CREATE TABLE `', repl_get_schema_name(), '`.`', s.TABLE_NAME, '` */'),
				CONCAT('/* table ', d.TABLE_NAME, ' already exists */')
			) AS cmd_info,
			IF(ISNULL(d.TABLE_NAME),
				/* generate CREATE TABLE commands for missing tables */
				CONCAT('CREATE TABLE `', repl_get_schema_name(), '`.`', s.TABLE_NAME, '` AS SELECT * FROM `mysql`.`', s.TABLE_NAME, '`'),
				''
			) AS cmd 
		FROM information_schema.TABLES AS s
		LEFT JOIN information_schema.TABLES AS d ON (s.TABLE_NAME = d.TABLE_NAME AND d.TABLE_SCHEMA = repl_get_schema_name())
		WHERE s.TABLE_SCHEMA = 'mysql';

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
	SELECT FOUND_ROWS() INTO num_rows;
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
	FROM information_schema.TABLES WHERE TABLE_SCHEMA = repl_get_schema_name();

	-- now do the job
	COMMIT;
	-- ROLLBACK;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_drop_triggers` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_drop_triggers`()
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
		CONCAT('DROP TRIGGER IF EXISTS `repl_', LOWER(trigger_types.t_type), '_', s.TABLE_NAME, '`;') AS '-- SQL command'
	FROM information_schema.TABLES AS s
	INNER JOIN (
		SELECT 'INSERT' AS t_type UNION SELECT 'UPDATE' AS t_type UNION SELECT 'DELETE' AS t_type
	) AS trigger_types
	LEFT JOIN information_schema.TRIGGERS AS t ON (
		s.TABLE_SCHEMA = t.EVENT_OBJECT_SCHEMA
		AND s.TABLE_NAME = t.EVENT_OBJECT_TABLE
		AND trigger_types.t_type = t.EVENT_MANIPULATION
	)
	WHERE s.TABLE_SCHEMA = 'mysql'
	ORDER BY s.TABLE_NAME;

	SELECT 'SELECT "-- INFO: all triggers dropped" AS "-- INFO:";' AS '-- INFO';

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_create_triggers` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_create_triggers`()
BEGIN
	-- Declarations {{{
	DECLARE num_rows INT DEFAULT 0;
	DECLARE tablename_val VARCHAR(32);
	DECLARE schema_name VARCHAR(64);
	DECLARE cmd_info VARCHAR(255);
	DECLARE cmd VARCHAR(255);
	DECLARE t_type VARCHAR(16);
	DECLARE t_name VARCHAR(255);
	DECLARE no_more_rows BOOLEAN;

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
		WHERE s.TABLE_SCHEMA = 'mysql'
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
	SELECT FOUND_ROWS() INTO num_rows;
	the_loop: LOOP

		FETCH missing_triggers_cur
		INTO tablename_val, t_type, t_name;

		IF no_more_rows THEN
			CLOSE missing_triggers_cur;
			LEAVE the_loop;
		END IF;

		/* build CREATE TRIGGER query based on trigger type */
		IF t_type = 'INSERT' THEN
			SELECT '-- INFO: create INSERT trigger' AS '-- INFO:';
		ELSE
			IF t_type = 'UPDATE' THEN
				SELECT '-- INFO: create UPDATE trigger' AS '-- INFO:';
			ELSE
				IF t_type = 'DELETE' THEN
					-- create INSERT TRIGGER
			SELECT '-- INFO: create DELETE trigger' AS '-- INFO:';
				ELSE
					SELECT CONCAT('-- ERROR: wrong trigger type "', t_type, '"') AS '# error';
				END IF;
			END IF;
		END IF;

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

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_help` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_help`()
	COMMENT 'print help message'
BEGIN
	SELECT '' AS '-- INFO:'
	UNION
	SELECT '-- INFO: You can create fresh replica by shell command'
	UNION
	SELECT '-- INFO:      echo "CALL repl_init();" | mysql mysql | mysql mysql'
	UNION
	SELECT '-- INFO: and stop your replica by shell command'
	UNION
	SELECT '-- INFO:      echo "CALL repl_drop();" | mysql mysql | mysql mysql;'
	;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_drop` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_drop`()
	COMMENT 'drop replicated schema'
BEGIN
	CALL repl_help();

	SELECT 'START TRANSACTION;' AS '-- SQL command';
	CALL repl_drop_triggers();
	SELECT CONCAT('DROP DATABASE `', repl_get_schema_name(), '`;') AS '-- SQL command'
	UNION
	SELECT 'COMMIT;' AS '-- now do the job';

	CALL repl_msg_quote(CONCAT('database `', repl_get_schema_name(), '`, dropped'));

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_execute` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
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
		SELECT cmd;
		SET @sql = cmd;
		PREPARE STMT FROM @sql;
		EXECUTE STMT;
		DEALLOCATE PREPARE STMT;
	ELSE
		SELECT "-- WARNING: empty command passed to CALL repl_execute('')" AS '# warning';
	END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_msg_quote` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_msg_quote`(IN msg VARCHAR(255))
	COMMENT 'quote message for user by "-- INFO:" prefix'
BEGIN
	/* add prefix '-- INFO' to message */
	SELECT CONCAT('SELECT "-- INFO: ', msg, '" AS "-- INFO:";') AS '-- INFO:';
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_init` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_init`()
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

	CALL repl_create_schema;
	CALL repl_create_tables;
	CALL repl_sync_table_engines;
	CALL repl_create_triggers;

	CALL repl_msg_quote(CONCAT('schema `mysql` is now replicated into schema `', repl_get_schema_name(), '`'));
	CALL repl_help;

	-- now do the job
	COMMIT;
	-- ROLLBACK;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `repl_sync_table_engines` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `repl_sync_table_engines`()
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
			CONCAT('/* ALTER TABLE `', repl_get_schema_name(), '`.`', s.TABLE_NAME, '` */') AS cmd_info,
			CONCAT('ALTER TABLE `', repl_get_schema_name(), '`.`', s.TABLE_NAME, '` ENGINE = ', s.ENGINE) AS cmd 
		FROM information_schema.TABLES AS s
		INNER JOIN information_schema.TABLES AS d ON (
			s.TABLE_NAME = d.TABLE_NAME
			AND d.TABLE_SCHEMA = repl_get_schema_name()
			AND s.ENGINE <> d.ENGINE
		)
		WHERE s.TABLE_SCHEMA = 'mysql';

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
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;


/* _footer.sql */
-- vim: fdm=marker fdl=0 fdc=0

