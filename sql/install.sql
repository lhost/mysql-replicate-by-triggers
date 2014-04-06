-- Install procedures into MySQL schema

-- set charset
/*!40101 SET NAMES utf8 */;

USE `mysql`;

START TRANSACTION;

SELECT 'INFO: Installing procedures into `mysql` schema' AS `# info`;
source procedures.sql;
SELECT 'INFO: DONE' AS `# info`;

-- SHOW FUNCTION STATUS;
SHOW PROCEDURE STATUS;

COMMIT;

# vim: ft=sql
