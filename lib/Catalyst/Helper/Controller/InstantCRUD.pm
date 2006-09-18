package Catalyst::Helper::Controller::InstantCRUD;

use version; $VERSION = qv('0.0.7');

use warnings;
use strict;

sub mk_compclass {
    my ( $self, $helper, $schema) = @_;
    
    # controllers
    my @source_monikers = $schema->sources;
    for my $class( @source_monikers ) {
        $helper->{class} = $helper->{app} . '::Controller::' . $class;
        (my $file = $helper->{file})  =~ s/InstantCRUD/$class/;
        $helper->{columns} = [ _getcolumns( $schema->source($class) ) ];
        $helper->{belongsto} = [ _getbelongsto( $schema->source($class) ) ];
        $helper->render_file( compclass => $file );
        $helper->render_file( altcompclass => $file . '.alt' );
    }
}

sub _getbelongsto {
    my $table = shift;
    my @columns;
    for my $col ($table->columns){
        next if !$table->relationship_info($col);
        my $info = $table->column_info($col);
        my $label = $info->{label} || join ' ', map { ucfirst } split '_', $col;
        push @columns, {widgettype => 'Select', name => $col, label => $label };
    }
    return @columns;
}

sub _getcolumns {
    my $table = shift;
    my @columns;
    my %primary_columns = map {$_ => 1} $table->primary_columns;
    for my $col ($table->columns){
        my $info = $table->column_info($col);
        next if $info->{is_auto_increment};
        next if $primary_columns{$col};
        next if $table->relationship_info($col);
        my $size = $info->{size} || 40;
        my $label = $info->{label} || join ' ', map { ucfirst } split '_', $col;
        my ( $widgettype, @constraints);
        if ( $info->{data_type} =~ /int/i ) {
            push @constraints,  {
                constraint => 'Integer',
                message => 'Should be a number',
            }
        } elsif ( $info->{size} ) {
            push @constraints,  {
                constraint => 'Length',
                message => "Should be shorten than $info->{size} characters",
                method => 'max',
                arg    => $info->{size},
            };
        }
        if ( !$info->{is_nullable} && !$info->{is_auto_increment}){
            push @constraints,  {
                constraint => 'All',
                message => "The field is required",
            }
        }
        if ( $col =~ /password|passwd/ ) {
            $size = 40 if $size > 40;
            $widgettype = 'Password';
           push @constraints,  {
                constraint => 'Equal',
                args => [ "$col\_2" ],
                message => "Passwords must match",
            }, {
                constraint => 'AllOrNone',
                args => [ "$col\_2" ],
                message => "Confirm the password",
            };
            push @columns, {widgettype => $widgettype, name => $col, label => $label, size => $size, constraints => \@constraints};
            push @columns, {widgettype => $widgettype, name => $col .'_2', label => $label, size => $size, constraints => \@constraints};
         }else{
            if( $size > 80 ){
                $widgettype = 'Textarea';
            }else{
                $widgettype = 'Textfield';
            } 
            push @columns, {widgettype => $widgettype, name => $col, label => $label, size => $size, constraints => \@constraints};
        }
    }
    return @columns;
}

1; # Magic true value required at end of module
__DATA__

=begin pod_to_ignore

__compclass__
package [% class %];
use base Catalyst::Example::Controller::InstantCRUD;
use strict;

1;
__altcompclass__
package [% class %];
use base Catalyst::Example::Controller::InstantCRUD;
use strict;

sub model_widget {
    my ( $self, $c, $id ) = @_;
    my $item = $self->model_item( $c, $id ) if $id;
    my $table = $self->model_resultset( $c )->result_source();
    my $w = HTML::Widget->new();
    my ($element, $info, @options, $relatedclass, $ref_pk, $const);
    [% FOR col = columns %]
      $element = $w->element( '[% col.widgettype %]', '[% col.name %]' );
      $element->label( '[% col.label%]' );
      $element->value( $item->[% col.name %] ) if $id;
      [% IF col.widgettype == 'Textfield' %]
        $element->size([% col.size %]);
        $element->maxlength([% col.size %]);
      [% END %]
      [% FOR const = col.constraints %]
        $const = $w->constraint( '[% const.constraint %]', '[% col.name %]' [% IF const.args %] , '[% const.args %]' [% END %] )->message( '[% const.message %]' );
        [% IF const.method %]
        $const->[% const.method %]([% const.arg %]);
        [% END %]
      [% END %]
    [% END %]
    my $model = $c->model($c->config->{InstantCRUD}{model_name});
    [% FOR col = belongsto %]
      $element = $w->element( '[% col.widgettype %]', '[% col.name %]' );
      $element->label( '[% col.label%]' );
      @options = ( 0, '' );
      $info = $table->relationship_info('[% col.name %]');
      $relatedclass = $model->resultset($info->{source});
      $ref_pk = ( $relatedclass->result_source->primary_columns ) [0];
      for my $ref_item ( $relatedclass->search() ){
          push @options, $ref_item->$ref_pk, "$ref_item"; 
      }
      $element->options(@options);
      $element->selected( $item->[% col.name %] ) if $id;
    [% END %]
    return HTML::Widget->new('widget')->method('post')->embed($w);
}

1;
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


