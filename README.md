mysql-replicate-by-triggers
===========================
With the following procedures you can synchronize/replicate your
`my_schema` schema into `my_schema_rep` schema. A set of SQL procedures
would help you to create INSERT/UPDATE/DELETE triggers.

It was planned to replicate `mysql` schema into `mysql_$hostname`, but
MySQL/MariaDB doesn't support triggers on "system" tables.  Maybe in the future
would be possible to create triggers on system tables.  When this happens, you
can ignore `mysql` in replication setting and safely replicate
`mysql_$hostname` schema.

GOAL
-----------
replicate `mysql` schema to `mysql_$hostname` using triggers
and use multimaster replication (see MariaDB feature) to single backup server

LIMITATIONS
-----------
- you can't create create trigger from SQL procedure
- you can't create trigger on system schema/tables
