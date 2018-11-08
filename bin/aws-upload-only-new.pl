#!/usr/bin/perl

use strict;

# Controlling variables
my $DIRLIST="$ARGV[0]";
my $BUCKET=$ARGV[1] ne "" ? $ARGV[1] : "offsite2018.library.arizona.edu";
my $PROFILE="--profile ".($ARGV[2] ne "" ? $ARGV[2] : "wasabi");
my $PARALLEL_UPLOADS=10;
my $OFFSITE_REFRESH=30*24*60*60; # Refresh offsite manifast after 30 days
my $LOCAL_REFRESH=6*24*60*60; # Refresh local file manifest after 6 days
my $DEBUG=0;

# Logging variables
chomp (my $DATETIME=`date +%Y-%m-%d.%H.%M.%S`);
my $LOGDIR="/var/log/continuity/sync-wasabi";
my $LOGFILE="$LOGDIR/aws-upload-only-new-$DATETIME.log";
my $OFFSITE_DUMP="$LOGDIR/offsite";
my $LOCAL_DUMP="$LOGDIR/local";

# Validate $DIRLIST
my $TESTLIST="GOOD";

if ( "$DIRLIST" eq "" ) {
$TESTLIST="FALSE";
}

foreach my $DIRPATH ( split( ' ', $DIRLIST ) ) {
if ( $DEBUG ) { print "$DIRPATH\n"; }
if ( ! -d "/$DIRPATH" ) {
$TESTLIST="FALSE";
}
}

if ( "$TESTLIST" ne "GOOD" ) {
print "ERROR: need to specifiy a list of root directories to upload. \n";
print "EXAMPLE: ./aws-upload.sh data-continuity preservation-continuity <optional_bucket> <optional_aws_profile>\n";
exit 1;
}

sub get_dir_list {
my ($filelist, $boil_parent) = @_;
my %dirlist = ();

if ( defined( $boil_parent ) ) {
# Seed $dirlist so parent path is included:
my $index = rindex( $boil_parent, '/' );

if ( $index != -1 ) {
    $dirlist{ substr( $boil_parent, 0, $index ) } = 0;
}
}

if ( $DEBUG ) { print "PARENTBOIL= $boil_parent\n"; }

foreach my $file (@$filelist) {
my $subdir = substr( $file, 0, rindex( $file, '/' ) );

if ( $boil_parent && ! defined $dirlist{ $subdir } ) {
    my $parent = $subdir;
    my $subindex = 0;

    while( ( $subindex = rindex( $parent, '/' ) ) != -1 ) {
	$parent = substr( $parent, 0, $subindex );
	if ( ! defined( $dirlist{ $parent } ) ) {
	    if ( $DEBUG ) { print "PARENTDIR: $parent\n"; }
	    $dirlist{ $parent } = 0;
	}
    }
}
$dirlist{ $subdir }++;
}
return %dirlist;
}

sub get_dir_paths {
my ($filelist) = @_;
my %dirlist = ();

foreach my $file (@$filelist) {
my $subdir = substr( $file, 0, rindex( $file, '/' ) );
push @{ $dirlist{ $subdir } }, $file;
}
return %dirlist;
}

sub log_upload_err {
my ( $UPLOAD_SUCCESS, $UPLOAD_PATH ) = @_;

my $ERRMSG = "ERROR: uploading $UPLOAD_PATH, ";

if ( $UPLOAD_SUCCESS == -1 ) {
$ERRMSG .= "failed to launch.";
}
elsif ($UPLOAD_SUCCESS & 127) {
$ERRMSG .= sprintf "died with signal %d, %s coredump.",
($UPLOAD_SUCCESS & 127),  ($UPLOAD_SUCCESS & 128) ? 'with' : 'without';
}
else {
$ERRMSG .= sprintf "exited with value %d.", $UPLOAD_SUCCESS >> 8;
}
`echo "$ERRMSG" >> $LOGFILE 2>&1`;     
}

