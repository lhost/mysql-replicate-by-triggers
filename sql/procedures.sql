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

DELIMITER ;;
DROP PROCEDURE IF EXISTS `repl_create_schema`;
CREATE PROCEDURE `repl_create_schema`()
BEGIN
	-- Declarations {{{
	DECLARE num_rows INT DEFAULT 0;

	-- Declare the cursor
	DECLARE get_schema_name_cur CURSOR FOR
		SELECT SCHEMA_NAME
		FROM information_schema.SCHEMATA
		WHERE SCHEMA_NAME = CONCAT('mysql_', GetHostName());

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
		SET @sql = CONCAT('CREATE DATABASE `', 'mysql_', GetHostName(), '`;');
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
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

