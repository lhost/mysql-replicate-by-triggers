-- Install procedures into MySQL schema

-- set charset
/*!40101 SET NAMES utf8 */;

USE `mysql`;

SELECT 'Installing procedures into `mysql` schema' AS `info`;
source procedures.sql;
SELECT 'DONE' AS `info`;

SHOW FUNCTION STATUS;
SHOW PROCEDURE STATUS;

# vim: ft=mysql
