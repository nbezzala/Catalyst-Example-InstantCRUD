package Catalyst::Helper::Model::DBICform;

use strict;
use DBIx::Class::Loader;
use File::Spec;

=head1 NAME

Catalyst::Helper::Model::DBIC - Helper for DBIC Models

=head1 SYNOPSIS

    script/create.pl model DBIC DBIC dsn user password

=head1 DESCRIPTION

Helper for DBIC Model.

=head2 METHODS

=over 4

=item mk_compclass

Reads the database and makes a main model class as well as placeholders
for each table.

=item mk_comptest

Makes tests for the DBIC Model.

=back 

=cut

sub mk_compclass {
    my ( $self, $helper, $dsn, $user, $pass ) = @_;
    $helper->{dsn}  = $dsn  || '';
    $helper->{user} = $user || '';
    $helper->{pass} = $pass || '';
    $helper->{rel} = $dsn =~ /sqlite|pg|mysql/i ? 1 : 0;
    my $file = $helper->{file};
    $helper->{classes} = [];
    $helper->render_file( 'dbicclass', $file );

    #push( @{ $helper->{classes} }, $helper->{class} );
    return 1 unless $dsn;
    my $loader = DBIx::Class::Loader->new(
        dsn       => $dsn,
        user      => $user,
        password  => $pass,
        namespace => $helper->{class}
    );

    my $path = $file;
    $path =~ s/\.pm$//;
    $helper->mk_dir($path);

    for my $c ( $loader->classes ) {
        $helper->{tableclass} = $c;
        $helper->{table} = $c->table;
        $helper->{columns} = join ' ', $c->columns;
        my @pk = $c->primary_columns();
        $helper->{primary_key} = $pk[0];
        $helper->{tableclass} =~ /\W*(\w+)$/;
        my $f = $1;
        my $p = File::Spec->catfile( $path, "$f.pm" );
        $helper->render_file( 'tableclass', $p );
        push( @{ $helper->{classes} }, $c );
    }
    return 1;
}

sub mk_comptest {
    my ( $self, $helper ) = @_;
    my $test = $helper->{test};
    my $name = $helper->{name};
    for my $c ( @{ $helper->{classes} } ) {
        $helper->{tableclass} = $c;
        $helper->{tableclass} =~ /\:\:(\w+)\:\:(\w+)$/;
        my $prefix;
        unless ( $1 eq 'M' ) { $prefix = "$name\::$2" }
        else { $prefix = $2 }
        $prefix =~ s/::/-/g;
        my $test = $helper->next_test($prefix);
        $helper->render_file( 'test', $test );
    }
}

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst::Helper>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
__DATA__

__dbicclass__
package [% class %];

use strict;
use base qw/DBIx::Class DBIx::Class::WebForm/;

__PACKAGE__->load_components(qw/PK::Auto::Pg Core DB/);

__PACKAGE__->connection('[% dsn %]', '[% user %]', '[% pass %]');


=head1 NAME

[% class %] - Catalyst DBIC Model

=head1 SYNOPSIS

See L<[% app %]>

=head1 DESCRIPTION

Catalyst DBIC Model.

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__tableclass__
package [% tableclass %];

use strict;
use warnings;
use base '[% class %]';

__PACKAGE__->table('[% table %]');
__PACKAGE__->add_columns(qw/[% columns %]/);
__PACKAGE__->set_primary_key('[% primary_key %]');


=head1 NAME

[% tableclass %] - Catalyst DBIC Table Model

=head1 SYNOPSIS

See L<[% app %]>

=head1 DESCRIPTION

Catalyst DBIC Table Model.

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__test__
use Test::More tests => 2;
use_ok( Catalyst::Test, '[% app %]' );
use_ok('[% tableclass %]');
