# Bioperl module for Bio::Pipeline::RunnableDB
#
# Adapted from Michele Clamp's EnsEMBL::Pipeline
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::RunnableDB

=head1 SYNOPSIS

# get a Bio::Pipeline::RunnableDB object somehow

  $runnabledb->fetch_input();
  $runnabledb->run();
  $runnabledb->output();
  $runnabledb->write_output(); #writes to DB

=head1 DESCRIPTION

parameters to new
-job    A Bio::Pipeline::Job(required), 

This object wraps Bio::Pipeline::Runnables to add
functionality for reading and writing to databases.  The appropriate
Bio::Job object must be passed for extraction
of appropriate parameters.

=head1 CONTACT

bioperl-l@bioperl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::Pipeline::RunnableDB;

use strict;
use Bio::Root::Root;
use Bio::DB::RandomAccessI;

use vars qw(@ISA);

@ISA = qw(Bio::Root::Root);



=head2 new

    Title   :   new
    Usage   :   $self->new(-JOB => $job,
			              );
    Function:   creates a Bio::Pipeline::RunnableDB object
    Returns :   A Bio::Pipeline::RunnableDB object
    Args    :   -job:   A Bio::Pipeline::Job (required), 
=cut

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($dbobj,$analysis,$inputs,$output) = $self->_rearrange ([qw  (   
                                                                 DBOBJ
                                                                 ANALYSIS
                                                                 INPUTS
                                                                 OUTPUT
                                                                )],@args);
    
    $self->throw("No DB_obj provided to RunnableDB") unless defined($dbobj);
    $self->throw("No analysis provided to RunnableDB") unless defined($analysis);
    $self->throw("No inputs provided to RunnableDB") unless defined($inputs);
    $self->throw("No output adaptor provided to RunnableDB") unless defined($output);

    $self->dbobj($dbobj);
    $self->analysis($analysis);
    $self->runnable($analysis->runnable);
    $self->output_adaptor($output);

    $self->{'_input_objs'}=[];
    $self->{'_data_types'}=[];

    foreach my $input (@{$inputs}){
        my $input_obj = $input->fetch;
        my $datatype =  Bio::Pipeline::DataType->create_from_input($input_obj);
        $self->add_input_obj($input_obj);
    }

    $self->setup_runnable_inputs();
    $self->setup_runnable_params($analysis->parameters);

    return $self;
}

=head2 analysis

    Title   :   analysis
    Usage   :   $self->analysis($analysis);
    Function:   Gets or sets the stored Analusis object
    Returns :   Bio::Pipeline::Analysis object
    Args    :   Bio::Pipeline::Analysis object

=cut

sub analysis {
    my ($self, $analysis) = @_;
    
    if ($analysis)
    {
        $self->throw("Not a Bio::Pipeline::Analysis object")
            unless ($analysis->isa("Bio::Pipeline::Analysis"));
        $self->{'_analysis'} = $analysis;
    }
    return $self->{'_analysis'};
}

=head2 output_adaptor

    Title   :   output_adaptor
    Usage   :   $self->output_adaptor($analysis);
    Function:   Gets or sets the stored output_adaptor object
    Returns :   a output adaptor 
    Args    :   a output adaptor 

=cut

sub output_adaptor {
    my ($self,$value) = @_;
    if ($value){
        $self->{'_output_adaptor'} = $value;
    }
    return $self->{'_output_adaptor'};
}

