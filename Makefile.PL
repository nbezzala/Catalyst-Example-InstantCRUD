use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Catalyst::Example::InstantCRUD',
    AUTHOR              => '<Zbigniew Lukasiak> <<zz bb yy @ gmail.com>>',
    VERSION_FROM        => 'lib/Catalyst/Example/InstantCRUD.pm',
    ABSTRACT_FROM       => 'lib/Catalyst/Example/InstantCRUD.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
        'Catalyst'      => 0,
        'URI::Escape'   => 0,
        'HTML::Entities' => 0,
        'HTML::Widget' => 0,
        'File::Spec'    => 0,
        'Catalyst::View::TT' => 0.21,
        'Template::Plugin::Class' => 0,
        'Catalyst::Model::DBIC' => 0,
        'Catalyst::Helper::Model::DBIC' => 0,
        'DBIx::Class::Loader' => 0,},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Catalyst-Example-InstantCRUD-*' },
    EXE_FILES           => ['script/instantcrud.pl'],
);

