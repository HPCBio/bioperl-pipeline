# Interface for running programs
#
# Based on Bio::EnsEMBL::Pipeline::RunnableI originally written
# by Michele Clamp <michele@sanger.ac.uk>
#
# Cared for by Fugu Informatics team <fuguteam@fugu-sg.org>
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code


=head1 NAME

Bio::Pipeline::RunnableI;

=head1 SYNOPSIS

  #Do not run this module directly.

=head1 DESCRIPTION

This provides a standard BioPerl Pipeline Runnable interface that should be
implemented by any object that wants to be treated as a Runnable. This
serves purely as an abstract base class for implementers and can not
be instantiated.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                         - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR  

Based on Bio::EnsEMBL::Pipeline::RunnableI originally written
by Michele Clamp <michele@sanger.ac.uk>

Cared for by Fugu Informatics team <fuguteam@fugu-sg.org>

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut



package Bio::Pipeline::RunnableI;

use vars qw(@ISA);
use strict;


use Bio::Root::Root;
use Bio::Root::IO;
use Bio::Pipeline::DataType;
use Bio::Pipeline::PipeConf qw (NFSTMP_DIR);
use Bio::SeqIO;

@ISA = qw(Bio::Root::Root Bio::Root::IO);

=head1 ABSTRACT METHODS

These methods need to be implemented in any
module which implements L<Bio::Pipeline::RunnableI>.

This methods will be used by RunnableDB so they MUST be
implemeted to work properly.

=head2 datatypes

  my %datatype = $self->datatypes();

  Returns a hash of datatypes that describes the parameters
  keyed by the runnable routines that is called to set them.
  For example if there is a $runnable->seq function which takes
  in a Bio::Seq object, then one of the entries in the hash will
  be 
  $datatype{seq}=Bio::Pipeline::DataType=>(-object_type=>'Bio::Seq',
                                           -name=>'sequence',
                                           -reftype=>'SCALAR);

  This is used by RunnableDB to match the inputs provided with the inputs
  required by the runnable and calling the set methods accordingly. 

=head2 params

  $self->params("-C 10 -W 3")

  This is a get/set method to allow any string of parameters to be
  passed into the runnable without needing a explicit get/set method

=head2 parse_results

  $self->parse_results()

  This is called by the runnable itself to parse the results from
  the program output

=head2 parse_params

  $self->parse_params()

  This is a utility used to parse a string of the form "-p blastp -e 0.01"
  into an array of tag/value elements to be passed into the bioperl run functions.

=head2 run

    $self->run();

Actually runs the analysis programs.  If the
analysis has fails, it should throw an
exception.  It should also remove any temporary
files created (before throwing the exception!).

=head2 output

    @output = $self->output();

Return a list of objects created by the analysis

=cut


=head2 new

 Title   :   new
 Usage   :   $self->new()
 Function:
 Returns :
 Args    :

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($result_dir,$infile_suffix,$infile_dir) = $self->_rearrange([qw(RESULT_DIR INFILE_SUFFIX INFILE_DIR)],@args);
  $self->result_dir($result_dir) if $result_dir;
  $self->infile_suffix($infile_suffix) if $infile_suffix;
  $self->infile_dir($infile_dir) if $infile_dir;

  return $self;

}

sub datatypes {
  my ($self) = @_;
  $self->throw_not_implemented();
  return;
}
sub run {
  my ($self) = @_;
  $self->throw_not_implemented();
  return;
}
sub params {
  my ($self,$params) = @_;
  if ($params) {
      $self->{'_params'} = $params;
  }
  return $self->{'_params'};
}
sub parse_results {
  my ($self) = @_;
  $self->throw_not_implemented();
  return;
}
sub output {
  my ($self,$output) = @_;
  if(defined $output){
      $self->{'_output'} = $output;
  }
  return $self->{'_output'} ;
}

sub analysis{
  my ($self, $analysis) = @_;
  if($analysis) {
      $self->{'_analysis'} = $analysis;
  }
  return $self->{'_analysis'};
}
sub result_dir{
  my ($self, $result_dir) = @_;
  if($result_dir) {
      $self->{'_result_dir'} = $result_dir;
  }
  return $self->{'_result_dir'};
}
sub infile_dir {
  my ($self, $infile_dir) = @_;
  if($infile_dir) {
      $self->{'_infile_dir'} = $infile_dir;
  }
  return $self->{'_infile_dir'};
}
sub file{
  my ($self, $file) = @_;
  if($file) {
      $file = Bio::Root::IO->catfile($self->infile_dir,$file) if $self->infile_dir;
      $file = $file.$self->infile_suffix if $self->infile_suffix;
      $self->{'_file'} = $file;
  }
  
  return $self->{'_file'};
}

sub infile_suffix {
    my ($self,$val) = @_;
    if($val){
        $val = $val=~/^\.\S*/ ? $val : ".$val";
        $self->{'_infile_suffix'} = $val;
    }
    return $self->{'_infile_suffix'};
}

sub parse_params {
    my ($self,$string,$dash) = @_;
    $string = " $string"; #add one space for first param
    my @param_str = split(/\s-/,$string);
    shift @param_str;
    #parse the parameters
    my @params;
    foreach my $p(@param_str){
      my ($tag,$value) = $p=~/(\S+)\s+(\S+)/;
      if($dash){
        push @params, ("-".$tag,$value);
      }
      else {
        push @params, ($tag,$value);
      }

    }
    return @params;
}
1;
