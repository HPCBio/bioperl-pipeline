# $Id: .pm,v 1.51 Fri Jun 07 05:43:37 SGT 2002
# BioPerl module for 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::SQL::NodeGroupAdaptor - Desc

=head1 SYNOPSIS

    my $group = $self->db->get_NodeGroupAdaptor->fetch_by_dbID(1);
    my $nodes_ref = $group->nodes;
    
=head1 DESCRIPTION

Adaptor Object for fetching a NodeGroup


=head1 FEEDBACK


=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists. Your participation is much appreciated.

  bioperl-l@bioperl.org              - General discussion
  http://bio.perl.org/MailList.html  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bioperl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon


Email shawnh@fugu-sg.org


=head1 APPENDIX


The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a "_".

=cut


# Let the code begin...

package Bio::Pipeline::SQL::NodeGroupAdaptor;

use Bio::Pipeline::NodeGroup;
use Bio::Root::Root;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);

=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   : $self->fetch_by_dbID()
 Function: fetching the group of nodes using dbID
 Returns : L<Bio::Pipeline::NodeGroup>
 Args    : an int  

=cut

sub fetch_by_dbID {
  my ($self,$id) = @_;
  
  my $sth = $self->prepare("SELECT name,description FROM node_group where node_group_id=$id");
  $sth->execute();
  my ($name,$desc) = $sth->fetchrow_array();
  
  my @nodes = $self->db->get_NodeAdaptor->get_nodes_by_group_id($id);
    
  if(scalar(@nodes) == 0){
	@nodes = $self->db->get_NodeAdaptor->get_all_nodes();
  }
  my $group = Bio::Pipeline::NodeGroup->new('-id'=>$id,'-name'=>$name,'-description'=>$desc,'-nodes'=>\@nodes);
  return $group;
}

=head2 fetch_by_name

 Title   : fetch_by_name
 Usage   : $self->fetch_by_name()
 Function: fetching the group of nodes using name
 Returns : L<Bio::Pipeline::NodeGroup>
 Args    : an string

=cut

sub fetch_by_name {
    my ($self,$name) = @_;
    my $sth = $self->prepare("SELECT node_group_id FROM node_group WHERE name=$name");
    $sth->execute();
    my ($gid) = $sth->fetchrow_array();
    
    my $group = $self->fetch_by_dbID($gid);
    
    return $group;
}

=head2 fetch_default_group

 Title   : fetch_default_group
 Usage   : $self->fetch_default_group()
 Function: fetching the super group containing all nodes
 Returns : L<Bio::Pipeline::NodeGroup>
 Args    : 

=cut

sub fetch_default_group{
  my ($self) = @_;
  my @nodes = $self->db->get_NodeAdaptor->get_all_nodes();
  my $group = Bio::Pipeline::NodeGroup->new('-id'=>0,'-name'=>'All','-description'=>"All Nodes",'-nodes'=>\@nodes);

  return $group;
}
1;

