package HTML::Widget::Element::DoubleSelect;

use warnings;
use strict;
use base 'HTML::Widget::Element::Select';
use Data::Dumper;

__PACKAGE__->mk_accessors(qw/js_options/);

=head1 NAME

HTML::Widget::Element::DoubleSelect - JSAN Widget.Select Element

=head1 SYNOPSIS

    my $e = $widget->element( 'JSAN::Widget::Select', 'foo' );
    $e->comment('(Required)');
    $e->label('Foo');

=head1 DESCRIPTION

JSAN Widget.Select Element.

If the users' JavaScript is disabled, they will see a plain Select 
element. If a C<value> is set, the Textfield will contain that, otherwise 
it will contain the C<dateFormat> string, but formatted like C<mm/dd/yyyy> 
instead of C<%m/%d/%Y>.

This Element inherits from 
L<HTML::Widget::Element::Select|HTML::Widget::Element::Select>, so 
it's methods are available.

=head1 METHODS

=head2 js_options

This returns a hash-ref of options that will be passed to the 
js widget constructor.

Options that can be set are:

=over

=back

=head2 $self->prepare()

=cut

# override prepare. We do not want constraints here.
sub prepare {}

=head2 $self->containerize

Containerize the element, label and error for later rendering. Uses HTML::Widget::Container by default, but this can be over-ridden on a class or instance basis via L<container_class>.

=cut

sub containerize {
    my ( $self, $w, $value, $errors ) = @_;

    my $o = $self->options;
    my $opt = $self->js_options || {};
    my $name = $self->name;
    #$opt->{new_right_options} ||= $name;
    $opt->{delimiter} ||= ',';
    
    my @options = ref $o eq 'ARRAY' ? @$o : ();
    my @values;
    if ($value) {
        @values = ref $value eq 'ARRAY'
	  ? @$value
	  : split($opt->{delimiter}, $value);
    }
    else {
        @values = ref $self->selected eq 'ARRAY'
          ? @{ $self->selected }
          : split($opt->{delimiter}, $self->selected || '');
    }
    
    my %selected = map { $_ => 1 } @values;

    my @temp_options = @options;
    my @o = ([], []);
    while ( scalar @temp_options ) {
        my $key    = shift @temp_options;
        my $value  = shift @temp_options;
        my $option = HTML::Element->new( 'option', value => $key );
        $option->push_content($value);
        push @{$o[$selected{$key} ? 1 : 0]}, $option;
    }
    
    my $label = $self->mk_label( $w, $self->label, $self->comment, $errors );

    my $selectelm = $self->mk_tag($w, 'select', { _suffix => 'left' });
    $selectelm->push_content(@{$o[0]});
    $selectelm->attr( multiple => 'multiple' ) if $self->multiple;

    my $selectelm2 = $self->mk_tag($w, 'select', { _suffix => 'right' });
    $selectelm2->push_content(@{$o[1]});
    $selectelm2->attr( name => $name );
    $selectelm2->attr( multiple => 'multiple' ) if $self->multiple;

    my $class = $self->attributes->{class} ||= 'doubleselect';
    
    my $button_left = $self->mk_input( $w, {
        type    => 'button',
        value   => '<',
        _suffix => 'button_left',
    } );
    $button_left->attr( class => "$class\_button_left");
    $button_left->attr( name => "$name\_move_left");
    my $button_right = $self->mk_input( $w, {
        type    => 'button',
        value   => '>',
        _suffix => 'button_right',
    } );
    $button_right->attr( name => "$name\_move_right");
    $button_right->attr( class => "$class\_button_right");
    
    my $buttons = HTML::Element->new('span');
    $buttons->push_content($button_left, $button_right);
    $buttons->attr( class => "$class\_buttons" );

    my %hidden;
    for (grep { exists $opt->{$_} && $opt->{$_} } 
	    qw/removed_left_options removed_right_options
	    added_left_options added_right_options
	    new_left_options new_right_options/)
    {
         $hidden{$_} = $self->mk_input( $w, { type => 'hidden', _suffix => $_ } );
         $hidden{$_}->attr( class => 'hidden' );
         $hidden{$_}->attr( name  => $opt->{$_} );
    }
    
    my $dselect = HTML::Element->new('span');
    $dselect->push_content($selectelm, $buttons, $selectelm2);
    $dselect->push_content($_) for values %hidden;
    $dselect->attr( class => $class );
    $dselect->attr( id    => $self->id($w) );
    
    my $e = $self->mk_error( $w, $errors );

    my $js = "var opt_$name = new OptionTransfer('$name\_left', '$name');\n";
    $js .= sprintf "opt_$name.setAutoSort('%s');\n", $opt->{auto_sort} ? 'true' : 'false';
    $js .= "opt_$name.setDelimiter('$opt->{delimiter}');\n";
    $js .= "opt_$name.setStatiOptionRegex('$opt->{static_option_regex}');\n"
      if $opt->{static_option_regex};
    $js .= "opt_$name.saveRemovedLeftOptions('$opt->{removed_left_options}');\n"
      if $opt->{removed_left_options};
    $js .= "opt_$name.saveRemovedRightOptions('$opt->{removed_right_options}');\n"
      if $opt->{removed_right_options};
    $js .= "opt_$name.saveAddedLeftOptions('$opt->{added_left_options}');\n"
      if $opt->{added_left_options};
    $js .= "opt_$name.saveAddedRightOptions('$opt->{added_right_options}');\n"
      if $opt->{added_right_options};
    $js .= "opt_$name.saveNewLeftOptions('$opt->{new_left_options}');\n"
      if $opt->{new_left_options};
    $js .= "opt_$name.saveNewRightOptions('$opt->{new_right_options}');\n"
      if $opt->{new_right_options};
    $js .= "opt_$name.setTransferLeft('$name\_move_left');\n";
    $js .= "opt_$name.setTransferRight('$name\_move_right');\n";
    $js .= "opt_$name.init(document.forms[0]);";
	    
    return $self->container( {
         element    => $dselect,
	 error      => $e,
	 label      => $label,
         javascript => $js,
    } );
}

