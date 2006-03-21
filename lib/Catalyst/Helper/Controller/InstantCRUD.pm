package Catalyst::Helper::Controller::InstantCRUD;

use version; $VERSION = qv('0.0.5');

use warnings;
use strict;
use Carp;
use Path::Class;
use DBIx::Class::Loader;
use Data::Dumper;

sub _mkcolumns {
    my($tableclass, $table) = @_;
    my %columns;
    my %primarykeys;
#    return \%columns if 1 or ! $tableclass->storage->can('column_info_for');
    my @pks = $tableclass->primary_columns();
    @primarykeys{@pks} = @pks;
    for my $column ($tableclass->columns()){ 
        next if exists $primarykeys{$column};
        $columns{$column} = [];
        my $column_info = $tableclass->column_info($column);
        if ( $column_info->{data_type} =~ /int/i ){
            push @{$columns{$column}},  {
                constraint => 'Integer', 
                message => 'Should be a number',
            }
        }
        if ( $tableclass->storage->dbh->{Driver}->{Name} eq 'Pg' and
            $column_info->{data_type} =~ /int/i ){
            $column_info->{size} = int( $column_info->{size} * 12 / 5 );
        }
        if ( $column_info->{size} ){
            push @{$columns{$column}},  {
                constraint => 'Length', 
                message => 'Should be shorten than ' . $column_info->{size} . ' characters',
                max => $column_info->{size},
            }
        }
    }
    return \%columns;
}

    
    
sub mk_compclass {
    my ( $self, $helper, $dsn, $user, $pass) = @_;
    my $dir = dir( $helper->{base}, 'root', $helper->{prefix} );
    $helper->mk_dir($dir);
    my $loader = DBIx::Class::Loader->new(
        dsn       => $dsn,
        user      => $user,
        password  => $pass,
        namespace => $helper->{class}
    );
    for my $c ( $loader->classes ) {
        $c =~ /\W*(\w+)$/; 
        my $table = $1;
        $helper->mk_dir( dir ( $dir, $table ) );
        $helper->{columns} = Dumper ( _mkcolumns($c, $table, )); 
        $helper->{columns} =~ s/.VAR1 =//;
        $helper->{table_name} = lc $table;
        $helper->{class} = $helper->{app} . '::Controller::' . $table;
        $helper->{table_class} = $helper->{app} . '::Model::CDBI::' . $table;
        my $file = $helper->{file};
        $file =~ s/InstantCRUD/$table/;
        $helper->render_file( 'compclass', $file );
    }

    $dir = dir( $helper->{base}, 'root', 'static' );
    $helper->mk_dir($dir);
    print "dir: $dir\n";
    $helper->render_file( 'style',      file( $dir, 'pagingandsort.css' ) );
}



# Other recommended modules (uncomment to use):
#  use IO::Prompt;
#  use Perl6::Export;
#  use Perl6::Slurp;
#  use Perl6::Say;
#  use Regexp::Autoflags;


# Module implementation here


1; # Magic true value required at end of module
__DATA__

=begin pod_to_ignore

__compclass__

package [% class %];
use base Catalyst::Example::Controller::InstantCRUD;
use strict;

sub edit_columns {
    return [% columns %];
}



1;

__style__

body {
    font: bold 12px Verdana, sans-serif;
}

.content {
    padding: 12px;
    margin-top: 1px;  
    margin-bottom:0px;
    margin-left: 15px; 
    margin-right: 15px;
    border-color: #000000;
    border-top: 0px;
    border-bottom: 0px;
    border-left: 1px;
    border-right: 1px;
}

A { 
    text-decoration: none; 
    color:#225 
}
A:hover { 
    text-decoration: underline; 
    color:#222 
}

#title {
    z-index: 6;
    width: 100%;
    height: 18px;
    margin-top: 10px;
    font-size: 90%;
    border-bottom: 1px solid #ddf;
    text-align: left;
}

input[type=submit] {
    height: 18px;
    width: 60px;
    font-family: sans-serif;
    font-size: 11px;
    border: 1px outset;
    background-color: #fff;
    padding: 0px 0px 2px 0px;
    margin-bottom: 5px;
}

input:hover[type=submit] {
    color: #fff;
    background-color: #7d95b5;
}

textarea {
    width: 136px;
    font-family: sans-serif;
    font-size: 11px;
    color: #2E415A;
    padding: 0px;
    margin-bottom: 5px;
}

select {
    height: 16px;
    width: 140px;
    font-family: sans-serif;
    font-size: 12px;
    color: #202020;
    padding: 0px;
    margin-bottom: 5px;
}

	    

table { 
    border: 0px solid; 
    background-color: #ffffff;
}

th {
    background-color: #b5cadc;
    border: 1px solid #778;
    font: bold 12px Verdana, sans-serif;
}

tr.alternate { background-color:#e3eaf0; }
tr:hover { background-color: #b5cadc; }
td { font: 12px Verdana, sans-serif; }


td { font: 12px Verdana, sans-serif; }


fieldset {
    margin-top: 1px;
    padding: 1em;
    background-color: #f3f6f8;
    font:80%/1 sans-serif;
    border:1px solid #ddd;
}

label {
    display:block;
}

label .field {
    float:left;
    width:25%;
    margin-right:0.5em;
    padding-top:0.2em;
    text-align:right;
    font-weight:bold;
}

.error_messages { color: #d00; }

.action {
    border: 1px outset #7d95b5;
    style:block;
}

.action:hover {
    color: #fff;
    text-decoration: none;
    background-color: #7d95b5;
}

.pager {
    font: 11px Arial, Helvetica, sans-serif;
    text-align: center;
    border: solid 1px #e2e2e2;
    border-left: 0;
    border-right: 0;
    padding-top: 10px;
    padding-bottom: 10px;
    margin: 0px;
    background-color: #f3f6f8;
}

.pager a {
    padding: 2px 6px;
    border: solid 1px #ddd;
    background: #fff;
    text-decoration: none;
}

.pager a:visited {
    padding: 2px 6px;
    border: solid 1px #ddd;
    background: #fff;
    text-decoration: none;
}

.pager .current-page {
    padding: 2px 6px;
    font-weight: bold;
    vertical-align: top;
}

.pager a:hover {
    color: #fff;
    background: #7d95b5;
    border-color: #036;
    text-decoration: none;
}



__END__

=head1 NAME

Catalyst::Helper::Controller::InstantCRUD - [One line description of module's purpose here]


=head1 VERSION

This document describes Catalyst::Helper::Controller::InstantCRUD version 0.0.1


=head1 SYNOPSIS

    use Catalyst::Helper::Controller::InstantCRUD;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.

=head2 METHODS

=over 4

=item mk_compclass

=back

=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Catalyst::Helper::Controller::InstantCRUD requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-catalyst-helper-controller-instantcrud@rt.cpan.org>, or through the web interface at
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


