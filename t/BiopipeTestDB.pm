
=pod

=head1 NAME - BiopipeTestDB

=head1 SYNOPSIS

    # Add test dir to lib search path
    use lib 't';
    
    use BiopipeTestDB;
    
    my $biopipe_test = BiopipeTestDB->new();
    
    # Load some data into the db
    $biopipe_test->do_sql_file("some_data.sql");
    
    # Get an Biopipe db object for the test db
    my $db = $biopipe_test->get_DBSQL_Obj;

=head1 DESCRIPTION

This is a module used just by the Bioperl test
suite to create a test database for a particular
test.  Creating a new object creates a database
with a name such that it should never clash with
other users testing on the same server.  The
database is destroyed when the object goes out of
scope.

The settings, such as the server host and port,
are found in the file B<Pipe.conf>.  See
B<Pipe.conf.example> for an example.

=head1 METHODS

=cut

package BiopipeTestDB;

use vars qw(@ISA);
use strict;
use Sys::Hostname 'hostname';
use Bio::Pipeline::SQL::DBAdaptor;
#use Bio::EnsEMBL::DBLoader;
use DBI;
use Carp;

#Package variable for unique database name
my $counter=0;

{
    # This is a list of possible entries in the config
    # file "BiopipeTestDB.conf" or in the hash being used.
    my %known_field = map {$_, 1} qw(
        driver
        host
        user
        port
        password
        schema_sql
        xml_script
        pipeline_manager
        module
        );

    ### now takes an optional argument; when given, it can be a filename
    ### or a hash, and will be used to get arguments from. If not, the
    ### file 'EnsTestDB.conf' will be tried; it it exist; that is taken;
    ### otherwise, some hopefully defaults will be used.
    sub new {
        my( $pkg, $arg ) = @_;

        $counter++;

        my $self =undef;
      	$self = do 'BiopipeTestDB.conf'
	              || {
                		'driver'        => 'mysql',
                		'host'          => 'localhost',
                		'user'          => 'root',
                		'port'          => '3306',
                		'password'      => undef,
                		'schema_sql'    => ['../sql/table.sql'],
                 		'module'        => 'Bio::Pipeline::SQL::DBAdaptor'
                		};
       	if ($arg) {
    	    if  (ref $arg eq 'HASH' ) {  # a hash ref
                foreach my $key (keys %$arg) {
          		    $self->{$key} = $arg->{$key};
            		}
    	    }
    	    elsif (-f $arg )  { # a file name
        		$self = do $arg;
    	    } else {
        		confess "expected a hash ref or existing file";
	        }
      	}
        
        foreach my $f (keys %$self) {
            confess "Unknown config field: '$f'" unless $known_field{$f};
        }
        bless $self, $pkg;
        $self->create_db;
	
        return $self;
    }
}

sub driver {
    my( $self, $value ) = @_;
    
    if ($value) {
        $self->{'driver'} = $value;
    }
    return $self->{'driver'} || confess "driver not set";
}

sub host {
    my( $self, $value ) = @_;
    
    if ($value) {
        $self->{'host'} = $value;
    }
    return $self->{'host'} || confess "host not set";
}

sub user {
    my( $self, $value ) = @_;
    
    if ($value) {
        $self->{'user'} = $value;
    }
    return $self->{'user'} || confess "user not set";
}

sub port {
    my( $self, $value ) = @_;
    
    if ($value) {
        $self->{'port'} = $value;
    }
    return $self->{'port'};
}

sub password {
    my( $self, $value ) = @_;
    
    if ($value) {
        $self->{'password'} = $value;
    }
    return $self->{'password'};
}

sub schema_sql {
    my( $self, $value ) = @_;
    
    if ($value) {
        push(@{$self->{'schema_sql'}}, $value);
    }
    return $self->{'schema_sql'} || confess "schema_sql not set";
}

sub xml_script {
    my ($self,$val) = @_;
    if($val){
        $self->{'xml_script'} = $val;
    }
    return $self->{'xml_script'} || confess 'Xml2Db.pl not set';
}

sub pipeline_manager {
    my ($self,$val) = @_;
    if($val){
        $self->{'pipeline_manager'} = $val;
    }
    return $self->{'pipeline_manager'} || confess 'PipelineManager.pl not set';
}

sub dbname {
    my( $self ) = @_;

    $self->{'_dbname'} ||= $self->_create_db_name();
    return $self->{'_dbname'};
}

# convenience method: by calling it, you get the name of the database,
# which  you can cut-n-paste into another window for doing some mysql
# stuff interactively
sub pause {
    my ($self) = @_;
    my $db = $self->{'_dbname'};
    print STDERR "pausing to inspect database; name of database is:  $db\n";
    print STDERR "press ^D to continue\n";
    `cat `;
}

sub module {
    my ($self, $value) = @_;
    $self->{'module'} = $value if ($value);
    return $self->{'module'};
}

sub _create_db_name {
    my( $self ) = @_;

    my $host = hostname();
    my $db_name = "_testdb_${host}_$$".$counter;
    $db_name =~ s{\W}{_}g;
    return $db_name;
}