=head2 $self->mk_tag( $w, $tagtype, $attrs, $errors )

Creates a new tag.

=cut

sub mk_tag {
    my ( $self, $w, $tag, $attrs, $errors ) = @_;
    my $suffix = delete $attrs->{_suffix};
    my $e = $self->SUPER::mk_tag($w, $tag, $attrs, $errors);
    if ($suffix) {
        $e->attr( id => $e->attr('id') . "_$suffix" );
        $e->attr( name => $e->attr('name') . "_$suffix" );
        $e->attr( class => $e->attr('class') . "_$suffix" );
    }
    return $e;
}

=head2 $self->js_lib()

Returns the javascript library

=cut

sub js_lib {
    return <<'END';
function addEvent(elm, evType, fn, useCapture)
// addEvent and removeEvent
// cross-browser event handling for IE5+,  NS6 and Mozilla
// By Scott Andrew
{
  if (elm.addEventListener){
    elm.addEventListener(evType, fn, useCapture);
    return true;
  } else if (elm.attachEvent){
    var r = elm.attachEvent("on"+evType, fn);
    return r;
  } else {
    alert("Handler could not be removed");
  }
}

// ===================================================================
// Author: Matt Kruse <matt@mattkruse.com>
// WWW: http://www.mattkruse.com/
//
// NOTICE: You may use this code for any purpose, commercial or
// private, without any further permission from the author. You may
// remove this notice from your final code if you wish, however it is
// appreciated by the author if at least my web site address is kept.
//
// You may *NOT* re-distribute this code in any way except through its
// use. That means, you can include it in your product, or your web
// site, or any other form where the code is actually being used. You
// may not put the plain javascript up on your site for download or
// include it in your javascript libraries for download. 
// If you wish to share this code with others, please just point them
// to the URL instead.
// Please DO NOT link directly to my .js files from your site. Copy
// the files to your server and use them there. Thank you.
// ===================================================================


/* SOURCE FILE: selectbox.js */

// HISTORY
// ------------------------------------------------------------------
// June 12, 2003: Modified up and down functions to support more than
//                one selected option
/*
DESCRIPTION: These are general functions to deal with and manipulate
select boxes. Also see the OptionTransfer library to more easily 
handle transferring options between two lists

COMPATABILITY: These are fairly basic functions - they should work on
all browsers that support Javascript.
*/


// -------------------------------------------------------------------
// hasOptions(obj)
//  Utility function to determine if a select object has an options array
// -------------------------------------------------------------------
function hasOptions(obj) {
	if (obj!=null && obj.options!=null) { return true; }
	return false;
	}

// -------------------------------------------------------------------
// selectUnselectMatchingOptions(select_object,regex,select/unselect,true/false)
//  This is a general function used by the select functions below, to
//  avoid code duplication
// -------------------------------------------------------------------
function selectUnselectMatchingOptions(obj,regex,which,only) {
	if (window.RegExp) {
		if (which == "select") {
			var selected1=true;
			var selected2=false;
			}
		else if (which == "unselect") {
			var selected1=false;
			var selected2=true;
			}
		else {
			return;
			}
		var re = new RegExp(regex);
		if (!hasOptions(obj)) { return; }
		for (var i=0; i<obj.options.length; i++) {
			if (re.test(obj.options[i].text)) {
				obj.options[i].selected = selected1;
				}
			else {
				if (only == true) {
					obj.options[i].selected = selected2;
					}
				}
			}
		}
	}
		
// -------------------------------------------------------------------
// selectMatchingOptions(select_object,regex)
//  This function selects all options that match the regular expression
//  passed in. Currently-selected options will not be changed.
// -------------------------------------------------------------------
function selectMatchingOptions(obj,regex) {
	selectUnselectMatchingOptions(obj,regex,"select",false);
	}
// -------------------------------------------------------------------
// selectOnlyMatchingOptions(select_object,regex)
//  This function selects all options that match the regular expression
//  passed in. Selected options that don't match will be un-selected.
// -------------------------------------------------------------------
function selectOnlyMatchingOptions(obj,regex) {
	selectUnselectMatchingOptions(obj,regex,"select",true);
	}
// -------------------------------------------------------------------
// unSelectMatchingOptions(select_object,regex)
//  This function Unselects all options that match the regular expression
//  passed in. 
// -------------------------------------------------------------------
function unSelectMatchingOptions(obj,regex) {
	selectUnselectMatchingOptions(obj,regex,"unselect",false);
	}
	
// -------------------------------------------------------------------
// sortSelect(select_object)
//   Pass this function a SELECT object and the options will be sorted
//   by their text (display) values
// -------------------------------------------------------------------
function sortSelect(obj) {
	var o = new Array();
	if (!hasOptions(obj)) { return; }
	for (var i=0; i<obj.options.length; i++) {
		o[o.length] = new Option( obj.options[i].text, obj.options[i].value, obj.options[i].defaultSelected, obj.options[i].selected) ;
		}
	if (o.length==0) { return; }
	o = o.sort( 
		function(a,b) { 
			if ((a.text+"") < (b.text+"")) { return -1; }
			if ((a.text+"") > (b.text+"")) { return 1; }
			return 0;
			} 
		);

	for (var i=0; i<o.length; i++) {
		obj.options[i] = new Option(o[i].text, o[i].value, o[i].defaultSelected, o[i].selected);
		}
	}

// -------------------------------------------------------------------
// selectAllOptions(select_object)
//  This function takes a select box and selects all options (in a 
//  multiple select object). This is used when passing values between
//  two select boxes. Select all options in the right box before 
//  submitting the form so the values will be sent to the server.
// -------------------------------------------------------------------
function selectAllOptions(obj) {
	if (!hasOptions(obj)) { return; }
	for (var i=0; i<obj.options.length; i++) {
		obj.options[i].selected = true;
		}
	}
	
// -------------------------------------------------------------------
// moveSelectedOptions(select_object,select_object[,autosort(true/false)[,regex]])
//  This function moves options between select boxes. Works best with
//  multi-select boxes to create the common Windows control effect.
//  Passes all selected values from the first object to the second
//  object and re-sorts each box.
//  If a third argument of 'false' is passed, then the lists are not
//  sorted after the move.
//  If a fourth string argument is passed, this will function as a
//  Regular Expression to match against the TEXT or the options. If 
//  the text of an option matches the pattern, it will NOT be moved.
//  It will be treated as an unmoveable option.
//  You can also put this into the <SELECT> object as follows:
//    onDblClick="moveSelectedOptions(this,this.form.target)
//  This way, when the user double-clicks on a value in one box, it
//  will be transferred to the other (in browsers that support the 
//  onDblClick() event handler).
// -------------------------------------------------------------------
function moveSelectedOptions(from,to) {
	// Unselect matching options, if required
	if (arguments.length>3) {
		var regex = arguments[3];
		if (regex != "") {
			unSelectMatchingOptions(from,regex);
			}
		}
	// Move them over
	if (!hasOptions(from)) { return; }
	for (var i=0; i<from.options.length; i++) {
		var o = from.options[i];
		if (o.selected) {
			if (!hasOptions(to)) { var index = 0; } else { var index=to.options.length; }
			to.options[index] = new Option( o.text, o.value, false, false);
			}
		}
	// Delete them from original
	for (var i=(from.options.length-1); i>=0; i--) {
		var o = from.options[i];
		if (o.selected) {
			from.options[i] = null;
			}
		}
	if ((arguments.length<3) || (arguments[2]==true)) {
		sortSelect(from);
		sortSelect(to);
		}
	from.selectedIndex = -1;
	to.selectedIndex = -1;
	}

// -------------------------------------------------------------------
// copySelectedOptions(select_object,select_object[,autosort(true/false)])
//  This function copies options between select boxes instead of 
//  moving items. Duplicates in the target list are not allowed.
// -------------------------------------------------------------------
function copySelectedOptions(from,to) {
	var options = new Object();
	if (hasOptions(to)) {
		for (var i=0; i<to.options.length; i++) {
			options[to.options[i].value] = to.options[i].text;
			}
		}
	if (!hasOptions(from)) { return; }
	for (var i=0; i<from.options.length; i++) {
		var o = from.options[i];
		if (o.selected) {
			if (options[o.value] == null || options[o.value] == "undefined" || options[o.value]!=o.text) {
				if (!hasOptions(to)) { var index = 0; } else { var index=to.options.length; }
				to.options[index] = new Option( o.text, o.value, false, false);
				}
			}
		}
	if ((arguments.length<3) || (arguments[2]==true)) {
		sortSelect(to);
		}
	from.selectedIndex = -1;
	to.selectedIndex = -1;
	}

// -------------------------------------------------------------------
// moveAllOptions(select_object,select_object[,autosort(true/false)[,regex]])
//  Move all options from one select box to another.
// -------------------------------------------------------------------
function moveAllOptions(from,to) {
	selectAllOptions(from);
	if (arguments.length==2) {
		moveSelectedOptions(from,to);
		}
	else if (arguments.length==3) {
		moveSelectedOptions(from,to,arguments[2]);
		}
	else if (arguments.length==4) {
		moveSelectedOptions(from,to,arguments[2],arguments[3]);
		}
	}

// -------------------------------------------------------------------
// copyAllOptions(select_object,select_object[,autosort(true/false)])
//  Copy all options from one select box to another, instead of
//  removing items. Duplicates in the target list are not allowed.
// -------------------------------------------------------------------
function copyAllOptions(from,to) {
	selectAllOptions(from);
	if (arguments.length==2) {
		copySelectedOptions(from,to);
		}
	else if (arguments.length==3) {
		copySelectedOptions(from,to,arguments[2]);
		}
	}

// -------------------------------------------------------------------
// swapOptions(select_object,option1,option2)
//  Swap positions of two options in a select list
// -------------------------------------------------------------------
function swapOptions(obj,i,j) {
	var o = obj.options;
	var i_selected = o[i].selected;
	var j_selected = o[j].selected;
	var temp = new Option(o[i].text, o[i].value, o[i].defaultSelected, o[i].selected);
	var temp2= new Option(o[j].text, o[j].value, o[j].defaultSelected, o[j].selected);
	o[i] = temp2;
	o[j] = temp;
	o[i].selected = j_selected;
	o[j].selected = i_selected;
	}
	
// -------------------------------------------------------------------
// moveOptionUp(select_object)
//  Move selected option in a select list up one
// -------------------------------------------------------------------
function moveOptionUp(obj) {
	if (!hasOptions(obj)) { return; }
	for (i=0; i<obj.options.length; i++) {
		if (obj.options[i].selected) {
			if (i != 0 && !obj.options[i-1].selected) {
				swapOptions(obj,i,i-1);
				obj.options[i-1].selected = true;
				}
			}
		}
	}

// -------------------------------------------------------------------
// moveOptionDown(select_object)
//  Move selected option in a select list down one
// -------------------------------------------------------------------
function moveOptionDown(obj) {
	if (!hasOptions(obj)) { return; }
	for (i=obj.options.length-1; i>=0; i--) {
		if (obj.options[i].selected) {
			if (i != (obj.options.length-1) && ! obj.options[i+1].selected) {
				swapOptions(obj,i,i+1);
				obj.options[i+1].selected = true;
				}
			}
		}
	}

// -------------------------------------------------------------------
// removeSelectedOptions(select_object)
//  Remove all selected options from a list
//  (Thanks to Gene Ninestein)
// -------------------------------------------------------------------
function removeSelectedOptions(from) { 
	if (!hasOptions(from)) { return; }
	for (var i=(from.options.length-1); i>=0; i--) { 
		var o=from.options[i]; 
		if (o.selected) { 
			from.options[i] = null; 
			} 
		} 
	from.selectedIndex = -1; 
	} 

// -------------------------------------------------------------------
// removeAllOptions(select_object)
//  Remove all options from a list
// -------------------------------------------------------------------
function removeAllOptions(from) { 
	if (!hasOptions(from)) { return; }
	for (var i=(from.options.length-1); i>=0; i--) { 
		from.options[i] = null; 
		} 
	from.selectedIndex = -1; 
	} 

// -------------------------------------------------------------------
// addOption(select_object,display_text,value,selected)
//  Add an option to a list
// -------------------------------------------------------------------
function addOption(obj,text,value,selected) {
	if (obj!=null && obj.options!=null) {
		obj.options[obj.options.length] = new Option(text, value, false, selected);
		}
	}


/* SOURCE FILE: OptionTransfer.js */

/* 
OptionTransfer.js
Last Modified: 7/12/2004

DESCRIPTION: This widget is used to easily and quickly create an interface
where the user can transfer choices from one select box to another. For
example, when selecting which columns to show or hide in search results.
This object adds value by automatically storing the values that were added
or removed from each list, as well as the state of the final list. 

COMPATABILITY: Should work on all Javascript-compliant browsers.

USAGE:
// Create a new OptionTransfer object. Pass it the field names of the left
// select box and the right select box.
var ot = new OptionTransfer("from","to");

// Optionally tell the lists whether or not to auto-sort when options are 
// moved. By default, the lists will be sorted.
ot.setAutoSort(true);

// Optionally set the delimiter to be used to separate values that are
// stored in hidden fields for the added and removed options, as well as
// final state of the lists. Defaults to a comma.
ot.setDelimiter("|");

// You can set a regular expression for option texts which are _not_ allowed to
// be transferred in either direction
ot.setStaticOptionRegex("static");

// These functions assign the form fields which will store the state of
// the lists. Each one is optional, so you can pick to only store the
// new options which were transferred to the right list, for example.
// Each function takes the name of a HIDDEN or TEXT input field.

// Store list of options removed from left list into an input field
ot.saveRemovedLeftOptions("removedLeft");
// Store list of options removed from right list into an input field
ot.saveRemovedRightOptions("removedRight");
// Store list of options added to left list into an input field
ot.saveAddedLeftOptions("addedLeft");
// Store list of options radded to right list into an input field
ot.saveAddedRightOptions("addedRight");
// Store all options existing in the left list into an input field
ot.saveNewLeftOptions("newLeft");
// Store all options existing in the right list into an input field
ot.saveNewRightOptions("newRight");

// IMPORTANT: This step is required for the OptionTransfer object to work
// correctly.
// Add a call to the BODY onLoad="" tag of the page, and pass a reference to
// the form which contains the select boxes and input fields.
BODY onLoad="ot.init(document.forms[0])"

// ADDING ACTIONS INTO YOUR PAGE
// Finally, add calls to the object to move options back and forth, either
// from links in your page or from double-clicking the options themselves.
// See example page, and use the following methods:
ot.transferRight();
ot.transferAllRight();
ot.transferLeft();
ot.transferAllLeft();


NOTES:
1) Requires the functions in selectbox.js

*/ 
function OT_transferLeft() { moveSelectedOptions(this.right,this.left,this.autoSort,this.staticOptionRegex); this.update(); }
function OT_transferRight() { moveSelectedOptions(this.left,this.right,this.autoSort,this.staticOptionRegex); this.update(); }
function OT_transferAllLeft() { moveAllOptions(this.right,this.left,this.autoSort,this.staticOptionRegex); this.update(); }
function OT_transferAllRight() { moveAllOptions(this.left,this.right,this.autoSort,this.staticOptionRegex); this.update(); }
function OT_saveRemovedLeftOptions(f) { this.removedLeftField = f; }
function OT_saveRemovedRightOptions(f) { this.removedRightField = f; }
function OT_saveAddedLeftOptions(f) { this.addedLeftField = f; }
function OT_saveAddedRightOptions(f) { this.addedRightField = f; }
function OT_saveNewLeftOptions(f) { this.newLeftField = f; }
function OT_saveNewRightOptions(f) { this.newRightField = f; }
function OT_update() {
	var removedLeft = new Object();
	var removedRight = new Object();
	var addedLeft = new Object();
	var addedRight = new Object();
	var newLeft = new Object();
	var newRight = new Object();
	for (var i=0;i<this.left.options.length;i++) {
		var o=this.left.options[i];
		newLeft[o.value]=1;
		if (typeof(this.originalLeftValues[o.value])=="undefined") {
			addedLeft[o.value]=1;
			removedRight[o.value]=1;
			}
		}
	for (var i=0;i<this.right.options.length;i++) {
		var o=this.right.options[i];
		newRight[o.value]=1;
		if (typeof(this.originalRightValues[o.value])=="undefined") {
			addedRight[o.value]=1;
			removedLeft[o.value]=1;
			}
		}
	if (this.removedLeftField!=null) { this.removedLeftField.value = OT_join(removedLeft,this.delimiter); }
	if (this.removedRightField!=null) { this.removedRightField.value = OT_join(removedRight,this.delimiter); }
	if (this.addedLeftField!=null) { this.addedLeftField.value = OT_join(addedLeft,this.delimiter); }
	if (this.addedRightField!=null) { this.addedRightField.value = OT_join(addedRight,this.delimiter); }
	if (this.newLeftField!=null) { this.newLeftField.value = OT_join(newLeft,this.delimiter); }
	if (this.newRightField!=null) { this.newRightField.value = OT_join(newRight,this.delimiter); }
	}
function OT_join(o,delimiter) {
	var val; var str="";
	for(val in o){
		if (str.length>0) { str=str+delimiter; }
		str=str+val;
		}
	return str;
	}
function OT_setDelimiter(val) { this.delimiter=val; }
function OT_setAutoSort(val) { this.autoSort=val; }
function OT_setStaticOptionRegex(val) { this.staticOptionRegex=val; }
function OT_setTransferLeft(val) { this.transferLeftButton=val; }
function OT_setTransferRight(val) { this.transferRightButton=val; }
function OT_init(theform) {
	this.form = theform;
	if(!theform[this.left]){alert("OptionTransfer init(): Left select list does not exist in form!");return false;}
	if(!theform[this.right]){alert("OptionTransfer init(): Right select list does not exist in form!");return false;}
	this.left=theform[this.left];
	this.right=theform[this.right];
	for(var i=0;i<this.left.options.length;i++) {
		this.originalLeftValues[this.left.options[i].value]=1;
		}
	for(var i=0;i<this.right.options.length;i++) {
		this.originalRightValues[this.right.options[i].value]=1;
		}
	if(this.removedLeftField!=null) { this.removedLeftField=theform[this.removedLeftField]; }
	if(this.removedRightField!=null) { this.removedRightField=theform[this.removedRightField]; }
	if(this.addedLeftField!=null) { this.addedLeftField=theform[this.addedLeftField]; }
	if(this.addedRightField!=null) { this.addedRightField=theform[this.addedRightField]; }
	if(this.newLeftField!=null) { this.newLeftField=theform[this.newLeftField]; }
	if(this.newRightField!=null) { this.newRightField=theform[this.newRightField]; }
	var obj = this;
	if(this.transferLeftButton!=null) {
	  addEvent(theform[this.transferLeftButton], 'click', function(){obj.transferLeft()}) }
	if(this.transferRightButton!=null) {
	  addEvent(theform[this.transferRightButton], 'click', function(){obj.transferRight()}) }
	addEvent(this.right, 'dblclick', function(){obj.transferLeft()});
	addEvent(this.left, 'dblclick', function(){obj.transferRight()});
        addEvent(theform, 'submit', function(){selectAllOptions(obj.right)} );
	this.update();
	}
// -------------------------------------------------------------------
// OptionTransfer()
//  This is the object interface.
// -------------------------------------------------------------------
function OptionTransfer(l,r) {
	this.form = null;
	this.left=l;
	this.right=r;
	this.autoSort=true;
	this.delimiter=",";
	this.staticOptionRegex = "";
	this.originalLeftValues = new Object();
	this.originalRightValues = new Object();
	this.removedLeftField = null;
	this.removedRightField = null;
	this.addedLeftField = null;
	this.addedRightField = null;
	this.newLeftField = null;
	this.newRightField = null;
	this.transferLeft=OT_transferLeft;
	this.transferRight=OT_transferRight;
	this.transferAllLeft=OT_transferAllLeft;
	this.transferAllRight=OT_transferAllRight;
	this.saveRemovedLeftOptions=OT_saveRemovedLeftOptions;
	this.saveRemovedRightOptions=OT_saveRemovedRightOptions;
	this.saveAddedLeftOptions=OT_saveAddedLeftOptions;
	this.saveAddedRightOptions=OT_saveAddedRightOptions;
	this.saveNewLeftOptions=OT_saveNewLeftOptions;
	this.saveNewRightOptions=OT_saveNewRightOptions;
	this.setDelimiter=OT_setDelimiter;
	this.setAutoSort=OT_setAutoSort;
	this.setStaticOptionRegex=OT_setStaticOptionRegex;
	this.init=OT_init;
	this.update=OT_update;
	this.setTransferLeft=OT_setTransferLeft;
	this.setTransferRight=OT_setTransferRight;
	}
END
}

=head1 SEE ALSO

L<HTML::Widget::JSAN>, L<HTML::Widget>, L<JSAN>, L<JSAN::ServerSide>

L<http://www.openjsan.org>

=head1 AUTHOR

Jonas Alves, C<jonas.alves at gmail.com>

=head1 LICENSE

Copyright 2006, Jonas Alves.  All rights reserved.  

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself (L<perlgpl>, L<perlartistic>).

=cut

1;

