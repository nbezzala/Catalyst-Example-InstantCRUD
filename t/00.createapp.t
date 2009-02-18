use strict;
use warnings;
use Test::More tests => 2;
use Path::Class;
use File::Path;
use File::Copy;

my $apptree = dir('t', 'tmp', 'My-App');
my $dbfile = file('t', 'tmp', 'test.db');
rmtree( [$apptree, $dbfile] );

my $testfile = file('t', 'tmp', 'test.db')->absolute->stringify;
my $origtestfile = file('t', 'var', 'test.db')->absolute->stringify;

copy $origtestfile, $testfile;

my $tmpdir = dir(qw/ t tmp/);
my $libdir = dir(dir()->parent->parent, 'lib');
my $instant = file(dir()->parent->parent, 'script', 'instantcrud.pl');
my $line = "cd $tmpdir; $^X -I$libdir ../../script/instantcrud.pl -name=My::App -dsn='dbi:SQLite:dbname=$testfile' -noauth";
warn $line;

my $currdir = dir()->absolute;
chdir $tmpdir;
`$^X -I$libdir ../../script/instantcrud.pl -name=My::App -dsn='dbi:SQLite:dbname=$testfile' -noauth`;
chdir $currdir;

ok( -f file(qw/ t tmp My-App lib My App DBSchema.pm/), 'DBSchema creation');
ok( -f file( qw/ t tmp My-App lib My App Controller Usr.pm / ), 'Controller for "User" created');

