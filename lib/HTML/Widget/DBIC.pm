package HTML::Widget::DBIC;
use strict;
use warnings;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.01;
	@ISA         = qw (Exporter);
	#Give a hoot don't pollute, do not export more than needed by default
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}
use base 'HTML::Widget';
use Data::Dumper;

sub _make_elem {
    my( $w, $field_conf, @options ) = @_;
#    warn "Making element: " . Dumper($field_conf); use Data::Dumper;
    my @widget_args = @{$field_conf->{widget_element}};
    my $widget_type = shift @widget_args;
    my %additionalmods = @widget_args;
#    $widget_element = 'Select' if $widget_element eq 'DoubleSelect';
    my $element = $w->element( $widget_type , $field_conf->{name} );
    if ( $widget_type eq 'Select' ){
        $element->options(0, '', @options);
    }
    if ( $widget_type eq 'DoubleSelect' ){
        $element->options( @options );
    }
    $element->label( $field_conf->{label} );
    for my $widgetmod ( keys %additionalmods ) {
        $element->$widgetmod( $additionalmods{$widgetmod} );
    }
    return $element;
}

sub _make_constraints {
    my( $w, $field_conf ) = @_;
    for my $cconf ( @{ $field_conf->{constraints} || [] } ) {
        my $const =
          $w->constraint( $cconf->{constraint}, $field_conf->{name},
            $cconf->{args} ? @{ $cconf->{args} } : () );
        $cconf->{$_} and $const->$_( $cconf->{$_} )
          for qw/min max regex callback in message/;
    }
}

sub _get_options {
    my( $class, $schema ) = @_;
    my @options;
#    my $displaymethod = $config->{$class}->{displaymethod};
    my( $pkey ) = $schema->source( $class )->primary_columns();
    my $rs = $schema->resultset( $class )->search;
    my $j = 1;
    while( my $i = $rs->next() ){
        push @options, $i->$pkey, "$i";   #->$displaymethod;
    }
    return @options;
}

sub _getval {
    my( $item, $field_conf, $schema ) = @_;
    my $class = $field_conf->{foreign_class};
    my $name  = $field_conf->{name};
    my @widget_args = @{$field_conf->{widget_element}};
    my $widget_type = shift @widget_args;
    my %additionalmods = @widget_args;
    if( $class ){
        my( $pkey ) = $schema->source( $class )->primary_columns();
        if( $additionalmods{multiple} ){
            my @vals;
            my $rs = $item->$name();
            while( my $rec = $rs->next() ){
                push @vals, $rec->$pkey;
            }
            return @vals;
        }else{
            return $item->$name()->$pkey;
        }
    }else{
        if( $widget_type eq 'Password' ){
            $name =~ s/_2$//;
        }
        return $item->$name();
    }
}

sub create_from_config {
    my ( $class, $config, $schema, $resultclass, $item ) = @_;
#    warn 'aaaaaaaaaaa' . Dumper($config); use Data::Dumper;
    my $self = $class->SUPER::new;
    for my $col ( @{$config} ) {
        next if ! defined $col->{widget_element};
        my @options;
        if( $col->{foreign_class} ){
            @options = _get_options( $col->{foreign_class}, $schema );
        }
        my $element = _make_elem( $self, $col, @options );
        $element->value( _getval($item, $col, $schema) ) if $item;
        _make_constraints( $self, $col );
    }
    $self->{dbic_config} = $config;
    $self->{dbic_schema} = $schema;
    $self->{dbic_resultclass} = $resultclass;
    $self->{dbic_item}   = $item;
    return bless( $self, $class);
}

sub process {
    my $self = shift;
    my $result = $self->SUPER::result( @_ );
    for my $attr ( qw/ dbic_config dbic_schema dbic_resultclass dbic_item / ){ 
        $result->{$attr} = $self->{$attr};
    }
    return bless ( $result, 'HTML::Widget::Result::DBIC' );
}


package HTML::Widget::Result::DBIC;
use base 'HTML::Widget::Result';
use Data::Dumper;

