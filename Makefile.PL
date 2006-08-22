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
        'Catalyst::Runtime'                                      => '5.7000',
        'Catalyst::Devel'                                        => '1.00',
        'Catalyst::View::TT'                                     => '0.21',
        'DBIx::Class'                                            => '0.07000',
        'DBIx::Class::Schema::Loader'                            => '0.03',
	'DBIx::Class::DigestColumns'                             => 0,
        'Template::Plugin::Class'                                => 0,
        'Catalyst::Model::DBIC'                                  => 0,
        'Catalyst::Helper::Model::DBIC::Schema'                  => 0,
        'Catalyst::Plugin::ConfigLoader'                         => 0,
        'Catalyst::Plugin::Static::Simple'                       => 0,
        'Catalyst::Plugin::StackTrace'                           => 0,
        'Catalyst::Plugin::HTML::Widget'                         => 0,
        'Catalyst::Plugin::Authentication'                       => '0.07',
        'Catalyst::Plugin::Authentication::Store::DBIC'          => '0.07',
        'Catalyst::Plugin::Authentication::Credential::Password' => 0,
        'Catalyst::Plugin::Session::State::Cookie'               => 0,
	'Catalyst::Plugin::Session::Store::FastMmap'             => 0,
        'Test::More'                                             => 0,
        'version'                                                => 0,
        'URI::Escape'                                            => 0,
        'HTML::Entities'                                         => 0,
        'HTML::Widget'                                           => 0,
        'File::Spec'                                             => 0,
        'File::Slurp'                                            => 0,
        'Pod::Usage'                                             => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Catalyst-Example-InstantCRUD-*' },
    EXE_FILES           => ['script/instantcrud.pl'],
);