sub create_db {
    my( $self ) = @_;
    
    ### FIXME: not portable between different drivers

    my $locator = 'DBI:'. $self->driver .':host='.$self->host;

    my $db = DBI->connect(
        $locator, $self->user, $self->password, {RaiseError => 1}
        ) or confess "Can't connect to server";

    my $db_name = $self->dbname;
    $db->do("CREATE DATABASE $db_name");
    $db->disconnect;
    
    
    $self->do_sql_file(@{$self->schema_sql});
}

sub db_handle {
    my( $self ) = @_;
    
    unless ($self->{'_db_handle'}) {
        $self->{'_db_handle'} = DBI->connect(
            $self->test_locator, $self->user, $self->password, {RaiseError => 1}
            ) or confess "Can't connect to server";
    }
    return $self->{'_db_handle'};
}

sub test_locator {
    my( $self ) = @_;
    
    my $locator = 'dbi:'. $self->driver .':database='. $self->dbname;
    foreach my $meth (qw{ host port password}) {
        if (my $value = $self->$meth()) {
            $locator .= ";$meth=$value";
        }
    }
    return $locator;
}

sub ensembl_locator {
    my( $self) = @_;
    
    my $module = ($self->module() || 'Bio::Pipeline::SQL::DBAdaptor');
    my $locator = '';

    foreach my $meth (qw{ host port dbname user password}) {

        my $value = $self->$meth();
	next unless defined $value;
        $locator .= ';' if $locator;
        $locator .= "$meth=$value";
    }
    $locator .= ";perlonlyfeatures=1";
   
    return "$module/$locator";
}

# return the database handle:
sub get_DBSQL_Obj {
    my( $self ) = @_;
    
    my $locator = $self->ensembl_locator();
    my $db =  Bio::EnsEMBL::DBLoader->new($locator);
    $db->dnadb($self->dnadb);
}

# return the database adaptor:
sub get_DBAdaptor {
    my( $self ) = @_;
    
    my $locator = $self->ensembl_locator();
    #my $dba =  Bio::Pipeline::SQL::DBAdaptor->new($locator);
    my $dba =  Bio::Pipeline::SQL::DBAdaptor->new($self->dbname,$self->host,$self->driver,$self->user,$self->password,$self->port);
    return $dba;
}

sub do_sql_file {
    my( $self, @files ) = @_;
    local *SQL;
    my $i = 0;
    my $dbh = $self->db_handle;

    my $comment_strip_warned=0;

    foreach my $file (@files)
    {
        my $sql = '';
        open SQL, $file or die "Can't read SQL file '$file' : $!";
        while (<SQL>) {
            # careful with stripping out comments; quoted text
            # (e.g. aligments) may contain them. Just warn (once) and ignore
            if (    /'[^']*#[^']*'/ 
                 || /'[^']*--[^']*'/ ) {
                     if ( $comment_strip_warned++ ) { 
                         # already warned
                     } else {
                         warn "#################################\n".
                           warn "# found comment strings inside quoted string; not stripping, too complicated: $_\n";
                         warn "# (continuing, assuming all these they are simply valid quoted strings)\n";
                         warn "#################################\n";
                     }
                 } else {
                s/(#|--).*//;       # Remove comments
            }
            next unless /\S/;   # Skip lines which are all space
            $sql .= $_;
            $sql .= ' ';
        }
        close SQL;
        
	#Modified split statement, only semicolumns before end of line,
	#so we can have them inside a string in the statement
	#\s*\n, takes in account the case when there is space before the new line
        foreach my $s (grep /\S/, split /;[ \t]*\n/, $sql) {
            #$self->validate_sql($s);
            $dbh->do($s);
            $i++
        }
    }
    return $i;
}                                       # do_sql_file

sub do_xml_file {
    my ($self,$file) = @_;
    $file || confess "Must pass in XML file";

    my $xml_script = "perl ".$self->xml_script;
    $xml_script .= " -dbhost ".$self->host if $self->host;
    $xml_script .= " -dbname ".$self->dbname if $self->dbname;
    $xml_script .= " -dbuser ".$self->user if $self->user;
    $xml_script .= " -schema ".@{$self->schema_sql}[0] if $self->schema_sql;
    $xml_script .= " -p ".$file ." -f\n";

    my $status = system($xml_script);
    confess ("Problem running $xml_script") if $status > 0;
    return;
}

sub run_pipeline {
    my ($self) = @_;
    my $manager = "perl ".$self->pipeline_manager;
    $manager.= " -dbname ".$self->dbname;
    $manager.=" -l -f ";
    my $status = system($manager);
    confess ("Problem running $manager ") if $status > 0;
    return;
}
    
    

sub validate_sql {
    my ($self, $statement) = @_;
    if ($statement =~ /insert/i)
    {
        $statement =~ s/\n/ /g; #remove newlines
        die ("INSERT should use explicit column names (-c switch in mysqldump)\n$statement\n")
            unless ($statement =~ /insert.+into.*\(.+\).+values.*\(.+\)/i);
    }
}

sub dnadb {
  my ($self,$dnadb) = @_;

  if (defined($dnadb)) {
     $self->{_dnadb} = $dnadb;
  }
  return $self->{_dnadb};
}


sub DESTROY {
    my( $self ) = @_;

    if (my $dbh = $self->db_handle) {
        my $db_name = $self->dbname;
        $dbh->do("DROP DATABASE $db_name");
        $dbh->disconnect;
    }
}

1;


__END__

=head1 AUTHOR

James Gilbert B<email> jgrg@sanger.ac.uk