sub save_to_db {
    my $self = shift;
#    my ( $interface_config, $class, $widget, $item ) = @_;
    my $config = $self->{dbic_config};
    my @widgets = ( $self, @{ $self->{_embedded} || [] } );
    my @elements = map @{ $_->{_elements} }, @widgets;
    my ( @cols, @rels, %rels );
    my $resultclass = $self->{dbic_resultclass};
    my $schema = $self->{dbic_schema};
    my $source = $schema->source($self->{dbic_resultclass});
    my %possiblerels;
    my %pkeys = map { $_ => 1 } $source->primary_columns();
    for my $field ( @$config ){
        next if $pkeys{$field->{name}};
        if ( $source->has_column ( $field->{name} ) ){
            push @cols, $field->{name};
        }elsif ( !$field->{not_to_db} ) { 
            push @rels, $field->{name};
            $rels{$field->{name}} = 1;
        }
    }
    my %obj = map {
         $_ => scalar $self->param( $_ )
    } @cols;
    my $item = $self->{dbic_item} || $schema->resultset( $self->{dbic_resultclass} )->new_result( {} );
    $item->result_source->schema->txn_do(
        sub {
            $item->set_columns( \%obj );
            my $in_storage = $item->in_storage;
            $item->insert_or_update;
            for (@$config) {
                my $name = $_->{name};
                next if ! $rels{$name};
                if ( my $bridge_rel = $_->{bridge_rel} ){
                    $item->delete_related( $bridge_rel ) if $in_storage;
                    my $foreign_class = $_->{foreign_class};
                    my $other_class = $schema->source($foreign_class);
                    my $info = $other_class->relationship_info($bridge_rel);
                    my ($self_col, $foreign_col) = %{$info->{cond}};
                    if ( $self_col =~ /^foreign/ ) {
                        ( $foreign_col, $self_col ) = %{$info->{cond}};
                    }
                    $foreign_col =~ s/foreign\.//;
                    $self_col    =~ s/self\.//;
                    $item->create_related( $bridge_rel,
                        { $foreign_col => $_ } )
                      for $self->param($name);
                }
                else {                          #if ( $info->{type} eq 'has_many' ) {
                    my $info = $item->result_source->relationship_info($name);
                    my ($self_col, $foreign_col) = %{$info->{cond}};
                    if ( $self_col =~ /^foreign/ ) {
                        ( $foreign_col, $self_col ) = %{$info->{cond}};
                    }
                    $foreign_col =~ s/foreign\.//;
                    $self_col    =~ s/self\.//;
                    if ($in_storage) {
                        my $related_objs = $item->search_related(
                            $name,
                            {
                                $self_col =>
                                  { -not_in => [ $self->param($name) ] },
                            }
                        );

                        # Let's try to put a NULL in the related objects FK
                        eval {
                            $related_objs->update(
                                { $foreign_col => undef } );
                          }

             # If the relation can't be NULL the related objects must be deleted
                          || $related_objs->delete;
                    }
                    my ($pk) = $item->result_source->primary_columns;
                    my @values = grep $_, $self->param($name);
                    $item->result_source->schema->resultset( $info->{class} )
                      ->search( { $self_col => \@values } )
                      ->update( { $foreign_col => $item->$pk } )
                      if @values;
                }
            }
        }
    );
    return $item;
}



1;

__END__


=head1 NAME

HTML::Widget::DBIC - a subclass of HTML::Widgets for dealing with DBIx::Class

=head1 SYNOPSIS
    use HTML::Widget::DBIC;
    
    # create a widget coupled with a db record
    my $widget = HTML::Widget::DBIC->create_from_config( $config, $schema, 'Tag', $item );

    # process a query
    my $result = $widget->process ( $query );

    # and save the values from the query to the database
    $result->save_to_db();


=head1 METHODS

=over 4

=item create_from_config

Method to create widget.  The parameters are configuration for all the widget
fields, DBIx::Class schema, the name of the DBIC Resultset and optionally 
a DBIC record (item) - to fill in the current values in the form and as the
target for saving the data, if not present when saving a new record will be
created.

The config is a reference to a list of configuration for particular fields.
Like:
    my $config = [
        {
            'foreign_class'  => 'Dvd',
            'widget_element' => [ 'Select', 'multiple' => 1 ],
            'name'           => 'dvds',
            'label'          => 'Dvds',
            'bridge_rel'     => 'dvdtags'
        },
        {
            'widget_element' => [
                'Textarea', 
                'rows' => 5,
                'cols' => 60
            ],
            'constraints' => [
                {
                    'max'        => '255',
                    'constraint' => 'Length',
                    'message'    => 'Should be shorten than 255 characters'
                },
                {
                    'constraint' => 'All',
                    'message'    => 'The field is required'
                }
            ],
            'name'  => 'name',
            'label' => 'Name'
        },
        {
            'primary_key' => 1,
            'name'        => 'id',
            'label'       => 'Id'
        }
    ];
    

=item process

