package Catalyst::Example::InstantCRUD;

use version; $VERSION = qv('0.0.3');

use warnings;
use strict;
use Carp;


# Module implementation here


1; # Magic true value required at end of module
__END__

=head1 NAME

Catalyst::Example::InstantCRUD  


=head1 VERSION

This document describes Catalyst::Example::InstantCRUD version 0.0.1


=head1 SYNOPSIS

    instantcrud.pl -name=My::App -dsn='dbi:Pg:dbname=CE' -user=zby -password='pass'

The instantcrud.pl executable creates a skeleton CRUD application in
current directory. The parameters are: name of the application and
database connection details.

=head1 DESCRIPTION

The script will create CRUD interface with paging and sort for all
tables defined in the accessed database.  
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
and the CSS file. To customize the templates copy them from the subdirectory templates of the directory where the Catalyst::Controller::PagingAndSort
was installed to the "root" directory in the generated application and modify
them.

The CSS file used by the application is root/static/pagingandsort.css.

The generated controller is a subclass of Catalyst::Controller::PagingAndSort.
You can use the standard OO technique of overriding the documented methods
to customize and extend it.

=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

'Test::More' => 0,
'version'    => 0,
'Catalyst'      => 0,
'URI::Escape'   => 0,
'HTML::Entities' => 0,
'HTML::Widget' => 0,
'File::Spec'    => 0,
'Catalyst::View::TT' => 0.21,
'Template::Plugin::Class'


=head1 BUGS AND LIMITATIONS

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
