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

sub populate_from_widget {
    my ( $self, $result ) = @_;
    my @widgets = ( $result, @{ $result->{_embedded} || [] } );
    my @elements = map @{ $_->{_elements} }, @widgets;
    warn "elements: @elements\n";
    my ( @cols, @rels );
    for (@elements) {
        my $name = $_->name;
        if ( $self->has_column($name) ) {
            push @cols, $_;
        }
        elsif ( $self->relationship_info($name) ) {
            push @rels, $_;
        }
    }
    my %obj = map {
        ( $_->isa('HTML::Widget::Element::Password')
              && !$result->param( $_->name ) )
          || ( !defined $result->param( $_->name )
            && !$_->isa('HTML::Widget::Element::Checkbox') )
          || $_->{attributes}{readonly}
          ? ()
          : $_->name => scalar $result->param( $_->name )
    } @cols;
    $self->result_source->schema->txn_do(
        sub {
            $self->set_columns( \%obj );
            my $in_storage = $self->in_storage;
            $self->insert_or_update;
            for (@rels) {
                next if $_->{attributes}{readonly};
                my $name = $_->name;
                my $info = $self->result_source->__relationship_info($name);
                if ( $info->{type} eq 'many_to_many' ) {
                    $self->delete_related($name) if $in_storage;
                    $self->create_related( $name,
                        { $info->{other_self_col} => $_ } )
                      for $result->param($name);
                }
                elsif ( $info->{type} eq 'has_many' ) {
                    if ($in_storage) {
                        my $related_objs = $self->search_related(
                            $name,
                            {
                                $info->{self_col} =>
                                  { -not_in => [ $result->param($name) ] },
                            }
                        );

                        # Let's try to put a NULL in the related objects FK
                        eval {
                            $related_objs->update(
                                { $info->{foreign_col} => undef } );
                          }

             # If the relation can't be NULL the related objects must be deleted
                          || $related_objs->delete;
                    }
                    my ($pk) = $self->result_source->primary_columns;
                    my @values = grep $_, $result->param($name);
                    $self->result_source->schema->resultset( $info->{class} )
                      ->search( { $info->{self_col} => \@values } )
                      ->update( { $info->{foreign_col} => $self->$pk } )
                      if @values;
                }
            }
        }
    );
    return $self;
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