Like HTML::Widget->process but produces HTML::Widget::Result::DBIC - with extra info for saving to database.

=item save_to_db

HTML::Widget::DBIC::Result method to save the data from widget to the database

=cut
=back

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


1;    # Magic true value required at end of module
__END__

=head1 NAME

Catalyst::Example::Controller::InstantCRUD - Catalyst CRUD example Controller


=head1 VERSION

This document describes Catalyst::Example::Controller::InstantCRUD version 0.0.1


=head1 SYNOPSIS

    use base Catalyst::Example::Controller::InstantCRUD;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=head2 METHODS

=over 4

=item column_value
Returns the value of the column in the row.

=item get_resultset 
Returns the resultset appriopriate for the page parameters.

=item model_class
Returns a class from the model.

=item model_resultset
Returns a resultset from the model.

=item model_item
Returns an item from the model.

=item model_widget
Returns a L<HTML::Widget> object filled with elements from the model.

=item button
Returns an L<HTML::Widget> object with a submit button.

=item source_name
Class method for finding name of corresponding database table.

=item add
Method for displaying form for adding new records

=item create_col_link
Subroutine placed on stash for templates to use.

=item create_page_link
Subroutine placed on stash for templates to use.

=item auto 
Adds Controller name as additional directory to search for templates

=item index
Forwards to list

=item destroy
Deleting records.

=item do_add
Method for adding new records

=item do_edit
Method for editin existing records

=item edit
Method for displaying form for editing a record.

=item list
Method for displaying pages of records

=item view
Method for diplaying one record

=back

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
  
Catalyst::Example::Controller::InstantCRUD requires no configuration files or environment variables.


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
C<bug-catalyst-example-controller-instantcrud@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

<Zbigniew Lukasiak>  C<< <<zz bb yy @ gmail.com>> >>
<Jonas Alves>  C<< <<jonas.alves at gmail.com>> >>
<Lars Balker Rasmussen>

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




package DBIx::Class::InstantCRUD;
use base qw/DBIx::Class/;
use strict;
use warnings;
use Carp;
use HTML::Widget;
use Lingua::EN::Inflect::Number ();

our $VERSION = '0.01';

__PACKAGE__->mk_classdata('widget_elements');
__PACKAGE__->mk_classdata('list_columns');

sub fill_widget {
    my ( $dbic, $widget ) = @_;

    croak('fill_widget needs a HTML::Widget object as argument')
      unless ref $widget && $widget->isa('HTML::Widget');
    my @elements = $widget->get_elements;

    # get embeded widgets
    my @widgets = @{ $widget->{_embedded} || [] };

    foreach my $emb_widget (@widgets) {
        push @elements, $emb_widget->get_elements;
    }

    foreach my $element (@elements) {
        my $name = $element->name;
        next unless $name && $dbic->can($name) && $element->can('value');
        if ( $element->isa('HTML::Widget::Element::Checkbox') ) {
            $element->checked( $dbic->$name ? 1 : 0 );
        }
        else {
            $element->value( $dbic->$name )
              unless $element->isa('HTML::Widget::Element::Password');
        }
    }
}

sub get_widget {
    my ($self) = @_;
    my $table  = $self->result_source;
    my $w      = HTML::Widget->new( $table->from )->method('post');
    for my $el ( grep $_, @{ $self->widget_elements || [] } ) {

        #next if ( grep /^$el$/, $table->primary_columns  );
        # Table column
        if ( $table->has_column($el) && !$table->relationship_info($el) ) {
            my $info = $table->column_info($el);
            next if $info->{is_auto_increment};
            $self->_build_element( $w, $el, $info );

            # Add constraints
            for my $c ( @{ $info->{constraints} || [] } ) {
                my $const =
                  $w->constraint( $c->{constraint}, $el,
                    $c->{args} ? @{ $c->{args} } : () );
                $c->{$_} and $const->$_( $c->{$_} )
                  for qw/min max regex callback in message/;
            }
        }

        # Relationships
        else {
            my $info = $table->__relationship_info($el) || next;
            my $class =
                $info->{type} eq 'many_to_many'
              ? $info->{other_class}
              : $info->{class};
            my $ref_pk =
              ( $self->result_source->schema->source($class)->primary_columns )
              [0];
            my $w_element =
              $info->{type} eq 'belongs_to' ? 'Select' : 'DoubleSelect';
            my @options;
            @options = ( 0, '' ) unless $w_element eq 'DoubleSelect';
            for my $ref_item (
                $self->result_source->schema->resultset($class)->search )
            {
                push @options, $ref_item->$ref_pk, "$ref_item";
            }
            my $element = $w->element( $w_element, $info->{rel_name} );
            $element->options(@options);    # when done on the previous line this was
                   # resulting sometimes in $element == undef

            # belongs_to relationships
            if ( $info->{type} eq 'belongs_to' ) {
                my $label = $info->{label} || join ' ',
                  map { ucfirst } split '_', $el;
                $element->label($label);
                $element->selected(
                    $self->in_storage ? $self->$el->$ref_pk : 0 );
            }

            # has_many and many-to-many relationships
            else {
                my $label = $class;
                $element->multiple(1)->size(5)->label($label);
                if ( $self->in_storage ) {
                    my @selected = $self->search_related($el);
                    $element->selected(
                        [ @selected ? map( $_->$ref_pk, @selected ) : 0 ] );
                }
            }
        }
    }
    return $w;
}

