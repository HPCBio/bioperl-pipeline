# Pipeline module for Seg  Bio::Pipeline::Runnable::Seg
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Seg
# originally written by Marc Sohrmann (ms2@sanger.ac.uk)
# Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::Runnable::Seg

=head1 SYNOPSIS

 my $runnable = Bio::Pipeline::Runnable::Seg->new(@params);
 $runnable->analysis($analysis);
 $runnable->run;
 my $output = $runnable->output;

=head1 DESCRIPTION

Runnable for Seg

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to the
Bioperl mailing lists  Your participation is much appreciated.

  bioperl-l@bioperl.org                         - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via
email or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.bioperl.org/

=head1 AUTHOR

 Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Seg
 originally written by Marc Sohrmann (ms2@sanger.ac.uk)
 Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
 Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _.

=cut

package Bio::Pipeline::Runnable::Seg;
use vars qw(@ISA);
use strict;
use FileHandle;
use Bio::PrimarySeq;
use Bio::SeqFeature::FeaturePair;
use Bio::SeqFeature::Generic;
use Bio::SeqI;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::Seg;

@ISA = qw(Bio::Pipeline::RunnableI);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;

}

=head2 datatypes

 Title   :   datatypes
 Usage   :   $self->datatypes
 Function:   Returns the datatypes that the runnable requires.
 Returns :   It returns a hash of the different data types.
 Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::PrimarySeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my %dts;
    $dts{feat1} = $dt1;

    return %dts;
}


 
=head2 feat1

 Title   :   feat1
 Usage   :   $self->feat1($seq)
 Function:
 Returns :
 Args    :

=cut

sub feat1{
    my ($self,$feat) = @_;
    if (defined($feat)){
        $self->{'_feat1'} = $feat;
    }
    return $self->{'_feat1'};
}




=head2 run

 Title   :   run
 Usage   :   $self->run($seq)
 Function:   Runs Seg
 Returns :
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $seq = ($self->feat1);
  my $params = $self->params;

  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  my @params = $self->parse_params($self->analysis->parameters);
  
  $factory = Bio::Tools::Run::Seg->new(@params);
  

  my $program_file = $self->analysis->program_file;
  $factory->executable($program_file) if $program_file;
  
  my @genes;
  eval {
    @genes = $factory->predict_protein_features($seq);
  };
  $self->throw("Problems running predict_protein_featuers due to $@") if $@;
  
  $self->output(\@genes);
  
  return \@genes;

}

=head2 output


 Title   :   output
 Usage   :   $self->output($seq)
 Function:   Get/set method for output
 Returns :   
 Args    :   

=cut

sub output{
    my ($self,$gene) = @_;
    if(defined $gene){
      (ref($gene) eq "ARRAY") || $self->throw("Output must be an array reference.");
      $self->{'_gene'} = $gene;
    }
    return @{$self->{'_gene'}};
} 




