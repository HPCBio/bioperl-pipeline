#
# BioPerl module for Bio::Pipeline::IOHandler
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME
Bio::Pipeline::IOHandler input/output object for pipeline


=head1 SYNOPSIS

=head1 DESCRIPTION

The input/output handler for reading input and writing output.
Basically the goal of the IOHandler object is to represent a
series of method calls that are needed to fetch a particular input. 
Methods are represented by DataHandler objects which in term have
argument objects. Datahandlers are rank in the order that they
are cascaded, likewise for arguments.


=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org          - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org 

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::IOHandler;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new_ioh_db

  Title   : new_ioh_db
  Usage   : my $io = Bio::Pipeline::IOHandler->new(-dbadaptor=>$dbadaptor,
                                            -dataadaptor=>$datahandler,
                                            -dataadaptormethod=>$datahandler_method);
 
  Function: generates a new Bio::Pipeline::IOHandler for DB connections
  Returns : a new IOHandler object 
  Args    : dbadaptor to database #note dbadaptor and biodbadaptor are mutally exclusive
            biodbadaptor external biodb adaptor
            biodbname name of biodb
            dataadaptor the adaptor for the object (example Bio::EnsEMBL::DBSQL::ProteinAdaptor)
            dataadaptormethod the method to fetch the object (example fetch_by_dbID)
=cut

sub new_ioh_db {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$type,$dbadaptor_dbname,$dbadaptor_driver,$dbadaptor_host,
      $dbadaptor_user,$dbadaptor_pass,$dbadaptor_module,$dbadaptor_port,
      $datahandlers) = $self->_rearrange([ qw( DBID
                                               TYPE
                                                DBADAPTOR_DBNAME
                                                DBADAPTOR_DRIVER
                                                DBADAPTOR_HOST
                                                DBADAPTOR_USER
                                                DBADAPTOR_PASS
                                                DBADAPTOR_MODULE
                                                DBADAPTOR_PORT
                                                DATAHANDLERS)],@args);

  $dbadaptor_dbname ||= $self->throw("Need a dbadaptor name");
  $dbadaptor_driver ||= "mysql";
  $dbadaptor_user   ||= "root";
  $dbadaptor_host   ||= "localhost";
  $dbadaptor_pass   ||= "";
  $dbadaptor_port   ||= "";
  $dbadaptor_module || $self->throw("Need a module for db adaptor");
  $datahandlers     || $self->throw("Need datahandlers in IOHandler constructor");

  $self->dbID($dbID);
  $self->dbadaptor_dbname($dbadaptor_dbname);
  $self->dbadaptor_driver($dbadaptor_driver);
  $self->dbadaptor_host($dbadaptor_host);
  $self->dbadaptor_user($dbadaptor_user);
  $self->dbadaptor_pass($dbadaptor_pass);
  $self->dbadaptor_port($dbadaptor_port);
  $self->dbadaptor_module($dbadaptor_module);
  $self->adaptor_type("DB");
  $self->type($type);
  @{$self->{'_datahandlers'}} = @{$datahandlers}; 
  
  return $self;
}    


=head2 new_ioh_stream

  Title   : new_ioh_stream
  Usage   : my $io = Bio::Pipeline::IOHandler->new(-dbadaptor=>$dbadaptor,
                                            -dataadaptor=>$datahandler,
                                            -dataadaptormethod=>$datahandler_method);
  Function: generates a new Bio::Pipeline::IOHandler for streams(files or remote fetching) 
  Returns : a new IOHandler object 
  Args    : module a string of the form Bio::XXX 
            datahandlers array of L<Bio::Pipeline::DataHandler> 
=cut

sub new_ioh_stream{
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($dbID,$type,$module,$datahandlers) = $self->_rearrange([qw(DBID
                                                       TYPE
                                                       MODULE
                                                       DATAHANDLERS)],@args);

    $module  || $self->throw("Need a stream module");

    $self->dbID($dbID);
    $self->stream_module($module);

    $self->adaptor_type("STREAM");
    $self->type($type);
    @{$self->{'_datahandlers'}} = @{$datahandlers};

    return $self;
} 
                                                    
=head1 Fetch/Write methods 
These methods calls adaptors to fetch and write inputs and outputs to database
=cut

=head2 fetch_input 

  Title    : fetch_input
  Function : fetches the input(s) from the adaptors supplied 
  Example  : $contig = $io ->fetch_input("Scaffold_1");
  Returns  : a array ref to the inputs 
  Args     : a string/array ref of strings which specifies the id of the input 

=cut

