{ config, pkgs, lib, ... }:
{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings = {
      mysqld = {
        innodb_buffer_pool_size = "16G";
        innodb_log_file_size="2g";
        innodb_buffer_pool_instances = "4";
        performance_schema = "on";
        tmp_table_size = "512m";
        max_heap_table_size = "512m";
      };
    };
    ensureUsers = [
      {
        name = "nathan";
        ensurePermissions = {
          "*.*" = "ALL PRIVILEGES";
        };
      }
      {
        name = "mysql-backup";
        ensurePermissions = {
          "*.*" = "SELECT, SHOW VIEW, TRIGGER, LOCK TABLES";
        };
      }
    ];
  };

  systemd.services.mysql-backup = {
    description = "MariaDB Backup";
    path = [ pkgs.mariadb pkgs.gzip ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    serviceConfig = {
      User = "nathan";
    };
    environment = {
      MYSQL_USER="mysql-backup";
      MYSQL_PASSWORD=config.secrets.mariadb.mysql-backup;
      TARGET_LOCATION="/media/documents/nathan/onedrive_nathan_personal/backup/mariadb";
    };
    script = ''
      EXCLUDE_DATABASES="Database|information_schema|performance_schema|mysql|sys|test"
      mkdir -pm 0775 $TARGET_LOCATION
      
      databases=`mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | tr -d "| " | egrep -v $EXCLUDE_DATABASES`

      for db in $databases; do        
        TMPFILE=$(mktemp --suffix "mysql-backup")
        if mysqldump --single-transaction -u $MYSQL_USER -p$MYSQL_PASSWORD --databases $db | gzip -c > $TMPFILE; then
          mv $TMPFILE $TARGET_LOCATION/$db.sql.gz
          echo "Backed up to $TARGET_LOCATION/$db.sql.gz"
        else
            echo "Failed to back up to $TARGET_LOCATION/$db.sql.gz"
            rm -f $TMPFILE
            failed="$failed $db"
        fi        
      done

      if [ -n "$failed" ]; then
        echo "Backup of database(s) failed:$failed"
        exit 1
      fi    
      '';
    startAt = "*-*-* 01:00:00";
  };

  
}
