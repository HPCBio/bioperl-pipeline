#
# BioPerl module for Bio::Pipeline::InputCreate
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME
Bio::Pipeline::InputCreate
Filter object used for encasulating different input creating functions.
Part of DataMonger Object.


=head1 SYNOPSIS

=head1 DESCRIPTION

Object used for encapsulating "hacky" processing needed to setup
input and job tables. Pluggable into DataMonger object

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

package Bio::Pipeline::InputCreate;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

=head2 new

  Title   : new
  Usage   : my $inc = Bio::Pipeline::InputCreate->new('-module'=>$module,'-rank'=>$rank,'-dbadaptor'=>$self->db)
  Function: constructor for InputCreate object 
  Returns : a new InputCreate object
  Args    : module, the list of inputcreate modules found in Bio::Pipeline::Filter::*
            rank specifies the order in which to apply the inputcreate in relation to others
            dbadaptor provides the handle to the pipeline database

=cut

sub new {
    my ($caller ,@args) = @_;
     my $class = ref($caller) || $caller;

    # or do we want to call SUPER on an object if $caller is an
    # object?
    if( $class =~ /Bio::Pipeline::InputCreate::(\S+)/ ) {
      my ($self) = $class->SUPER::new(@args);
      $self->_initialize(@args);
      return $self;
    }
    else {
      my %param = @args;
      @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
      my $module= $param{'-module'};
      $module || Bio::Root::Root->throw("Must you must provided a InputCreate module found in Bio::Pipeline::InputCreate::*");

      $module = "\L$module";  # normalize capitalization to lower case
      return undef unless ($class->_load_inputcreate_module($module));
      return "Bio::Pipeline::InputCreate::$module"->new(@args);
    }
}

sub _initialize {
  my ($self,@args) = @_;
  my ($dbadaptor,$analysis) = $self->_rearrange([qw(DBADAPTOR)],@args);

  $dbadaptor || $self->throw("InputCreate needs a dbadaptor to create new jobs and inputs");

  $self->dbadaptor($dbadaptor);
}

=head2 _load_inputcreate_module

  Title   : _load_inputcreate_module
  Usage   : $inc->_load_inputcreate_module("setup_genewise");
  Function: loads the input create module 
  Returns : a new InputCreate object
  Args    : module, the name of the module found in Bio::Pipeline::InputCreate

=cut

sub _load_inputcreate_module {
    my ($self, $module) = @_;
    $module = "Bio::Pipeline::InputCreate::" . $module;
    my $ok;

    eval {
      $ok = $self->_load_module($module);
    };
    if ($@) {
    print STDERR <<END;
$self: $module cannot be found
Exception $@
For more information about the Bio::Pipeline::InputCreate system please see the pipeline docs 
This includes ways of checking for formats at compile time, not run time
END
  ;
  }
  return $ok;
}

=head2 create_input

  Title   : create_input
  Usage   : $inc->create_input("inputname","3");
  Function: utility method for creating Bio::Pipeline::Input objects 
  Returns : L<Bio::Pipeline::Input>
  Args    : name: the name of the input
            ioh : the iohandler dbID of the input

=cut

sub create_input {
    my ($self,$name,$ioh) = @_;
    $name || $self->throw("Need an input name to create input");

    my $input_obj = Bio::Pipeline::Input->new(-name => $name,
                                              -input_handler => $ioh);

    return $input_obj;
}

=head2 create_job

  Title   : create_job
  Usage   : $inc->create_job($analysis,[$input1,$input2]);
  Function: utility method for creating Bio::Pipeline::Job objects
  Returns : L<Bio::Pipeline::Job >
  Args    : analysis: a L<Bio::Pipeline::Analysis> object
            inputs: an array ref to the list of input belonging to the job

=cut


sub create_job {
    my ($self,$analysis,$input_objs) = @_;
    
    my $job = Bio::Pipeline::Job->new(-analysis => $analysis,
                                      -adaptor =>  $self->dbadaptor->get_JobAdaptor,
                                      -inputs => $input_objs);
    return $job;
}

=head2 datatypes 

  Title   : datatypes
  Usage   : $inc->datatypes 
  Function: abstract method for returing the datatypes required by InputCreate object
  Returns : 
  Args    :

=cut

sub datatypes {
  my ($self) = @_;
  $self->throw_not_implemented();
}

=head2 run

  Title   : run
  Usage   : $self->run();
  Function: abstract method for running the module 
  Returns :
  Args    :

=cut

sub run {
  my ($self) = @_;
  $self->throw_not_implemented();
}

=head2 dbadaptor

  Title   : dbadaptor
  Usage   : $self->dbadaptor();
  Function: get/set for dbadaptor 
  Returns :
  Args    :

=cut

sub dbadaptor {
  my ($self,$dbadaptor) = @_;

  if($dbadaptor){
    $self->{'_dbadaptor'} = $dbadaptor;
  }
  return $self->{'_dbadaptor'};
}

1;
