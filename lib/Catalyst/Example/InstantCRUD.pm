package Catalyst::Example::InstantCRUD;

use version; $VERSION = qv('0.0.25');

use warnings;
use strict;
use Carp;


# Module implementation here


1; # Magic true value required at end of module
__END__

=head1 NAME

Catalyst::Example::InstantCRUD - A CRUD scaffolding for Catalyst.

=head1 VERSION

This document describes Catalyst::Example::InstantCRUD version 0.0.22

=head1 SYNOPSIS

    instantcrud.pl -name=My::App -dsn='dbi:Pg:dbname=CE' -user=zby -password='pass'

The instantcrud.pl executable creates a skeleton CRUD application in
current directory. The parameters are: name of the application and
database connection details.

=head1 DESCRIPTION

The script will create CRUD interface (CReate, Update, Delete) 
with paging and sort for all
tables defined in the accessed database.  
The Create and Update forms let you manipulate also on relations
(even many to many).

I am waiting for suggestions what else basic functionality would be nice
to have in the generated application.

When the code is generated you can run the application:

    $ My-App/script/my_app_server.pl
    You can connect to your server at http://zby.aster.net.pl:3000

To access the CRUD interface to the tables you need to add
'/tablename' (in lowercase) to the address:
http://localhost:3000/tablename 
(Note that if the table name has a underscore, that underscore should be 
deleted in the address so table foo_bar is available at 
http://localhost:3000/foobar, this is due to some conversions made by the 
underlying libraries).

The generated application will use DBIx::Class for model classes and
Template::Toolkit for View.

=head1 CUSTOMISATION AND EXTENDING

The first place for customisations are the Template Toolkit templates
and the CSS file.
The CSS file used by the application is root/static/pagingandsort.css.
The templates are generated in directories named after the controllers in the
root directory.  

The generated controller is a subclass of 
Catalyst::Example::Controller::InstantCRUD. 
You can use the standard OO technique of overriding the documented methods
to customize and extend it.
The form handling code is in the controller.

=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

        'Catalyst::Runtime'                                      => '5.7000',
        'Catalyst::Devel'                                        => '1.00',
        'Catalyst::View::TT'                                     => '0.21',
        'DBIx::Class'                                            => '0.08003',
        'DBIx::Class::Schema::Loader'                            => '0.03',
        'DBIx::Class::ResultSet::RecursiveUpdate'                => 0,
        'Catalyst::Model::DBIC::Schema'                          => 0,
        'Catalyst::Helper::Model::DBIC::Schema'                  => 0,
        'Catalyst::Plugin::ConfigLoader'                         => 0,
        'Catalyst::Plugin::Static::Simple'                       => 0,
        'Catalyst::Plugin::Session::State::Cookie'               => 0,
        'Catalyst::Plugin::Session::Store::FastMmap'             => 0,
        'Rose::HTMLx::Form::DBIC'                                => 0,
        'Rose::HTMLx::Form::DBIC::FormGenerator'                 => 0,
        'Path::Class'                                            => 0,
        'File::Spec'                                             => 0,
        'File::Slurp'                                            => 0,
        'Pod::Usage'                                             => 0,
        'List::Util'                                             => 0,

=head1 BUGS AND LIMITATIONS

This is still experimental and it is a first new release 
after a long time and substantial refactoring so treat with caution.

The main generator script (instantcrud.pl) is an ugly hack.  First
the Catalyst helpers assume where the executable is located so I had
to fool them, second there is no API for creation of the main
application module (My::App).

Please report any bugs or feature requests to
C<bug-catalyst-example-instantcrud@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

<Zbigniew Lukasiak>  C<< <<zz bb yy @ gmail.com>> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, <Zbigniew Lukasiak> C<< <<zz bb yy @ gmail.com>> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
