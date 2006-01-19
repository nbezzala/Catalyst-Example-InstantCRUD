use Test::More tests => 4;

BEGIN {
use_ok( 'Catalyst::Example::Controller::InstantCRUD' );
use_ok( 'Catalyst::Helper::Controller::InstantCRUD' );
use_ok( 'Catalyst::Helper::Model::DBICform' );
use_ok( 'Catalyst::Example::InstantCRUD');
}

diag( "Testing Catalyst::Example::InstantCRUD $Catalyst::Example::InstantCRUD::VERSION" );