sub fetch_input {
    my ($self,$input) = @_;
    $input || $self->throw("Need a input object");
    my $input_name = $input->name;

    #hash up the dynamic arguments by datahandler id
    my %dyn_arg;

    if($input->dynamic_arguments){
        foreach my $arg (@{$input->dynamic_arguments}){
            defined $arg->dhID || $self->throw("dynamic arguments much have a datahandler id");
            push @{$dyn_arg{$arg->dhID}},$arg;
        }
    }

    my @datahandlers= sort {$a->rank <=> $b->rank}$self->datahandlers;

    # the datahandlers work this way:
    # each datahandler has an argument. 
    # If this variable is eq 'INPUT', the argument for the datahandlers
    # will be the input name found in the Input table.
    # If this variable is some other string, the argument will be this string
    # If the variable argument is empty, it means that this datahandler call requires
    # no argument.
    #
    # eg. to fetch a sequence from biosql,
    # the datahandlers required will look like that:
    # $datahandler_1( -method=> 'get_BioDatabaseAdaptor'
    #                  -argument=> ''
    #                  -rank => 1 )
    # $datahandler_2 ( -method=> 'fetch_BioSeqDatabase_by_name'
    #                   -argument=> 'swissprot'
    #                   -rank => 2 )
    # 
    # $datahandler_3 ( -method=> 'get_Seq_by_acc'
    #                   -argument=> 'INPUT'
    #                   -rank => 3 )
    #   where the arguement will be the input_name attached to the input object.
    # 
    # if say, what is desired are the genes annotated on this sequence,
    # then an additional datahandler is required,
    #
    # $datahandler_4 ( -method=> 'get_all_genes'
    #                   -argument=> ''
    #                   -rank => 4)
    #                   
    #   

    my $obj; 
    #create the handler fetcher differently depending on whether its a DB or a Stream
    if($self->adaptor_type eq "DB"){
        $obj = $self->_fetch_dbadaptor();
    }
    else {
        my $constructor = shift @datahandlers;
        my @arguments = sort{$a->rank <=> $b->rank} @{$constructor->argument};
        my @args = $self->_format_input_arguments($input_name,@arguments);
        $obj = $self->_create_obj($self->stream_module,$constructor,@args);
    }

    #now call the cascade of datahandler methods
    my $tmp = $obj;
    foreach my $datahandler (@datahandlers) {
        my @arguments = sort {$a->rank <=> $b->rank} @{$datahandler->argument};
        my @dyn_arg;
        if(ref($dyn_arg{$datahandler->dbID}) eq "ARRAY"){
          @dyn_arg = @{$dyn_arg{$datahandler->dbID}};
        }
        if($#dyn_arg > 0){
          #merge arguments if dynamic arguments exist
          @arguments = $self->_merge_args(\@arguments,\@dyn_arg);
        }

        my @args = $self->_format_input_arguments($input_name,@arguments);
        my $tmp1 = $datahandler->method;
        my @obj = $obj->$tmp1(@args);
        if(scalar(@obj) == 1){
          $obj = $obj[0];
        }
        else {
          $obj = \@obj;
        }
    }

    if (defined $self->converters) {
      my @converters = sort {$a->rank <=> $b->rank} @{$self->converters};
      foreach my $converter(@converters){
          $obj = $converter->convert($obj);
      }
    }
  return $obj;
}

sub _merge_args {
    my ($self,$arg,$dyn) = @_;
    my @final;
    foreach my $static(@{$arg}){
        $final[$static->rank] = $static;
    }
    my @copy = @{$dyn};
    foreach my $dynamic (@{$dyn}){
        for (my $i = 1; $i <=$#final; $i++){
          if(!defined $final[$i]){
              $final[$i] = $dynamic;
              shift @copy;
              last;
         }
       }
    }
    if($#copy > 0){
      push @final, @copy;
    }

  return @final;
}


#method used to fetch input ids, used to handle array of inputs fetched
#may be hacky but will do for now. shawn

