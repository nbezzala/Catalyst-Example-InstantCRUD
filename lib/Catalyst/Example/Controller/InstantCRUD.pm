package Catalyst::Example::Controller::InstantCRUD;

use version; $VERSION = qv('0.0.11');

use warnings;
use strict;
use base 'Catalyst::Base';

use Carp;
use Data::Dumper;
use HTML::Widget;
use Path::Class;
use HTML::Widget::DBIC;

sub load_interface_config {
    my ( $self, $c ) = @_;
    my $cfile = file( dir( $c->config->{root} )->parent, 'interface_config.dat' );
    my $tmp = do $cfile;
    my $interface_config;
    for my $class ( keys %{$tmp} ){
        for my $field_conf ( @{$tmp->{$class}} ){
            $interface_config->{$class}{fields}{$field_conf->{name}} = $field_conf;
            push @{$interface_config->{$class}{field_order}}, $field_conf->{name};
        }
    }
    return ( $interface_config, $tmp );
}

sub source_name {
    my $self  = shift;
    my $class = ref $self;
    $class =~ /([^:]*)$/;
    return $1;
}

sub model_widget {
    my ( $self, $c, $id ) = @_;
    my ($tmp, $interface_config) = $self->load_interface_config($c);
    my $model_name = $c->config->{InstantCRUD}{model_name};
    my $rs = $self->model_resultset($c);
    my $item = $rs->find($id);
    my $fieldsconfig = $interface_config->{$self->source_name};
    my $w = HTML::Widget::DBIC->create_from_config( $fieldsconfig, $c->model($model_name), $self->source_name, $item ); 
    $w->method( 'post' );
    return $w;
}

sub model_item {
    my ( $self, $c, $id ) = @_;
    my $rs = $self->model_resultset($c);
    my $item = defined $id ? $rs->find($id) : $rs->new( {} );
    return $item;
}

sub model_resultset {
    my ( $self, $c ) = @_;
    my $model_name = $c->config->{InstantCRUD}{model_name};
    my $source     = $self->source_name;
    return $c->model($model_name)->resultset($source);
}

sub model_class {
    my ( $self, $c ) = @_;
    my $model_name = $c->config->{InstantCRUD}{model_name};
    my $source     = $self->source_name;
    return $c->model($model_name)->class($source);
}

sub auto : Local {
    my ( $self, $c ) = @_;
    $c->stash->{additional_template_paths} = [ dir( $c->config->{root}, $self->source_name) . '', $c->config->{root} . ''];
}

sub button {
    my ($name) = @_;
    my $w = HTML::Widget->new('button');
    $w->element( 'Submit', 'ok' )->value($name);
    return $w;
}

sub index : Private {
    my ( $self, $c ) = @_;
    $c->forward('list');
}

sub destroy : Local {
    my ( $self, $c, $id ) = @_;
    if ( $c->req->method eq 'POST' ) {
        $self->model_item( $c, $id )->delete;
        $c->forward('list');
    }
    else {
        my $w =
          $c->widget('widget')->method('post')
          ->action( $c->uri_for( 'destroy', $id ) )
          ->embed( button('Delete ?') );
        $c->stash->{destroywidget} = $w->process;
        $c->stash->{template}      = 'destroy';
    }
}

sub do_add : Local {
    my ( $self, $c ) = @_;
    my $w = $self->model_widget( $c );
    my $fs = $w->element( 'Fieldset', 'Submit' );
    $fs->element( 'Submit', 'ok' )->value('Create');
    my $result = $w->action( $c->uri_for('do_add') )->process( $c->request );
    if ( $result->has_errors ) {
        $c->stash->{widget}   = $result;
        $c->stash->{template} = 'edit';
    }
    else {
        my $item = $result->save_to_db();
        $c->forward( 'view', [ $item->id ] );
    }
}

sub add : Local {
    my ( $self, $c ) = @_;
    my $w = $self->model_widget($c);
    my $fs = $w->element( 'Fieldset', 'Submit' );
    $fs->element( 'Submit', 'ok' )->value('Create');
    $c->stash->{widget} = $w->action( $c->uri_for('do_add') )->process;
    $c->stash->{template} = 'edit';
}

sub do_edit : Local {
    my ( $self, $c, $id ) = @_;
    die "You need to pass an id" unless $id;
    my $w    = $self->model_widget( $c, $id );
    my $fs = $w->element( 'Fieldset', 'Submit' );
    $fs->element( 'Submit', 'ok' )->value('Update');
    my $result = $w->action( $c->uri_for('do_edit') )->process( $c->request );
    if ( $result->has_errors ) {
        $c->stash->{widget}   = $result;
        $c->stash->{template} = 'edit';
    }
    else {
        $result->save_to_db();
        $c->forward('view', [ $id ]);
    }
}

