#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(strftime);
use File::Path qw(remove_tree);

my $BACKUP_BASEDIR  = '/srv/pgsql/base';
my $ARCHIVE_DIR     = '/srv/pgsql/archive';
my $MAX_NUM_BACKUPS = 4;

sub list_backups {
    opendir( my $backup_bdh, $BACKUP_BASEDIR );
    my @dates = sort grep /^\d{4}-\d\d-\d\d$/, readdir $backup_bdh;
    return @dates;
 }

sub num_backups {
    return scalar list_backups();
}

sub old_backup {
    return (list_backups())[0];
}

sub old_wal_segment {
    my $old_pg_wal_dir = "$BACKUP_BASEDIR/" . old_backup() . "/pg_wal";
    opendir( my $old_pg_wal_dh, $old_pg_wal_dir );
    my @segments = sort grep /^[0-9A-F]{24}$/, readdir $old_pg_wal_dh;
    closedir $old_pg_wal_dh;
    return $segments[0];
}

sub remove_old_backups {
    while ( num_backups() > $MAX_NUM_BACKUPS ) {
        my $old_backup_dir = "$BACKUP_BASEDIR/" . old_backup();
	remove_tree($old_backup_dir);
    }
}

sub create_backup {
    my $today      = strftime( '%F', localtime time );
    my $backup_dir = "$BACKUP_BASEDIR/$today";
    die "Directory $backup_dir already exists, you should remove it first.\n"
      if -d $backup_dir;
    mkdir $backup_dir, 0700;
    system '/usr/bin/pg_basebackup',
      -h => '/tmp',
      -l => $today,
      -D => $backup_dir,
      -X => 'stream';
}

sub cleanup_archive {
    system '/usr/pgsql-11/bin/pg_archivecleanup', $ARCHIVE_DIR, old_wal_segment();
}

create_backup();
remove_old_backups();
cleanup_archive();

1;
