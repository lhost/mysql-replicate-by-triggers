-- Install procedures into MySQL schema

-- set charset
/*!40101 SET NAMES utf8 */;

USE `mysql`;

START TRANSACTION;

SELECT '-- INFO: Installing procedures into `mysql` schema' AS '-- INFO:';
source procedures.sql;
SELECT '-- INFO: DONE - procedures installed' AS '-- INFO:';

COMMIT;

-- vim: ft=sql
