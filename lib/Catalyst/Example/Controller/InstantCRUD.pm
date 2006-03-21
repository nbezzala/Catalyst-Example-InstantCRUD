package Catalyst::Example::Controller::InstantCRUD;
use version; $VERSION = qv('0.0.5');
my $LOCATION; 
BEGIN { use File::Spec; $LOCATION = File::Spec->rel2abs(__FILE__) }

use warnings;
use strict;
use Carp;
use base 'Catalyst::Base';
use URI::Escape;
use HTML::Entities;
use Catalyst::Utils;
use HTML::Widget;
use Path::Class;

sub auto : Local {
    my ( $self, $c ) = @_;
    my $viewclass = ref $c->comp('^'.ref($c).'::(V|View)::');
    no strict 'refs';
    my $root   = $c->config->{root};
    my $libroot = file($LOCATION)->parent->subdir('templates');
    my @additional_paths = ("$root/InstantCRUD/" . $self->model_name, "$root/InstantCRUD", $libroot);
    $c->stash->{additional_template_paths} = \@additional_paths;
    my $table = $c->model( 'DBICSchemamodel' )->source( $self->model_name() );
    my @columns = $table->columns;
    $c->stash->{columns} = \@columns;
    my @primary_keys = $table->primary_columns();
    $c->stash->{primary_key} = $primary_keys[0];
    for my $pkcol (@primary_keys){
            $c->stash->{pk}{$pkcol} = 1;
    }
    1;
}

sub model_name {
    my $self = shift;
    my $class = ref $self;
    $class =~ /([^:]*)$/;
    return $1;
}


sub index: Private {
    my ( $self, $c ) = @_;
    $c->forward('list');
}

sub destroy : Local {
    my ( $self, $c, $id ) = @_;
    if ( $c->req->method eq 'POST' ){
        my $model_object = $c->model('DBICSchemamodel::' . $self->model_name());
        $model_object->find($id)->delete;
        $c->forward('list');
    }else{
        my $w = HTML::Widget->new('widget')->method('post');
        $w->action ( $c->uri_for ( 'destroy', $id ));
        $w->element( 'Submit', 'ok' )->value('Delete ?');
        $c->stash->{destroywidget} = $w->process;
        $c->stash->{template} = 'destroy.tt';
    }
}

sub do_add : Local {
    my ( $self, $c ) = @_;
    my $model_object = $c->model('DBICSchemamodel::' . $self->model_name());
    my $widget = $self->_build_widget($c);
    $widget->action ( $c->uri_for ( 'do_add' ));
    my $result = $widget->process($c->request);
    if($result->have_errors){
        $c->stash->{widget} = $result; 
        $c->stash->{template} = 'edit.tt';
    }else{
        my %vals;
        foreach my $col ( @{$c->stash->{columns}} ) {
            next if $c->stash->{pk}{$col};
            $vals{$col} = $c->request->param( $col );
        }
        my $item = $model_object->create( \%vals );
        $c->forward('view', [ $item->id ] );
    }
}

sub add: Local {
    my ( $self, $c ) = @_;
    my $w = $self->_build_widget($c);
    $w->action ( $c->uri_for ( 'do_add' ));
    $c->stash->{widget} = $w->process;
    $c->stash->{template} = 'edit.tt';
}


sub edit_columns {};

sub _build_widget {
    my ( $self, $c, $id, $item ) = @_;
    my $edit_columns= $self->edit_columns();
#    warn 'constraints ' . Dumper($edit_columns);
    my $table = $c->model( 'DBICSchemamodel' )->source( $self->model_name() );
    my $w = HTML::Widget->new('widget')->method('post');
    $w->action ( $c->uri_for ( 'do_edit', $id ));
    for my $column ($table->columns){
        next if ( $column eq $c->stash->{primary_key} );
        if ($table->relationship_info($column)) {
            my $rel_info = $table->relationship_info($column);
            my $rel_class = $rel_info->{class};
            my $ref_pk = ($rel_class->primary_columns())[0];
            $rel_class =~ /::([^:]*)/;
            my $rel_name = $1;
            my @options;
            foreach my $ref_item ($c->model( 'DBICSchemamodel' )->resultset( $rel_name)->search) {
                push @options, $ref_item->$ref_pk(), "$ref_item";
            }
            my $element = $w->element( 'Select', $column)->label(ucfirst($column));
            $element->options(@options);
            $element->selected($item->$column->$ref_pk()) if $item;
        }
        else {
            my $element = $w->element( 'Textfield', $column)->label(ucfirst($column))->size(20);
            $element->value($item->$column) if $item;
        }

        for my $c( @{$edit_columns->{$column}} ){
            my $const = $w->constraint( $c->{constraint}, $column);
            $const->message($c->{message});
            $const->max($c->{max}) if $c->{max};
        }
    }
    if($id){
        $w->element( 'Submit', 'ok' )->value('Update');
    }else{
        $w->element( 'Submit', 'ok' )->value('Create');
    }
    return $w;
}

