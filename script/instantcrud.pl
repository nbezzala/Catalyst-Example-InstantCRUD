#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use Getopt::Long;
use Pod::Usage;
use YAML 'LoadFile';
use File::Spec;
use File::Slurp;
use Catalyst::Helper::InstantCRUD;
use Catalyst::Example::InstantCRUD::Utils;
use Catalyst::Utils;
use Data::Dumper;

my $help     = 0;
my $adv_help = 0;
my $nonew    = 0;
my $scripts  = 0;
my $short    = 0;
my $auth     = 1;
my $dsn;
my $duser;
my $dpassword;
my $appname;

my $model_name  = 'DBICSchemamodel';
my $schema_name = 'DBSchema';

my %auth;
my %authz;

GetOptions(
    'help|?'  => \$help,
    'advanced_help'  => \$adv_help,
    'nonew'   => \$nonew,
    'scripts' => \$scripts,
    'short'   => \$short,
    'name=s'    => \$appname,
    'dsn=s'     => \$dsn,
    'user=s'    => \$duser,
    'password=s'=> \$dpassword,
    'auth!'      => \$auth,
    
    'model_name=s'=> \$model_name,
    'schema_name=s'=> \$schema_name,
    
    'auth_user_table=s' => \$auth{user_table},
    'auth_user_field=s' => \$auth{user_field},
    'auth_password_field=s' => \$auth{password_field},
    'auth_password_type=s' => \$auth{password_type},
    'auth_password_hash_type=s' => \$auth{password_hash_type},
    'auth_user_role_user_field=s' => \$auth{user_role_user_field},
    
    'authz_role_table=s' => \$authz{role_table},
    'authz_role_field=s' => \$authz{role_field},
    'authz_user_role_user_field=s' => \$authz{user_role_user_field},
    'authz_role_rel=s' => \$authz{role_rel},
);

pod2usage($adv_help ? 1 : 2) if $help || $adv_help || !$appname;

{
    require DBIx::Class::Schema::Loader;
    no strict 'refs';
    @{"$schema_name\::ISA"} = qw/DBIx::Class::Schema::Loader/;
    $schema_name->loader_options(relationships => 1, exclude => qr/^sqlite_sequence$/);
}

my $schema = $schema_name->connect($dsn, $duser, $dpassword);

my $attrs = Catalyst::Example::InstantCRUD::Utils->load_schema($schema,
    auth => \%auth, authz => \%authz, noauth => !$auth,
);
      
# Application
my $helper = Catalyst::Helper::InstantCRUD->new( {
    '.newfiles'   => !$nonew,
    'scripts'     => $scripts,
    'short'       => $short,
    'model_name'  => $model_name,
    'schema_name' => $schema_name,
    'auth'        => $attrs->{auth},
    'authz'       => $attrs->{authz},
} );

pod2usage(1) unless $helper->mk_app( $appname );

my $appdir = $appname;
$appdir =~ s/::/-/g;
local $FindBin::Bin = File::Spec->catdir($appdir, 'script');

# Controllers
$helper->mk_component ( $appname, 'controller', 'InstantCRUD', 'InstantCRUD',
  @{$attrs->{classes}}
);

# Model
$helper->mk_component ( $appname, 'model', $model_name, 'InstantCRUD', 
  $schema_name, $dsn, $duser, $dpassword, {}, $attrs
);

my @classes = map {
    $attrs->{many_to_many_relation_table}{$schema->class($_)->table} ? () : $_
} @{$attrs->{classes}};

# View and Templates
$helper->mk_component ( $appname, 'view', 'TT', 'InstantCRUD', @classes );

#my $tfile =  File::Spec->catdir ( $appdir, 't', 'controller_InstantCRUD.t' );
#unlink $tfile or die "Cannot remove $tfile - the wrong test file: $!";

1;

__END__

=head1 NAME

instantcrud.pl - Bootstrap a Catalyst application example