foreach my $DIRPATH ( split ( ' ', $DIRLIST ) ) {
my @pid = ();

my $LOGPATH = $DIRPATH;
# Replace / with - for log file names
$LOGPATH =~ s|/|-|g;

my $OFFSITE_DATETIME="$OFFSITE_DUMP-$LOGPATH-$DATETIME";
my $OFFSITE_LATEST="$OFFSITE_DUMP-$LOGPATH-latest.out";
my $OFFSITE_AGE=time() - (stat($OFFSITE_LATEST))[10];
my $LOCAL_DATETIME="$LOCAL_DUMP-$LOGPATH-$DATETIME";
my $LOCAL_LATEST="$LOCAL_DUMP-$LOGPATH-latest.out";
my $LOCAL_AGE=time() - (stat($LOCAL_LATEST))[10];

if ( ! -f "$OFFSITE_LATEST" || $OFFSITE_AGE > $OFFSITE_REFRESH) {
print "REBUILDING: $OFFSITE_DATETIME.out\n";
if ( ( $pid[0] = fork() ) == 0 ) {
   `aws $PROFILE --color auto s3 ls s3://$BUCKET/$DIRPATH --recursive --human-readable >$OFFSITE_DATETIME.out 2>$OFFSITE_DATETIME.err`;
   `ln -sf $OFFSITE_DATETIME.out $OFFSITE_LATEST`;
   exit 0;
}
}
if ( ! -f "$LOCAL_LATEST" || $LOCAL_AGE > $LOCAL_REFRESH) {
print "REBUILDING: $LOCAL_DATETIME.out\n";
if ( ( $pid[1] = fork() ) == 0 ) {
   print "EXEC: find /$DIRPATH -type f >$LOCAL_DATETIME.out 2>$LOCAL_DATETIME.err\n" if $DEBUG;
   `find /$DIRPATH -type f >$LOCAL_DATETIME.out 2>$LOCAL_DATETIME.err`;
   `ln -sf $LOCAL_DATETIME.out $LOCAL_LATEST`;
   exit 0;
}
}

if ( defined( $pid[0] ) ) {
waitpid( $pid[0], 0 );
}
if ( defined( $pid[1] ) ) {
waitpid( $pid[1], 0 );
}

print "LOADING OFFSITE: $OFFSITE_LATEST\n";
open( my $OFFSITE_FH, "< $OFFSITE_LATEST");
chomp( my @OFFSITE_LINES = <$OFFSITE_FH> );
close $OFFSITE_FH;

my %OFFSITE_LIST = ();
foreach my $LINE (@OFFSITE_LINES) {
my @LINE_ARRAY = $LINE =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)$/g;
if ( $DEBUG ) { print "OFFSITE_PATH: ".$LINE_ARRAY[-1]."\n"; }
$OFFSITE_LIST{ '/'.$LINE_ARRAY[-1] } = undef;
}

print "LOADING LOCAL: $LOCAL_LATEST\n";
open( my $LOCAL_FH, "< $LOCAL_LATEST");
chomp( my @LOCAL_LINES = <$LOCAL_FH> );
close $LOCAL_FH;

print "ANALYZING: files that need uploading\n";
my %LOCAL_LIST = map { ($_ => undef) } @LOCAL_LINES;

my @LOCAL_KEYS = keys %LOCAL_LIST;

print "CALCULATING: local dir list\n";
my %LOCAL_DIRS = &get_dir_list( \@LOCAL_KEYS );

print "CALCULATING: offsite dir list\n";
my @OFFSITE_KEYS = keys %OFFSITE_LIST;
my %OFFSITE_DIRS = &get_dir_list( \@OFFSITE_KEYS, '/'.$DIRPATH );

print "CALCULATING: local file list\n";
my @NEW_FILES = ();
foreach ( @LOCAL_KEYS ) {
push( @NEW_FILES, $_ ) unless exists $OFFSITE_LIST{$_};
}

my %NEW_DIRPATH_FILES = &get_dir_paths( \@NEW_FILES );
my @NEW_DIRPATH_DIRS = keys %NEW_DIRPATH_FILES;

my @UPLOAD_FILES = ();
my @UPLOAD_DIRS = ();

print "COMPARING: local and offsite dir list\n";
foreach my $DIR (keys %LOCAL_DIRS) {
# if the directory is offsite
if ( defined( $OFFSITE_DIRS{ $DIR } ) ) {
    if ( $OFFSITE_DIRS{ $DIR } != $LOCAL_DIRS{ $DIR } ) {
	if ( $DEBUG ) { print "DIRCOUNT: ".$DIR." ".$OFFSITE_DIRS{ $DIR }." != ".$LOCAL_DIRS{ $DIR }."\n"; }
	foreach my $FILE (@{$NEW_DIRPATH_FILES{ $DIR }}) {
	    if ( $DEBUG ) { print "UPLOAD_ADD_FILE: $FILE\n"; }
	    push @UPLOAD_FILES, $FILE;
	}
    }
}
# if the directory is not offsite and contains a bunch of files
else {
    # optimize down to the lowest parent dir that is not offsite
    my $parent = $DIR;
    my $subindex = 0;

    while( ! defined( $OFFSITE_DIRS{ $parent } ) &&
	   ( $subindex = rindex( $parent, '/' ) ) != -1 ) {
	$DIR = $parent;
	$parent = substr( $DIR, 0, $subindex );
	if ( $DEBUG ) { print "BOILDIR: $DIR\n"; }
    }

    push @UPLOAD_DIRS, $DIR;
}
}