sub _build_element {
    my ( $self, $w, $el, $info ) = @_;
    my ( $w_element, %attrs );
    my $label = $info->{label} || join ' ', map { ucfirst } split '_', $el;
    my $size = $info->{size} || 40;
    if ( ref $info->{widget_element} eq 'ARRAY' ) {
        $w_element = $info->{widget_element}[0];
        %attrs     =
          ref $info->{widget_element}[1] eq 'HASH'
          ? %{ $info->{widget_element}[1] }
          : ();
    }
    if ( $el =~ /password|passwd/ ) {
        $w_element ||= 'Password';
        $size = 40 if $size > 40;
        $w->element( 'Password', $el )->label($label)->size($size);
        $w->element( 'Password', "$el\_2" )->label($label)->size($size)
          ->comment('(Confirm)');
        return;
    }
    else {
        $w_element ||= $size > 40 ? 'Textarea' : 'Textfield';
        if ( $w_element eq 'Textarea' ) {
            $attrs{cols} ||= 60;
            $attrs{rows} ||= 5;
        }
        elsif ( $w_element eq 'Textfield' ) {
            $attrs{size}      ||= $size;
            $attrs{maxlength} ||= $size;
        }
    }
    my $element = $w->element( $w_element, $el )->label($label);
    $element->$_( $attrs{$_} ) for keys %attrs;
    $element->value( $self->$el ) if $self->in_storage;
}

sub to_html {
    my ( $self, %a ) = @_;
    my $source  = $self->result_source;
    my @columns = $source->columns;
    my @rels    =
      grep $source->relationship_info($_)->{attrs}{accessor} eq 'multi',
      $source->relationships;
    my @elements =
      $source->result_class->list_columns
      ? @{ $source->result_class->list_columns }
      : ( @columns, @rels );
    my %cols = map { $_ => 1 } @columns;
    my %rels = map { $_ => 1 } @rels;

    my $str = join '', map {
        my $label = $source->column_info($_)->{label};
        "<b>$label</b>:<br/>\n" . $self->$_ . "<br/><br/>\n"
    } grep $cols{$_}, @elements;
    $str .= join '', map {
        my $info  = $source->__relationship_info($_);
        my $meth  = $info->{method};
        my $label = $info->{label};
        "<b>$label</b>:<br/>\n" . join( ', ', $self->$meth ) . "<br/><br/>\n"
    } grep $rels{$_}, @elements;
    return $str;
}

package DBIx::Class::ResultSource::Table;

sub __relationship_info {
    my ( $self, $rel ) = @_;
    my $rel_info = $self->relationship_info($rel) || return;
    my %attrs = ( %$rel_info, rel_name => $rel );
    @attrs{ 'foreign_col', 'self_col' } = %{ $rel_info->{cond} };
    $attrs{foreign_col} =~ s/foreign\.//;
    $attrs{self_col}    =~ s/self\.//;
    if ( $rel_info->{attrs}{accessor} eq 'multi' ) {
        my $source = $self->schema->source( $rel_info->{source} );
        my %rels   = map { $_ => 1 } $source->relationships;

        # many-to-many ?
        if ( keys %rels == 2 && delete $rels{ $self->from } ) {
            $attrs{type} = 'many_to_many';
            my $other_rel_info = $source->relationship_info( keys %rels );
            $attrs{"other_$_"} = $other_rel_info->{$_}
              for keys %$other_rel_info;
            @attrs{ 'other_foreign_col', 'other_self_col' } =
              %{ $other_rel_info->{cond} };
            $attrs{other_foreign_col} =~ s/foreign\.//;
            $attrs{other_self_col}    =~ s/self\.//;
            $attrs{method} =
              Lingua::EN::Inflect::Number::to_PL(
                $self->schema->class( $attrs{other_class} )->table );
            $attrs{label} = join ' ', map { ucfirst } split '_', $attrs{method};
        }
        else {
            $attrs{type}  = 'has_many';
            $attrs{label} =
              Lingua::EN::Inflect::Number::to_PL(
                $self->schema->class( $attrs{class} )->table );
            $attrs{label} = join ' ', map { ucfirst } split '_', $attrs{label};
            $attrs{method} = $rel;
        }
    }
    else {
        $attrs{type} = 'belongs_to';
        my $info = $self->column_info($rel);
        @attrs{ keys %$info } = values %$info;
    }
    return \%attrs;
}