sub do_edit : Local {
    my ( $self, $c, $id ) = @_;
    my $model_object = $c->model('DBICSchemamodel::' . $self->model_name());
    my $result = $self->_build_widget($c, $id)->process($c->request);
    if($result->have_errors){
        $c->stash->{widget} = $result; 
        $c->stash->{template} = 'edit.tt';
    }else{
        my $item = $model_object->find($id);
        foreach my $col ( @{$c->stash->{columns}} ) {
            next if $c->stash->{pk}{$col};
            $item->$col ( $c->request->param( $col ) ) ;
        }
        $item->update;
        $c->forward('view');
    }
}



sub edit : Local {
    my ( $self, $c, $id ) = @_;
    my $model_object = $c->model('DBICSchemamodel::' . $self->model_name());
    my $item = $model_object->find($id);
    my $w = $self->_build_widget($c, $id, $item)->process();
    $c->stash->{widget} = $w;
    $c->stash->{template} = 'edit.tt';
}


sub create_page_link {
    my ( $c, $page, $origparams ) = @_;
    my %params = %$origparams;          # So that we don't change the params for good
    $params{page} = $page;
    my $addr;
    for my $key (keys %params){
        $addr .= "&$key=" . $params{$key};
    }
    $addr = uri_escape($addr, q{^;/?:@&=+\$,A-Za-z0-9\-_.!~*'()} );
    $addr = encode_entities($addr, '<>&"');
    my $result = '<a href="' . $c->uri_for( 'list?' );
    $result .= $addr . '">' . $page . '</a>';
    return $result;
}

sub create_col_link {
    my ( $c, $column, $origparams ) = @_;
    my %params = %$origparams;          # So that we don't change the params for good
    delete $params{o2};
    delete $params{page};
    if(($origparams->{'order'} eq $column) and !$origparams->{'o2'}){
        $params{o2} = 'desc';
    }
    $params{order} = $column;
    my $addr;
    for my $key (keys %params){
        $addr .= "&$key=" . $params{$key};
    }
    $addr = uri_escape($addr, q{^;/?:@&=+\$,A-Za-z0-9\-_.!~*'()} );
    $addr = encode_entities($addr, '<>&"');
    my $result = '<a href="' . $c->uri_for( 'list?' );
    $result .= $addr . '">' . $column . '</a>';
    if($origparams->{'order'} and $column eq $origparams->{'order'}){
        if($origparams->{'o2'}){
            $result .= "&darr;";
        }else{
            $result .= "&uarr;";
        }
    }
    return $result;
}

sub list : Local {
    my ( $self, $c ) = @_;
    my $params = $c->request->params;
    my $order = $params->{'order'};
    $order .= ' DESC' if $params->{'o2'};
    my $maxrows = 10;                             # number or rows on page
    my $page = $params->{'page'} || 1;
#    die  $self->model_name();
    my $model_object = $c->model('DBICSchemamodel::' . $self->model_name());
    $c->stash->{objects} = [
        $model_object->search(
            {},
            { 
                page => $page,
                order_by => $order,
                rows => $maxrows,
            },
        ) ];
    my $count = $model_object->count();
    $c->stash->{pages} = int(($count - 1) / $maxrows) + 1;
    $c->stash->{order_by_column_link} = sub {
        my $column = shift;
        return create_col_link($c, $column, $params);
    };
    $c->stash->{page_link} = sub {
        my $page = shift;
        return create_page_link($c, $page, $params );
    };
    $c->stash->{template} = 'list.tt';
}

sub view : Local {
    my ( $self, $c, $id ) = @_;
    my $model_object = $c->model('DBICSchemamodel::' . $self->model_name());
    $c->stash->{item} = $model_object->find($id);
    $c->stash->{template} = 'view.tt';
}


1; # Magic true value required at end of module
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

=item model_name
Class method for finding name of corresponding database table.

=item auto
This automatically called method puts on the stash path to templates
distributed with this module

=item add
Method for displaying form for adding new records

=item create_col_link
Subroutine placed on stash for templates to use.

=item create_page_link
Subroutine placed on stash for templates to use.

=item index
Forwards to list

=item destroy
Deleting records.

=item do_add
Method for adding new records

=item do_edit
Method for editin existing records

=item edit_columns
Should be overriden in subclass to something like:
sub edit_columns {
    {
        'integerfield' => {
                                'constraint' => 'Integer',
                                'message' => 'Should be a number'
                           }
     };
}


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
