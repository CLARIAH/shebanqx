REVOKE ALL, GRANT OPTION FROM 'shebanq'@'%';

GRANT USAGE ON *.* TO `shebanq`@`%`;

GRANT SELECT ON `shebanq\_etcbc%`.* TO 'shebanq'@'%';
GRANT SELECT ON `shebanq\_passage%`.* TO 'shebanq'@'%';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER ON shebanq_web.* TO 'shebanq'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER ON shebanq_note.* TO 'shebanq'@'%';

FLUSH PRIVILEGES;