sub setup_runnable_params {
    my ($self,$parameters) = @_;
    my @params = split("--",$parameters);
    shift @params; #first element is empty
    my %param;
    foreach my $param(@params){
      my @list = split(" ",$param);
      my $routine = shift @list;
      my $string = join " ",@list[0..$#list];
      $param{$routine} = $string;
    }
    #set the pamaters in the runnable
    my $runnable = $self->runnable;
    foreach my $routine (keys %param){
      eval {
        $runnable->$routine($param{$routine});
      };
      if($@) {

        $self->warn("Error setting up parameter $routine for analysis ".$self->analysis->logic_name." with message:\n $@\n");
      }
    }
    return;
}


=head2 dbobj

    Title   :   dbobj
    Usage   :   $self->dbobj($obj);
    Function:   Gets or sets the value of dbobj
    Returns :   A Bio::Pipeline::SQL::DBAdaptor object
    Args    :   A Bio::Pipeline::SQL:DBAdaptor compliant object

=cut

sub dbobj {
    my( $self, $value ) = @_;
    
    if ($value) 
    {
        $value->isa("Bio::Pipeline::SQL::DBAdaptor")
            || $self->throw("Input [$value] isn't a Bio::Pipeline::SQL::DBAdaptor");
        $self->{'_dbobj'} = $value;
    }
    return $self->{'_dbobj'};
}


=head2 add_input_obj

    Title   :   add_input_obj
    Usage   :   
    Function:   
    Returns :   
    Args    :   

=cut

sub add_input_obj{
    my ($self,$input_obj) = @_;

    push (@{$self->{'_input_objs'}},$input_obj);

}

=head2 input_objs

    Title   :   input_objs
    Usage   :   
    Function:   
    Returns :   
    Args    :   

=cut

sub input_objs{
    my ($self) = @_;

    return @{$self->{'_input_objs'}};

}

=head2 genseq

    Title   :   genseq
    Usage   :   $self->genseq($genseq);
    Function:   Get/set genseq
    Returns :   
    Args    :   

=cut

sub genseq {
    my ($self, $genseq) = @_;

    if (defined($genseq)){ 
	$self->{'_genseq'} = $genseq; 
    }
    return $self->{'_genseq'}
}


=head2 output

    Title   :   output
    Usage   :   $self->output()
    Function:   
    Returns :   Array of Bio::FeaturePair
    Args    :   None

=cut

sub output {
    my ($self) = @_;
   
    $self->{'_output'} = [];
    
    my @r = $self->runnable;

    if(defined (@r) && scalar(@r)){
      foreach my $r ($self->runnable){
	      push(@{$self->{'_output'}}, $r->output);
      }
    }
    return @{$self->{'_output'}};
}

=head2 setup_runnable_inputs

    Title   :   setup_runnable_inputs
    Usage   :   $self->setup_runnable_inputs()
    Function:   Checks the inputs with the runnable data types and set the runnable inputs 
    Returns :   None 
    Args    :   None 

=cut

sub setup_runnable_inputs {
    my ($self) = @_;
    my $runnable = $self->runnable;
    my %r_datatypes = $runnable->datatypes;
    my @inputs = $self->input_objs;

    my %match_datatype={};
  
    DT: foreach my $r_key (keys %r_datatypes){
        foreach my $in_obj(@inputs){
            next if exists $match_datatype{$in_obj};
            if ($self->match_data_type($in_obj,$r_datatypes{$r_key})) {
                $match_datatype{$in_obj}=1;
                #set runnables inputs
                $self->runnable->$r_key($in_obj);
                next DT;
            }
        }
        $self->throw("Job's inputs datatypes do not match runnable ".$self->runnable." datatypes.");
    }
}

=head2 match_data_type

    Title   :   match_data_type
    Usage   :   $self->match_data_type()
    Function:   checks an input whether it matches a data type object. It is handles inherited objects as matching 
                the parent.The input can be of type inherited from the type of the runnable but not the other
                way around 
    Returns :   None 
    Args    :   None 

=cut

sub match_data_type {
    my ($self,$input,$run_dt) = @_;
    my $in_dt = Bio::Pipeline::DataType->create_from_input($input);
    $run_dt->isa("Bio::Pipeline::DataType") || $self->throw("Need a Bio::Pipeline::DataType to check");

    #have to do this check cuz the isa call will barf it its not an valid object
    if ((ref($input) ne "SCALAR") && (ref($input) ne "ARRAY") && (ref($input) ne "HASH")){
      if ($input->isa($run_dt->object_type)){ 
        return 1;
      }
      else {
        return 0;
      }
    }
    elsif (($in_dt->object_type eq $run_dt->object_type) && ($in_dt->ref_type eq $run_dt->ref_type)){
      return 1;
    }
    else {
      return 0;
    }
}

=head2 run

    Title   :   run
    Usage   :   $self->run();
    Function:   Runs Bio::Pipeline::Runnable::xxxx->run()
    Returns :   none
    Args    :   none

=cut

sub run {
    my ($self) = @_;
    
    my $runnable = $self->runnable; 
    $self->throw("Runnable module not set") unless ($runnable);
    $self->throw("Inputs not fetched") unless ($self->input_objs());
    $runnable->run();
}


=head2 runnable

    Title   :   runnable
    Usage   :   $self->runnable($arg)
    Function:   Sets a runnable for this RunnableDB
    Returns :   Bio::Pipeline::RunnableI
    Args    :   Bio::Pipeline::RunnableI

=cut

sub runnable {
    my ($self,$arg) = @_;

    if (!defined($self->{'_runnable'})) {
       $self->{'_runnable'} = ();
    }
  
    if (defined($arg)) {
        
        #create empty runnable
        $arg =~ s/\::/\//g;
        require "${arg}.pm";
        $arg =~ s/\//\::/g;

        my $runnable = "${arg}"->new();
	      $self->{'_runnable'}=$runnable;

=jerm
        if ($runnable->isa("Bio::Pipeline::RunnableI")) {
        } else {
	        $self->throw("[$runnable] is not a Bio::Pipeline::RunnableI");
        }
=cut
     }
  
    return $self->{'_runnable'};  
}

=head2 vc

 Title   : vc
 Usage   : $obj->vc($newval)
 Function: 
 Returns : value of vc
 Args    : newvalue (optional)


=cut

sub vc {
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'_vc'} = $value;
    }
    return $obj->{'_vc'};

}


