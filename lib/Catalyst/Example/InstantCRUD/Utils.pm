package Catalyst::Example::InstantCRUD::Utils; 

use strict;
use warnings;
use Data::Dumper;

=head1 NAME

Catalyst::Example::InstantCRUD::Utils - Utils for InstantCRUD.

=head1 METHODS

=over 4

=item load_schema

Method to load a schema from the DB

=cut

sub load_schema {
    my ( $self, $schema, %a ) = @_;
    my %auth  = %{$a{auth}||{}};
    my %authz = %{$a{authz}||{}};
    
    my (@classes, %rels, %elems, %many_to_many_relation_table);
    my %ret;

    for my $s ( @classes = $schema->sources ) {
        my $source = $schema->source($s);
        my $c = $schema->class($s);
        my $table = $c->table;
        
        # Let's try to discover the auth and authz tables and fields if none where given
	unless ($a{noauth}) {
	    $auth{user_table}  ||= $table and $auth{user_class}  ||= $s
	      if $table =~ /^(usr|users?)$/i;
	    $authz{role_table} ||= $table and $authz{role_class} ||= $s
              if $table =~ /^roles?$/i;
            if ($auth{user_table}) {
    	        unless ($auth{user_field}) {
    	            my @possible_user_fields = grep /login|user|usr/i, $source->columns;
    	            if (@possible_user_fields == 1) {
                            ($auth{user_field}) = @possible_user_fields;
    	            } elsif (@possible_user_fields > 1) {
    	        	print "\nWhat is the user field in your '$auth{user_table}' table?\n> ";
    	        	chomp($auth{user_field} = <STDIN>);
    	            }
    	        }
    	        unless ($auth{password_field}) {
    	            my @possible_password_fields = grep /pass\W|password|passwd/i, $source->columns;
    	            if (@possible_password_fields == 1) {
                            ($auth{password_field}) = @possible_password_fields;
    	            } else {
    	        	print "\nWhat is the password field in your '$auth{user_table}' table?\n> ";
    	        	chomp($auth{password_field }= <STDIN>);
    	            }
    	        }
		if ($auth{password_field} && !$auth{password_type}) {
		    my @passwords = $schema->resultset($auth{user_class})
		       ->search(undef, { rows => 5, select => [$auth{password_field}] });
		    if (@passwords) {
			my $meth = $auth{password_field};
		        @passwords = map { $_->$meth } @passwords;
			my $l = length $passwords[0];
			if (@passwords == scalar grep { $l == length $_ } @passwords) {
			    # all the passwords have the same lenght.
			    # they might be hashed
	                    $auth{password_type}      = 'hashed';
			    $auth{password_hash_type} = 'SHA-1' if $l == 40; 
			    $auth{password_hash_type} = 'MD5'   if $l == 32;
		        }	
		    } else {
	                $auth{password_type}      ||= 'hashed';
	                $auth{password_hash_type} ||= 'SHA-1';
		    }
	        }
            }
            if ($authz{role_table}) {
    	        unless ($authz{role_field}) {
    	            my @possible_role_fields = grep /roles?/i, $source->columns;
    	            if (@possible_role_fields == 1) {
                            ($authz{role_field}) = @possible_role_fields;
    	            } elsif (@possible_role_fields > 1) {
    	        	print "\nWhat is the role field in your '$authz{role_table}' table?\n> ";
    	        	chomp($authz{role_field }= <STDIN>);
    	            }
    	        }
            }
	}
        
        my @relationships = $c->relationships;
        my @pk = $source->primary_columns();
        my %columns;
        for my $col ($source->columns) {
            $columns{$col} = $source->column_info($col);
            delete $columns{$col}{$_} for grep /^_/, keys %{$columns{$col}};
            $columns{$col}{name} = $col;
            $columns{$col}{label} = join ' ', map { ucfirst } split '_', $col;
    	    $columns{$col}{is_auto_increment} = 1 if grep /^$col$/, @pk;
            #$columns{$col}{is_foreign_key} = 0;
            # Let's create the constraints
            $columns{$col}{constraints} = [];
            if ( $columns{$col}{data_type} =~ /int/i ) {
                push @{$columns{$col}{constraints}},  {
                    constraint => 'Integer',
                    message => 'Should be a number',
                }
            }
            #if ( $schema->storage->dbh->{Driver}->{Name} eq 'Pg' &&
            #    $columns{$col}{data_type} =~ /int/i ){
            #    $columns{$col}{size} = int( $columns{$col}{size} * 12 / 5 );
            #}
            if ( $columns{$col}{data_type} =~ /^date$/i ) {
	    #    $columns{$col}{widget_element} = [
    	    #        'Date' => { format => 'yyyy-mm-dd' }
    	    #    ];
	    #    #push @{$columns{$col}{constraints}},  {
            #    #    constraint => 'Date',
            #    #    message => "Should be a valid date (YYYY-MM-DD).",
            #    #};
            #}
            #elsif ( $columns{$col}{data_type} =~ /^datetime$/i ) {
            #    $columns{$col}{widget_element} = [
    	    #        'DateTime' => { format => 'yyyy-mm-dd HH:MM:SS' }
    	    #    ];
	    #    #push @{$columns{$col}{constraints}},  {
            #    #    constraint => 'DateTime',
            #    #    message => "Should be a valid date and time (YYYY-MM-DD HH:MM:SS).",
            #    #};
            }
            elsif ( $columns{$col}{size} ) {
                push @{$columns{$col}{constraints}},  {
                    constraint => 'Length',
                    message => "Should be shorten than $columns{$col}{size} characters",
                    max => $columns{$col}{size},
                };
    	        if ( $columns{$col}{size} > 40 ) {
                    $columns{$col}{widget_element} = [
    		        'Textarea' => { rows => 5, cols => 60 }
    		    ];
                }
    	        else {
                    $columns{$col}{widget_element} = [
    		        'Textfield' => { 
    		            size      => $columns{$col}{size},
    		            maxlength => $columns{$col}{size},
    	                }
    		    ];
                }
            }
            if ( !$columns{$col}{is_nullable} && !$columns{$col}{is_auto_increment}){
                push @{$columns{$col}{constraints}},  {
                    constraint => 'All',
                    message => "The field is required",
                }
            }
            if ( $col =~ /password|passwd/ ) {
                push @{$columns{$col}{constraints}},  {
                    constraint => 'Equal',
    		    args => [ "$col\_2" ],
                    message => "Passwords must match",
                }, {
                    constraint => 'AllOrNone',
    		    args => [ "$col\_2" ],
                    message => "Confirm the password",
                };
                if ($auth{password_hash_type}) {
                    $rels{$c} = "__PACKAGE__->digestcolumns(
    columns   => [qw/$col/],
    algorithm => '$auth{password_hash_type}',
    auto      => 1,
);
" . $rels{$c};
                }
            }
    
        }
        (my $columns = Dumper \%columns) =~ s/^\$VAR1 = {|\s*};$//g;
    
        # And now the relationships
        my (@rel_type, @rel_info);
        for my $rel (@relationships) {
            my $info = $source->relationship_info($rel);
            push @rel_info, $info;
            my $d = Data::Dumper->new([@$info{qw(class cond)}]);
            $d->Purity(1)->Terse(1)->Deepcopy(1)->Indent(0);
            my $relationship = $info->{attrs}{accessor} eq 'multi' ? 'has_many' : 'belongs_to';
            push @rel_type, $relationship;
            $rels{$c} .= 
              "__PACKAGE__->$relationship('$rel', " . join(', ',$d->Dump) . ");\n";
        }
        my @cols = $source->columns;
	push @{$elems{$c} ||= []}, @cols, @relationships;
    
        # Let's check if this table is for a many-to-many relationship.
        # If so then we create a many-to-many relationship in the related classes.
        # NOTE: This just handles the most common and simple case where exists a
        # table that has 2FK's to other two related tables,
        # both with a has_many relationship with first the table.
        if (scalar(@relationships) == 2 && scalar(@cols) == 2 &&
            scalar(grep {/belongs_to/} @rel_type) == 2) {
    	    my $inflector = DBIx::Class::Schema::Loader::RelBuilder->new;
            my $other_class1 = $schema->class($rel_info[0]->{class});
            my $other_class2 = $schema->class($rel_info[1]->{class});
            my $other_rel_name = $inflector->_inflect_plural($table);
            my $other_rel_info1 = $other_class1->relationship_info($other_rel_name) ;
            my $other_rel_info2 = $other_class2->relationship_info($other_rel_name) ;
            if ($other_rel_info1 && $other_rel_info2) {
                $many_to_many_relation_table{$table} = [$other_class1->table, $other_class2->table, @cols];
                my $new_rel_name1 = $inflector->_inflect_plural($other_class1->table);
                my $new_rel_name2 = $inflector->_inflect_plural($other_class2->table);
                $rels{$other_class1} .= 
                  "__PACKAGE__->many_to_many('$new_rel_name2', '$other_rel_name' => '$relationships[1]');\n";
                $rels{$other_class2} .= 
                  "__PACKAGE__->many_to_many('$new_rel_name1', '$other_rel_name' => '$relationships[0]');\n";
                push @{$elems{$other_class1} ||= []}, $new_rel_name2;
                push @{$elems{$other_class2} ||= []}, $new_rel_name1;
            }
        }
        my $overload_method = $source->has_column('name') ? 'name' : $pk[0];
        $ret{tables}{$table} = {
            relationships => \@relationships,
            columns => $columns,
            overload_method => ($source->has_column('name') ? 'name' : $pk[0]),
            pks => \@pk,
            cols => \@cols,
            c => $c,
            source => $s,
        }
    }

    unless ($a{noauth}) {
        # Let's check if we have a user/role relationship table
        for (keys %many_to_many_relation_table) {
            if ($auth{user_table} && $authz{role_table} && !$authz{role_rel}) {
                my ($t1, $t2, @cols) = @{$many_to_many_relation_table{$_}};
                if ($auth{user_table}=~ /^($t1|$t2)$/ && $authz{role_table} =~ /^($t1|$t2)$/) {
        		$authz{role_rel} = $_;
        	        ($authz{user_role_user_field}) ||= grep /login|user|name|$auth{user_field}/, @cols;
        	    }
            }
        }
        $ret{auth} = \%auth   if $auth{user_table};
        $ret{authz} = \%authz if $authz{role_table};
    }
    
    $ret{rels} = \%rels;
    $ret{elems} = \%elems;
    $ret{classes} = \@classes;
    $ret{many_to_many_relation_table} = \%many_to_many_relation_table;
    return \%ret;
}

1;
