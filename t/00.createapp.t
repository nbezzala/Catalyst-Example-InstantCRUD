use strict;
use warnings;
use Test::More tests => 1;
use Path::Class;
use File::Path;
use File::Copy;

my $apptree = dir('t', 'tmp', 'My-App');
my $dbfile = file('t', 'tmp', 'test.db');
rmtree( [$apptree, $dbfile] );

my $testfile = file('t', 'tmp', 'test.db')->absolute;
my $origtestfile = file('t', 'var', 'test.db')->absolute;

copy $origtestfile, $testfile;

my $tmpdir = dir(qw/ t tmp/);
my $libdir = dir(dir()->parent->parent, 'lib');
my $instant = file(dir()->parent->parent, 'script', 'instantcrud.pl');
my $line = "cd $tmpdir; perl -I$libdir ../../script/instantcrud.pl -name=My::App -dsn='dbi:SQLite:dbname=$testfile' -noauth";
warn $line;

my $currdir = dir()->absolute;
chdir $tmpdir;
`perl -I$libdir ../../script/instantcrud.pl -name=My::App -dsn='dbi:SQLite:dbname=$testfile' -noauth`;
chdir $currdir;

my $schemafile = file(qw/ t tmp My-App lib DBSchema.pm/);
ok( -f $schemafile, 'DBSchema creation');