sub fetch_input_ids {
    my ($self,$param) = @_;

    my @datahandlers= sort {$a->rank <=> $b->rank}$self->datahandlers;
    my $obj;
    #create the handler fetcher differently depending on whether its a DB or a Stream
    if($self->adaptor_type eq "DB"){
        $obj = $self->dbadaptor;
    }
    else {
        my $constructor = shift @datahandlers;
        my @arguments = sort{$a->rank <=> $b->rank} @{$constructor->argument};
        my @args = $self->_format_input_arguments($param,@arguments);
        $obj = $self->_create_obj($self->stream_module,$constructor,@args);
    }

    #now call the cascade of datahandler methods
    my $tmp = $obj;
    for (my $i = 0; $i < $#datahandlers; $i++){
        my $dh = $datahandlers[$i];
        my @arguments = sort {$a->rank <=> $b->rank} @{$dh->argument};
        my @args = $self->_format_input_arguments($param,@arguments);
        my $tmp1 = $dh->method;
        $obj= $obj->$tmp1(@args);
    }
    
    #now get the ids
    my $last = $datahandlers[$#datahandlers]->method;
    my @arguments = sort {$a->rank <=> $b->rank} @{$datahandlers[$#datahandlers]->argument};
    my @args = $self->_format_input_arguments($param,@arguments);
    my @ids = $obj->$last(@args);

    #destroy handle only if its a dbhandle
    if($self->adaptor_type eq "DB") {$tmp->DESTROY};

  return \@ids;
}


sub _format_input_arguments {
  my ($self,$input_name,@arguments) = @_;
  my @args;
  for (my $i = 0; $i <=$#arguments; $i++){
    if ($arguments[$i]->value eq 'INPUT') {
      if ($arguments[$i]->tag){
        push @args, ($arguments[$i]->tag => $input_name);
      }
      else {
        push @args, $input_name;
      }
    }
    else {
      if($arguments[$i]->tag){
        push @args, ($arguments[$i]->tag => $arguments[$i]->value);
      }
      else {
        push @args, $arguments[$i]->value;
      }
    }
  }
  return @args;
}



=head2 write_output

  Title    : write_output 
  Function : writes the output to database using the adaptors supplied 
  Example  : $io ->write_output($gene);
  Returns  : 
  Args     : an object/array ref to objects to be stored 

=cut

sub write_output {
    my ($self, $input,$object) = @_;
    $object || $self->throw("Need an object to write to database");


    # the datahandlers for an output handler works in the same principle as the
    # input datahandlers. please see above
    
    my @datahandlers= sort {$a->rank <=> $b->rank}$self->datahandlers;
    my $obj;
    if($self->adaptor_type eq "DB"){
        $obj = $self->_fetch_dbadaptor();
    }
    else {
        my $constructor = shift @datahandlers;
        my @arguments = sort{$a->rank <=> $b->rank} @{$constructor->argument};
        my @args = $self->_format_output_args($input,$object,@arguments);
        $obj = $self->_create_obj($self->stream_module,$constructor,@args);
    }

    # safety check ? Maybe this check should be made before the runnable is even ran
    #    $self->warn ("Last output datahandler does not seem to be a STORE function. Strange.")
    #       unless ($datahandlers[$#datahandlers]->argument eq 'OUTPUT');

    my @output_ids;
    my $output_flag = 0;
    
    foreach my $datahandler (@datahandlers) {
        my @arguments = sort {$a->rank <=> $b->rank} @{$datahandler->argument};
        my @args;
        my $tmp1 = $datahandler->method;
        @args = $self->_format_output_args ($input,$object,@arguments);
        @output_ids = $obj->$tmp1(@args);
        $obj = $output_ids[0];
    }
    if (defined $self->converters) {
      my @converters = sort {$a->rank <=> $b->rank} @{$self->converters};
      foreach my $converter(@converters){
          @output_ids = $converter->convert($obj);
          $obj = $output_ids[0];
      }
    }
  return @output_ids;
}

#needs some cleaning up --shawn
sub _format_output_args {
    my ($self,$input,$object,@arguments) = @_;
    my @args;
    my $value;
    for (my $i = 0; $i <=$#arguments; $i++){
      #pass output object
      if ($arguments[$i]->value eq 'OUTPUT'){
        $value = $object
      }
      #pass input id
      elsif($arguments[$i]->value eq 'INPUT'){
	      my @names;
	      foreach my $in (@{$input}){
		      push @names, $in->name;
	      }
          $value = \@names;
      }
      #pass input obj
      elsif($arguments[$i]->value eq 'INPUTOBJ'){
	      my @values;
	      foreach my $in (@{$input}){
		      push @values, $in->fetch;
	      }
	      $value = \@values;
      }
      #just pass the value
      else {
        $value = $arguments[$i]->value;
      }

      #if there are tags
      if($arguments[$i]->tag){
        if($arguments[$i]->type eq "ARRAY"){
            #if your method expects an array
            if(ref($value) eq "ARRAY"){
                push @args, ($arguments[$i]->tag => @{$value});
            }
            else {
                my @array;
                push @array, $value;
                push @args, ($arguments[$i]->tag => @array);
            }
        }
        else {
            push @args, ($arguments[$i]->tag => $value);
        }
      } 
      #no tags needed
      else {
        if($arguments[$i]->type eq "ARRAY"){
          if(ref($value) eq "ARRAY"){
            push @args, @{$value};
          }
          else {
              push @args, $value;
          }
        }
        else {
              push @args, $value;
        }
      }
    }
    return @args;
}


=head1 Member variable access

These methods let you get at and set the member variables

=head2 dbadaptor 

  Title    : dbadaptor 
  Function : returns/sets the dbadaptor object 
  Example  : $io->dbadaptor($db); 
  Returns  : the dbadaptor 
  Args     : optionally, the new dbadaptor 

=cut
 
sub dbadaptor {
    my ($self) = @_;
    if(!$self->{'_dbadaptor'}){
        $self->{'_dbadaptor'} = $self->_fetch_dbadaptor;
    }
    return $self->{'_dbadaptor'};
}

=head2 datahandlers 

  Title    : datahandler 
  Function : returns the datahandlers associated with this IOHandler onbject
  Example  : $io->datahandlers(); 
  Returns  : the datahandlers 
  Args     : 

=cut

sub datahandlers {
    my ($self) = @_;
    return @{$self->{'_datahandlers'}};
}

sub dbadaptor_dbname {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_dbname'} = $value;
  }
  return $self->{'_dbadaptor_dbname'};
}

#get/set methods for dbadaptor params
sub dbadaptor_driver {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_driver'} = $value;
  }
  return $self->{'_dbadaptor_driver'};
}

sub dbadaptor_user {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_user'} = $value;
  }
  return $self->{'_dbadaptor_user'};
}

