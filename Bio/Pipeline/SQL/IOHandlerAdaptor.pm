#
# BioPerl module for Bio::Pipeline::IOHandlerAdaptor
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME
Bio::Pipeline::IOHandlerAdaptor input/output adaptors object for pipeline

=head1 SYNOPSIS
my $in_adpt = Bio::Pipeline::IOHandlerAdaptor->new($db);


=head1 DESCRIPTION

The adaptor to get the input database adaptor 

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

=head1 AUTHOR - 

Email fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::SQL::IOHandlerAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::IOHandler;
use Bio::Pipeline::DataHandler;
use Bio::Pipeline::Argument;

@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);


=head 1 Fetch methods 
These methods retrievs the adaptors

=head2 fetch_by_dbID

  Title    : fetch_by_dbID
  Function : fetches the adaptor to the input adaptor 
  Example  : $in_adpt = $io ->fetch_by_dbID(1)
  Returns  : Bio::Pipeline::IO 
  Args     : a string which specifies the id of the adaptor 

=cut

sub fetch_by_dbID {
    my ($self,$dbID) = @_;
    $dbID || $self->throw("Need a db ID");
    
    my $sth = $self->prepare("SELECT 
                              dba.dbname,
                              dba.driver,
                              dba.host,
                              dba.user,
                              dba.pass,
                              dba.module
                              FROM iohandler io, dbadaptor dba
                              WHERE io.iohandler_id= '$dbID' AND
                              io.dbadaptor_id = dba.dbadaptor_id"
                              );
    $sth->execute();
    
    my ($dbname,$driver,$host,$user,$pass,$module)  = $sth->fetchrow_array;
    ($dbname && $module) || $self->throw("No DBadaptor found. Can't create an IO object without a dbadaptor");


    my $query = "SELECT datahandler_id, method, rank from datahandler
                 WHERE iohandler_id = $dbID";
    
    $sth = $self->prepare($query);
    $sth->execute();

    my @datahandlers;
    my $arg_sth= $self->prepare("SELECT argument_id, name,rank,type FROM argument WHERE datahandler_id=?");
    
    while (my ($datahandler_id, $method,  $rank) = $sth->fetchrow_array){
        $arg_sth->execute($datahandler_id);
        my @args;
        while(my ($argument_id,$name,$rank,$type) = $arg_sth->fetchrow_array){
          if($argument_id && $name && $rank && $type){
            my $arg = new Bio::Pipeline::Argument(-dbID => $argument_id,
                                                -rank => $rank,
                                                -name => $name,
                                                -type => $type);
            push @args, $arg;
          }
        }

        
        my $datahandler = new Bio::Pipeline::DataHandler    (   -dbID       => $datahandler_id,
                                                                -method     => $method,
                                                                -argument   => \@args,
                                                                -rank       => $rank
                                                              );
        push (@datahandlers,$datahandler);
    }
     
    my $iohandler = Bio::Pipeline::IOHandler->new(  -dbadaptor_dbname   =>$dbname,
                                                    -dbadaptor_driver   =>$driver,
                                                    -dbadaptor_host     =>$host,
                                                    -dbadaptor_user     =>$user,
                                                    -dbadaptor_pass     =>$pass,
                                                    -dbadaptor_module   =>$module,
                                                    -dbID               =>$dbID,
                                                    -datahandlers       =>\@datahandlers);

    $iohandler->adaptor($self);
                                    
    return $iohandler;
}


sub fetch_inputhandler_dbID_by_analysis{
    my ($self,$analysis_id) = @_;

    my $query = "   SELECT iohandler.iohandler_id
                    FROM   analysis_iohandler,iohandler
                    WHERE  analysis_id = ? 
                           and iohandler.type = 'INPUT'
                           and iohandler.iohandler_id= analysis_iohandler.iohandler_id";
    my $sth = $self->prepare($query);
    $sth->execute($analysis_id);

    my @dbIDs;

    while (my ($id) = $sth->fetchrow_array){
        push (@dbIDs,$id);
    }

    return @dbIDs;
}

1;


