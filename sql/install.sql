-- Install procedures into MySQL schema

-- set charset
/*!40101 SET NAMES utf8 */;

START TRANSACTION;

SELECT '-- INFO: Installing procedures' AS '-- INFO:';
source procedures.sql;
SELECT '-- INFO: DONE - procedures installed' AS '-- INFO:';

COMMIT;

-- vim: ft=sql
