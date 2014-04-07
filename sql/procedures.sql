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

	SELECT COUNT(*) AS 'number of tables in replicated schema'
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

	SET @sql = CONCAT('DROP DATABASE `', repl_get_schema_name(), '`');

	SELECT @sql AS '# info'
	UNION
	SELECT 'INFO: You can create fresh replica by command CALL repl_init();';

	PREPARE STMT FROM @sql;
	EXECUTE STMT;
	DEALLOCATE PREPARE STMT;

	-- now do the job
	COMMIT;
	-- ROLLBACK;

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

	SELECT CONCAT('INFO: schema `mysql` is now replicated into schema `', repl_get_schema_name(), '`') AS '# info'
	UNION
	SELECT 'Info: You can stop replication with command CALL repl_drop();';

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