print "OPTIMIZING: local dir list\n";

# one last optimization, see if nested dirs can be compacted:
@UPLOAD_DIRS = sort @UPLOAD_DIRS;

for ( my $i = 0; $i <= $#UPLOAD_DIRS; $i++) {
my $j = $i + 1; 
while ( 0 == index( $UPLOAD_DIRS[$j], $UPLOAD_DIRS[$i] ) ) { $j++; }
if ( $j > $i + 1 ) {
    my $splice_count = $j - $i - 1;
    if ( $DEBUG ) { print "SPLICING: $splice_count directories after $UPLOAD_DIRS[$i]\n"; }
    splice @UPLOAD_DIRS, $i + 1, $splice_count;
}
}

print "CALCULATED: ".(1+$#UPLOAD_FILES)." files need uploading\n";
if ( $DEBUG ) { print "UPLOAD_FILE: ".join( "\nUPLOAD_FILE: ", @UPLOAD_FILES )."\n"; }

print "CALCULATED: ".(1+$#UPLOAD_DIRS)." directories need uploading\n";
if ( $DEBUG ) { print "UPLOAD_DIR: ".join( "\nUPLOAD_DIR: ", @UPLOAD_DIRS )."\n"; }

next if ( $DEBUG );

`touch $LOGFILE`;
`ln -sf $LOGFILE $LOGDIR/upload-latest.log`; 

    # $DATE_TIME contains Y-M-D H.M.S instead of Y-M-D.H.M.S  
    my $DATE_TIME = $DATETIME;
    $DATE_TIME =~ s/\./ /;

    open( my $OFFSITE_APPEND_FH, ">> $OFFSITE_LATEST") || die "ERROR: could not append to file $OFFSITE_LATEST: $!";

    # UPLOAD directories by sequential calls to "aws sync <dir>"
    foreach my $UPLOAD_DIRPATH (@UPLOAD_DIRS) {

        print "UPLOADING_DIR: $UPLOAD_DIRPATH\n";
        
        `aws $PROFILE --color auto s3 sync "$UPLOAD_DIRPATH" "s3://$BUCKET$UPLOAD_DIRPATH"  --no-progress >>$LOGFILE 2>&1`;
        my $UPLOAD_SUCCESS = $?;
        
        if ($UPLOAD_SUCCESS == 0) {
            foreach my $DIRPATH ( grep { 0 == index( $_, $UPLOAD_DIRPATH ) } @NEW_DIRPATH_DIRS ) {
                foreach my $FILE ( @{$NEW_DIRPATH_FILES{ $DIRPATH }} ) {
                     my $NOSLASH_PATH = substr( $FILE, 1 );
                     print $OFFSITE_APPEND_FH "$DATE_TIME    0.0 SIZE $NOSLASH_PATH\n";
                }
            }
        }
        else {
            &log_upload_err( $UPLOAD_SUCCESS, $UPLOAD_DIRPATH );
        }
    }
    
    close( $OFFSITE_APPEND_FH );

    # Upload individual files by parralel instances of "aws cp <file>"
    print "UPLOADING_FILES\n";

    @pid = ();
    foreach my $UPLOAD_PATH (@UPLOAD_FILES) {

        my $child_pid = undef;
        if ( ( $child_pid = fork() ) == 0 ) {
            `aws $PROFILE --color auto s3 cp "$UPLOAD_PATH" "s3://$BUCKET$UPLOAD_PATH" --no-progress >>$LOGFILE 2>&1`;
            my $UPLOAD_SUCCESS = $?;
            if ($UPLOAD_SUCCESS == 0) {
                my $NOSLASH_PATH = substr( $UPLOAD_PATH, 1 );
                `echo "$DATE_TIME    0.0 SIZE $NOSLASH_PATH" >> $OFFSITE_LATEST 2>&1`;
            }
            else {
                &log_upload_err( $UPLOAD_SUCCESS, $UPLOAD_PATH );
            }
            
            exit 0;
        }
        elsif ( defined( $child_pid ) ) {
            push @pid, $child_pid;
        }

        if ( ( $#pid + 1 ) >= $PARALLEL_UPLOADS ) {
            my $finished_pid = wait();

            # delete the array element containing the finished child pid.
            grep { $pid[ $_ ] == $finished_pid } 0..$#pid;
        }
    }

    print "UPLOADING_DONE\n";
}