=head1 SYNOPSIS

instantcrud.pl [options] 

 Options:
   -help           display this help and exits
   -advanced_help  display the advanced help screen and exits
   -nonew          don't create a .new file where a file to be created exists
   -scripts        update helper scripts only
   -short          use short types, like C instead of Controller...
   -name           application-name
   -dsn            dsn
   -user           database user
   -password       database password
   -model_name     model name (default: DBICSchemamodel) 
   -schema_name    schema name (default: DBSchema) 

 application-name must be a valid Perl module name and can include "::"

 Examples:
    instantcrud.pl -name=My::App -dsn='dbi:Pg:dbname=CE' -user=zby -password='pass'


=head1 OPTIONS

 (For advanced users...)

 Authentication options:
    (See Catalyst::Plugin::Authentication::Store::DBIC for more info)
    -auth_user_table		 user table name
    -auth_user_field		 user field name
    -auth_password_field	 password field name
    -auth_password_type		 password type (clear, crypted, hashed, or salted_hash)
    -auth_password_hash_type	 password hash type (any hashing method supported by the Digest module may be used)
 
     Authorization options:
    -authz_role_table		 name of the table that contains the list of roles 
    -authz_role_field		 name of the field in authz_role_table that contains the role name
    -authz_user_role_user_field  name of the field in the user_role table that contains the user id		
    -authz_role_rel		 name of the relationship in role Class that refers to the mapping table between users and roles


=head1 DESCRIPTION

The C<catalyst.pl> script bootstraps a Catalyst application example, creating 
a directory structure populated with skeleton files.  

The application name must be a valid Perl module name.  The name of the
directory created is formed from the application name supplied, with double
colons replaced with hyphens (so, for example, the directory for C<My::App> is
C<My-App>).

Using the example application name C<My::App>, the application directory will
contain the following items:

=over 4

=item README

a skeleton README file, which you are encouraged to expand on

=item Build.PL

a C<Module::Build> build script

=item Changes

a changes file with an initial entry for the creation of the application

=item Makefile.PL

an old-style MakeMaker script.  Catalyst uses the C<Module::Build> system so
this script actually generates a Makeifle that invokes the Build script.

=item lib

contains the application module (C<My/App.pm>) and
subdirectories for model, view, and controller components (C<My/App/M>,
C<My/App/V>, and C<My/App/C>).  

=item root

root directory for your web document content.  This is left empty.

=item script

a directory containing helper scripts:

=over 4

=item C<my_app_create.pl>

helper script to generate new component modules

=item C<my_app_server.pl>

runs the generated application within a Catalyst test server, which can be
used for testing without resorting to a full-blown web server configuration.

=item C<my_app_cgi.pl>

runs the generated application as a CGI script

=item C<my_app_fastcgi.pl>

runs the generated application as a FastCGI script

=item C<my_app_test.pl>

runs an action of the generated application from the comand line.

=back

=item t

test directory

=back

The application module generated by the C<catalyst.pl> script is functional,
although it reacts to all requests by outputting a friendly welcome screen.

=head1 NOTE

Neither C<catalyst.pl> nor the generated helper script will overwrite existing
files.  In fact the scripts will generate new versions of any existing files,
adding the extension C<.new> to the filename.  The C<.new> file is not created
if would be identical to the existing file.  

This means you can re-run the scripts for example to see if newer versions of
Catalyst or its plugins generate different code, or to see how you may have
changed the generated code (although you do of course have all your code in a
version control system anyway, don't you ...).


=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Manual::Intro>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>,
Andrew Ford, C<A.Ford@ford-mason.co.uk>
Zbigniew Lukasiak, C<zz bb yy@gmail.com>
Jonas Alves, C<jonas.alves at gmail.com>
Jonathan Manning

=head1 COPYRIGHT

Copyright 2004-2005 Sebastian Riedel. All rights reserved.

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

