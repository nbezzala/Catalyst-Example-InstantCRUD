use strict;
use warnings;
use Test::More tests => 1;
use Path::Class;
use File::Path;
use File::Copy;

my $app = 'DVDzbr';
my $lcapp = lc $app;

rmtree( ["t/tmp/$app", "t/tmp/$lcapp.db"] );

my $testfile = file('t', 'tmp', "$lcapp.db")->absolute->stringify;
my $origtestfile = file('t', 'var', "$lcapp.db")->absolute->stringify;

copy $origtestfile, $testfile;

`cd t/tmp; $^X -I../../lib ../../script/instantcrud.pl -name=$app -dsn='dbi:SQLite:dbname=$testfile'`;

ok( -f "t/tmp/$app/lib/$app/DBSchema.pm", 'DBSchema creation');


