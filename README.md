# BioPipe v2

The original Bioperl pipeline framework was a flexible workflow system that
complements the Bioperl package by providing job management facilities for high
throughput sequence analysis. At the time it was also known as Biopipe. This
system was heavily inspired by the EnsEMBL Pipeline system.

This new endeavour is a rewrite of BioPipe to focus on the following:

* Conversion to Moose, with possible conversion to Perl 6
* Adoption of the [Common Workflow Language](https://github.com/common-workflow-language/common-workflow-language)
* Possible adoption of [HPCI](https://metacpan.org/pod/HPCI) 

The original installation documentation is currently not available via the
original BioPipe web site, though we may update documenation locally or through
other resources like ReadTheDocs.

## Biopipe Install Directions

### System Requirements and Installation

- Tested on:
  - Mac OS X (development, local jobs only)
  - Linux (soon-ish)

- [Perl](http://perl.org) 5.10 or later

- [MySQL database](http://www.mysql.com)

  BioPipe relies on a MySQL database for its job management and tracking. This
  allows persistence of most operations inherent to the pipeline, which in turn
  allows the pipeline to restart seemlessly even after an abrupt halt due to
  some system failure (e.g. network problems, power cut, and so on). Obtain
  MySQL from wwww.mysql.com and refer to the MySQL documentation for
  installation instructions. Once MySQL is installed and running you can create
  the bioperl-pipeline database.

- Load Sharing Software

  The bioperl-pipeline can be run locally on your own machine without load-sharing 
  software and will still manage the logic and workflow of your analysis runs. However 
  to truly harness the bioperl-pipeline's power you will need either:

  - [LSF](http://www.platform.com/) (Load Sharing Facility) a commercial package, but very cheap or free for small academic setups. 
  - [PBS](http://pbs.mrj.com/) (Portable Batch System) Freely Available for the Open PBS version. 

Without load-sharing you will be running your jobs in 'local' mode. 
Each job is then run  sequentially but this is not recommended for high throughput analysis.

- Bioperl Packages:

  **Note**: the requirement for these may be removed in the future to allow
  for more flexibility in job submission scripts

  - bioperl-live 
  - bioperl-run  
  - bioperl-pipeline - Git only at the moment
  - Bio-Coordinate - Git only at the moment
  - **Recommended but not required**: bioperl-db and biosql-schema

### Installation

Install the bioperl-pipeline package as follows:

```
 >cd bioperl-pipeline
 >perl Makefile.PL
 >make
```

Before doing make test, ensure that you modify the following files to reflect
your system specifics:

1. bioperl-pipeline/t/BiopipeTestDB.conf
2. bioperl-pipeline/Bio/Pipeline/PipeConf.pm

In particular, ensure that your mysql configurations are correct.
Having done, so, you may continue :

```
>make test
>make install
```

To create a MySQL pipeline database:

```
>mysqladmin -u root create biopipe
```

To create the pipeline database tables:

```
>cd bioperl-pipeline
>mysql -u <user> biopipe < sql/schema.sql
```

Biopipe databases are automatically created when pipelines are run(mysql configuration
read from PipeConf.pm) , so this is a useful test but not necessary for installation.

Although recommended, you do not need to install the packages. You may simply put them into
a directory and point to them in your PERL5LIB environment variable like so (if using `bash`):

```
### UNTESTED!!!!
export BIOPERL_BASE=/User/cjfields/bioperl
export PERL5LIB "$BIOPERL_BASE/bioperl-pipeline:$BIOPERL_BASE/bioperl-run:$BIOPERL_BASE/bioperl-1-2-1:$BIOPERL_BASE/bioperl-db-1-1-0:
```

For detailed instructions on installing Bioperl please refer to the INSTALL document
in bioperl-live or in the latest Bioperl release. This document discusses issues like
installation into non-standard locations or how to install a Perl package if you don't
have root access (Unix).

- Perl Packages - available at http://www.metacpan.org

  - [XML::SimpleObject](https://metacpan.org/pod/XML::SimpleObject)
  
    Required, may be replaced by other parsers
    
  - [XML::Parser](https://metacpan.org/pod/XML::Parser) or [XML::SAX::PurePerl](https://metacpan.org/pod/XML::SAX::PurePerl) 
  
    Either one is required.
    
    Note XML:Parser requires Expat installed and some parties have had problems
    getting this installed. As an alternative solution, XML::SAX::PurePerl doesn't
    require Expat and this is a viable alternative. The latter is of course slower
    but XML parsing only takes up a minute portion of biopipe and thus 
    speed here is not a consideration. Biopipe will default to XML::Parser. If not 
    installed, it will check for XML::SAX::PurePerl.
    
  - [Data::ShowTable](https://metacpan.org/pod/Data::ShowTable) - optional
  
    This package is used by the job_viewer script in bioperl-pipeline/scripts that
    provides a nice interface for querying the various job status in the pipeline.
    
  - [YAML](https://metacpan.org/pod/YAML) - NYI, but will be used in the future for CWL compliance