sub vcontig{
  my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'_vc'} = $value;
    }
    return $obj->{'_vc'};
}
 


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Writes output data to db
    Returns :   array of repeats (with start and end)
    Args    :   none

=cut

sub write_output {
    my($self) = @_;

    my $db=$self->dbobj();
    my @output = $self->output();
 
    $self->output_adaptor->write_output(\@output);
=head 
    foreach my $f (@features) {
	$f->analysis($self->analysis);
    }

    my $contig;
    eval 
    {
      $contig = $db->get_Contig($self->input_id);
    };

    if ($@) 
    {
	print STDERR "Contig not found, skipping writing output to db: $@\n";
    }
    elsif (@features) 
    {
	print STDERR "Writing features to database\n";

        my $feat_adp=Bio::DBSQL::FeatureAdaptor->new($db);
	$feat_adp->store($contig, @features);
    }
=cut
    return 1;
}

=head2 seqfetcher

    Title   :   seqfetcher
    Usage   :   $self->seqfetcher($seqfetcher)
    Function:   Get/set method for SeqFetcher
    Returns :   Bio::DB::RandomAccessI object
    Args    :   Bio::DB::RandomAccessI object

=cut

sub seqfetcher {
  my( $self, $value ) = @_;    
  if (defined($value)) {
    #need to check if passed sequence is Bio::DB::RandomAccessI object
    #$value->isa("Bio::DB::RandomAccessI") || 
    #  $self->throw("Input isn't a Bio::DB::RandomAccessI");
    $self->{'_seqfetcher'} = $value;
  }
    return $self->{'_seqfetcher'};
}

=head2 input_is_void

    Title   :   input_is_void
    Usage   :   $self->input_is_void(1)
    Function:   Get/set flag for sanity of input sequence
                e.g. reject seqs with only two base pairs
    Returns :   Boolean
    Args    :   Boolean

=cut

sub input_is_void {
    my ($self, $value) = @_;

    if ($value) {
	$self->{'_input_is_void'} = $value;
    }
    return $self->{'_input_is_void'};

}

=head2 verify_input_types

    Title   :   verify_input_types
    Usage   :   $self->verify_input_types
    Function:   
    Returns :   
    Args    :   

=cut

sub verify_input_types{
    my($self) = @_;

    my %match_datatype={};

    DT: foreach my $r_datatype ($self->runnable->datatypes){
        foreach my $input_datatype($self->datatypes){
            next if exists $match_datatype{$input_datatype}; 
            if ($input_datatype->match($r_datatype)){
                $match_datatype{$input_datatype}=1;
                next DT;
            }
        } 
        $self->throw("Job's inputs datatypes do not match runnable ".$self->runnable." datatypes.");
    }

}
    
=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   
    Returns :   
    Args    :   

=cut

sub fetch_input {
    my($self) = @_;

    my @inputs = $self->input_objs;

}

1;