1;
__END__

=pod

=head1 NAME

DBIx::Class::InstantCRUD - Like DBIx::Class::HTMLWidget but handles relationships
and extra info in the columns_info metadata.
It also has methods to put DBIC objects into HTML

=head1 SYNOPSIS

You'll need a working DBIx::Class setup and some knowledge of HTML::Widget
and Catalyst. If you have no idea what I'm talking about, check the (sparse)
docs of those modules.

   package My::Model::DBIC::User;
   use base 'DBIx::Class';
   __PACKAGE__->load_components(qw/InstantCRUD Core/);

   
   package My::Controller::User;    # Catalyst-style
   
   # this renders an edit form with values filled in from the DB 
   sub do_edit : Local {
     my ($self,$c,$id)=@_;
  
     # get the object
     my $item = $c->model('DBIC::User')->find($id);
     # get the widget
     my $w = $item->get_widget;
     $w->action($c->uri_for('do_edit/'.$id));
     
     # process the widget
     my $result = $w->process($c->request);

     if($result->has_errors){
         $c->stash->{widget} = $result;
	 $c->stash->{template} = 'edit';
     } else {
	 $item->populate_from_widget($result);
	 $c->forward('view');
     }
  
  }
  
  sub edit : Local {
    my ($self,$c,$id)=@_;
    
    # get the object from DB
    my $item=$c->model('DBIC::User')->find($id);
    $c->stash->{item}=$item;
    
    # get the widget
    my $w= $item->get_widget;
    $w->action($c->uri_for('do_edit/'.$id));
    
    # process the widget
    $c->stash->{'result'}= $w->process;
  }

  
=head1 DESCRIPTION

Something like DBIx::Class::HTMLWidget but handles relationships
and extra info in the columns_info metadata.
It also has methods to put DBIC objects into HTML

=head2 Methods

=head3 populate_from_widget

   my $obj=$schema->resultset('pet)->new({})->populate_from_widget($result);
   my $item->populate_from_widget($result);

Create or update a DBIx::Class row from a HTML::Widget::Result object

=head1 AUTHORS
 
Thomas Klausner, <domm@cpan.org>, http://domm.zsi.at

Marcus Ramberg, <mramberg@cpan.org>

Zbigniew Lukasiak>  C<zz bb yy @ gmail.com>

Jonas Alves, C<jonas.alves at gmail.com>

=head1 CONTRIBUTORS

Simon Elliott, <cpan@browsing.co.uk>

Kaare Rasmussen

Ashley Berlin

=head1 LICENSE

You may use and distribute this module according to the same terms
that Perl is distributed under.

=cut

########################################### main pod documentation begin ##
# Below is the stub of documentation for your module. You better edit it!


=head1 NAME

HTML::Widget::DBIC - 

=head1 SYNOPSIS

  use HTML::Widget::DBIC
  blah blah blah


=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.


=head1 USAGE



=head1 BUGS



=head1 SUPPORT



=head1 AUTHOR

	Zbigniew Lukasiak
	a.u.thor@a.galaxy.far.far.away
	http://zby.aster.net.pl

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

############################################# main pod documentation end ##


################################################ subroutine header begin ##

=head2 sample_function

 Usage     : How to use this function/method
 Purpose   : What it does
 Returns   : What it returns
 Argument  : What it wants to know
 Throws    : Exceptions and other anomolies
 Comments  : This is a sample subroutine header.
           : It is polite to include more pod and fewer comments.

See Also   : 

=cut

################################################## subroutine header end ##


sub new
{
	my ($class, %parameters) = @_;

	my $self = bless ({}, ref ($class) || $class);

	return ($self);
}


1; #this line is important and will help the module return a true value
__END__