sub dbadaptor_pass {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_pass'} = $value;
  }
  return $self->{'_dbadaptor_pass'};
}
sub dbadaptor_port{
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_port'} = $value;
  }
  return $self->{'_dbadaptor_port'};
}
sub dbadaptor_module {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_module'} = $value;
  }
  return $self->{'_dbadaptor_module'};
}
sub dbadaptor_host {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_host'} = $value;
  }
  return $self->{'_dbadaptor_host'};
}
sub stream_module{
    my ($self,$value) = @_;
    if($value) {
        $self->{'_filemodule'} = $value;
    }
    return $self->{'_filemodule'};
}

sub adaptor_type {
    my ($self,$value) = @_;
    if($value) {
        $self->{'_dbtype'} = $value;
    }
    return $self->{'_dbtype'};
}

sub type {
    my ($self,$value) = @_;
    if($value) {
        $self->{'_iotype'} = $value;
    }
    return $self->{'_iotype'};
}
sub _fetch_dbadaptor {
    my ($self,) = @_;
    my $dbname = $self->dbadaptor_dbname();
    my $driver = $self->dbadaptor_driver();
    my $host   = $self->dbadaptor_host();
    my $user   = $self->dbadaptor_user();
    my $pass   = $self->dbadaptor_pass();
    my $module = $self->dbadaptor_module();
    my $port   = $self->dbadaptor_port();

    if($module =~/::/)  {
         $module =~ s/::/\//g;
         require "${module}.pm";
         $module =~s/\//::/g;
    }
    
    my $db_adaptor = "${module}"->new(-dbname=>$dbname,-user=>$user,-host=>$host,-driver=>$driver,-pass=>$pass,-port=>$port);

    return $db_adaptor;
}

sub _create_obj {
    my ($self,$module,$method,@args) = @_;
    $module || $self->throw("Need an object to create object");
    $method || $self->throw("Need a method call");

    if($module=~/::/){
        $module =~ s/::/\//g;
        require "${module}.pm";
        $module =~s/\//::/g;
    }
    my $obj = "${module}"->new(@args);

    return $obj;
}
    

sub _fetch_fileadaptor {
    my ($self) = @_;
    my $filename = $self->filename;
    my $filemodule = $self->filemodule;
    $filename || $self->throw("No filename specified. You probably wanna use _fetch_dbadaptor");
    $filemodule || $self->throw("No file module specified. You probably wanna use _fetch_dbadaptor");

    if($filemodule=~/::/){
        $filemodule =~ s/::/\//g;
        require "${filemodule}.pm";
        $filemodule =~ s/\//::/g;
    }
    my $f_adaptor = "${filemodule}"->new(-filename=>$filename);
    $f_adaptor->make_index;
    return $f_adaptor;
}


=head2 dbID

  Title   : dbID
  Usage   : $self->dbID($id)
  Function: get set the dbID for this object, only used by Adaptor
  Returns : int
  Args    : int

=cut


sub dbID {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{'_dbID'} = $arg;
    }
    return $self->{'_dbID'};

}

=head2 adaptor

  Title   : adaptor
  Usage   : $self->adaptor
  Function: get database adaptor, set only for constructor and adaptor usage.
  Returns :
  Args    :

=cut


sub adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
    $self->{'_adaptor'} = $arg;
    }
    return $self->{'_adaptor'};

}

sub converters {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{'_converters'} = $arg;
    }
    return $self->{'_converters'};

}


1;



    
          