sub edit : Local {
    my ( $self, $c, $id ) = @_;
    die "You need to pass an id" unless $id;
    my $w = $self->model_widget( $c, $id );
    my $fs = $w->element( 'Fieldset', 'Submit' );
    $fs->element( 'Submit', 'ok' )->value('Update');
    $c->stash->{widget} = $w->action( $c->uri_for('do_edit', $id) )->process();
    $c->stash->{template} = 'edit';
}

sub view : Local {
    my ( $self, $c, $id ) = @_;
    die "You need to pass an id" unless $id;
    my $item = $self->model_item( $c, $id );
    $c->stash->{item} = $item;
    my ($interface_config, $tmp) = $self->load_interface_config($c);
    $c->stash->{column_value} = sub { column_value($interface_config, $self->source_name,  @_) };
    $c->stash->{template} = 'view';
}

sub get_resultset {
    my ( $self, $c ) = @_;
    my $params = $c->request->params;
    my $order  = $params->{'order'};
    $order .= ' DESC' if $params->{'o2'};
    my $maxrows = $c->config->{InstantCRUD}{maxrows} || 10;
    my $page = $params->{'page'} || 1;
    return $self->model_resultset($c)->search(
        {},
        {
            page     => $page,
            order_by => $order,
            rows     => $maxrows,
        }
    );
}

sub create_col_link {
    my ( $self, $interface_config, $class, $c, $source ) = @_;
    my $origparams = $c->request->params;
    my %params = %$origparams;    # So that we don't change the params for good
    delete @params{qw/o2 page/};
    my $link = '<a href="%s">%s</a>';
    return sub {
        my ( $column ) = @_;
        my $label = $interface_config->{$class}{fields}{$column}{label};
        if ( ! $source->has_column( $column ) ){
            return $label;
        }
        no warnings 'uninitialized';
        if ( $origparams->{'order'} eq $column && !$origparams->{'o2'} ) {
            $params{o2} = 'desc';
        }
        $params{order} = $column;
        my $result = sprintf $link, $c->uri_for( 'list?', \%params ), $label;
        if ( $origparams->{'order'} && $column eq $origparams->{'order'} ) {
            $result .= $origparams->{'o2'} ? "&darr;" : "&uarr;";
        }
        return $result;
    };
}

sub create_page_link {
    my ( $self, $c ) = @_;
    my $params = $c->request->params;
    my %params = %$params;    # So that we don't change the params for good
    my $link = '<a href="%s">%s</a>';
    return sub {
        my $page = shift;
        $params{page} = $page;
        my $result = sprintf $link, $c->uri_for( 'list?', \%params ), $page;
        return $result;
      }
}

sub column_value {
    my ( $interface_config, $source_name, $item, $column ) = @_;
    my $source  = $item->result_source;
    if ( $source->has_column( $column ) ){
        return $item->$column();
    }
    if ( my $field_conf = $interface_config->{$source_name}{fields}{$column} ){
        my $class = $field_conf->{foreign_class};
        my $name  = $field_conf->{name};
#        my( $meth ) = $interface_config->{$class}{displaymethod};
        my @vals = map {"$_"} $item->$name();
        my $display = join( ', ', @vals);
        return $display;
    }
    warn 'Wrong column';
    warn "source_name: $source_name\n";
}

sub list : Local {
    my ( $self, $c ) = @_;
    my $result = $self->get_resultset($c);
    $c->stash->{page_link} = $self->create_page_link($c);
    $c->stash->{pager}     = $result->pager;
    my $source  = $result->result_source;
#    $c->stash->{columns} = [ $result->html_columns() ];
#    my $model_name = $c->config->{InstantCRUD}{model_name};
#    my $source     = $self->source_name;
#    my $mld = "$model_name::Usr";
#    $c->stash->{aaa} = $c->model('DBICSchemamodel::User')->_aaa();
    ($c->stash->{pri}) = $source->primary_columns;
    my ($interface_config, $tmp) = $self->load_interface_config($c);
    $c->stash->{order_by_column_link} = $self->create_col_link($interface_config, $self->source_name, $c, $source);
    $c->stash->{column_value} = sub { column_value($interface_config, $self->source_name,  @_) };
    $c->stash->{result} = $result;
    $c->stash->{template} = 'list';
}



1;

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

=item load_interface_config
Returns the config hash for input forms (widgets) and other interface elements

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
