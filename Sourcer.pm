### //////////////////////////////////////////////////////////////////////////
#
#	TOP
#

=head1 NAME

DynaPage::Sourcer - DynPage text sources parser

 #------------------------------------------------------
 # (C) Daniel Peder & Infoset s.r.o., all rights reserved
 # http://www.infoset.com, Daniel.Peder@infoset.com
 #------------------------------------------------------

=cut

###													###
###	size of <TAB> in this document is 4 characters	###
###													###

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: package
#

    package DynaPage::Sourcer;


### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: version
#

	use vars qw( $VERSION $VERSION_LABEL $REVISION $REVISION_DATETIME $REVISION_LABEL $PROG_LABEL );

	$VERSION           = '0.90';
	
	$REVISION          = (qw$Revision: 1.4 $)[1];
	$REVISION_DATETIME = join(' ',(qw$Date: 2005/01/13 21:30:49 $)[1,2]);
	$REVISION_LABEL    = '$Id: Sourcer.pm,v 1.4 2005/01/13 21:30:49 root Exp root $';
	$VERSION_LABEL     = "$VERSION (rev. $REVISION $REVISION_DATETIME)";
	$PROG_LABEL        = __PACKAGE__." - ver. $VERSION_LABEL";

=pod

 $Revision: 1.4 $
 $Date: 2005/01/13 21:30:49 $

=cut


### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: debug
#

#	use vars qw( $DEBUG ); $DEBUG=0;
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: constants
#

	# use constant	name		=> 'value';
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: modules use
#

	require 5.005_62;

	use strict                  ;
	use warnings                ;
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: class properties
#

#	our	$config	= 
#	{
#	};
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: methods
#

=head1 METHODS

=over 4

=cut



### ##########################################################################

=item	new ( [ @data ] ) : blessed-hashref

For B<@data> see B<Parse> method.

=cut

### --------------------------------------------------------------------------
sub		new
### --------------------------------------------------------------------------
{
	my( $proto, @data ) = @_;
	
	my	$self  = {
            '~JOINSTRING'       => '',
        };
		bless( $self, (ref( $proto ) || $proto ));
		$self->Parse( @data ) if @data;
	
	$self
}

### ##########################################################################

=item	Parse ( data ) : true

Parse source data. B<data> could be either
scalar string, scalar ref, hash-ref, array-ref or array.
In case of hash-ref, array-ref or array each B<value>
is recursively crawled to find and parse parseable data.

=cut

### --------------------------------------------------------------------------
sub		Parse
### --------------------------------------------------------------------------
{
	my( $self, @data ) = @_;
	
	$self->ClearStats() unless $self->{flg_parsing}++;
    
	for my $source ( @data )
	{
		if( !ref($source) )
		{
			$self->parse_ref( \$source )
		}
		elsif( ref($source) eq 'SCALAR' )
		{
			$self->parse_ref( $source )
		}
		elsif( ref($source) eq 'HASH' )
		{
			for my $val ( values %$source )
			{ $self->Parse($val) }
		}
		elsif( ref($source) eq 'ARRAY' )
		{
			for my $val ( @$source )
			{ $self->Parse($val) }
		}
	}
	
	$self->{flg_parsing}--;
	
	1
}
    
### ##########################################################################

=item	parse_ref ( $source_stringref ) : true

The main source data parser.

There are two main format types of text sources:

 - single line
 
   value-name =- shrink line-inner tabs/spaces, drop line-outer whitespaces
   value-name =~ line whitespaces are preserved
 
 - multi line

   # UnIndent
   value-name ==
      shrink block-inner tabs/spaces
      drop block-outer newlines/linefeeds
      drop line-aouter spaces/tabs
   == value-name

   # SingleLiner
   value-name ==-
      shrink block-inner whitespaces
      drop block-outer whitespaces
   -== value-name

   # Preserver
   value-name ==~ 
      drop block up-to/behind first newline[?linefeed]
      preserve all whitespaces
   ~== value-name

=cut

### --------------------------------------------------------------------------
sub		parse_ref
### --------------------------------------------------------------------------
{
	my( $self, $source ) = @_;
	
    my	$contentRegex	= 
	qr{(?:^|[\r\n]+)\s*([!]?)([\w\.\-\:]+)\s*=(?:(?:([-~])(.*?)(?=[\r\n]|$))|(?:=([\-\~]?)(.*?)\5==\s*\1\2))}xs;

    while( $$source =~ m{$contentRegex}cgos )
    {
	   	my	( $sign, $name, $modifier, $content );
	   	
   		( $sign, $name ) = ( $1, $2 );
		if( $content = $4 )
		{
			$modifier	= $3;
			if( !$modifier or ($modifier eq '-') )
			{
				$content =~ s{\s+}{ }gos;		# shrink multiple whitespaces
				$content =~ s{^\s+|\s+$}{}gos;	# drop lead/trail whitespace
			}
		}
		else
		{
			$content	= $6;
			$modifier	= $5;
			if( !$modifier )			# minimize whitespaces, keep inner CR/LF's
			{
				$content =~ s{^\s*\n|\r?\n\s+$}{}os;	# drop lead/trail  CR/LF
				$content =~ s{[ \t]+}{ }gos;	# shrink multiple whitespaces
				$content =~ s{^[ \t]+|[ \t]+$}{}gom;	# drop line lead/trail whitespace
			}
			elsif( $modifier eq '-' )	# multi to single line, total minimize whitespaces
			{
				$content =~ s{\s+}{ }gos;		# shrink multiple whitespaces
				$content =~ s{^\s+|\s+$}{}gos;	# drop lead/trail whitespace
			}
			elsif( $modifier eq '~' )	# keep whitespaces but first/last CR/LF
			{
				$content =~ s{^[ \t]*(\r\n|\r|\n)}{}os;	# drop lead tabs/spaces up to CR/LF including
				$content =~ s{(\r\n|\r|\n)[ \t]*$}{}os;	# drop trail CR/LF and followng tabs/spaces
			}
		}
		$self->Add( $sign.$name, $content );
	}

	return 1;
}

### ##########################################################################

=item	Set ( $name, $content, $indexref ) : true

Set the named content.

=cut

### --------------------------------------------------------------------------
sub		Set
### --------------------------------------------------------------------------
{
	my( $self, $name, $content, $indexref) = @_;
	
	$indexref ||= 0;
    $self->UpdateStats($name);
    $self->{'~'}{$name}{'~'}[$indexref] = $content;
    
    return 1;
}


### ##########################################################################

=item	Add ( $name, $content ) : numeric

Add the named content. Multiple occurences of same
name are pushed.

Returns number of values.

=cut

### --------------------------------------------------------------------------
sub		Add
### --------------------------------------------------------------------------
{
	my( $self, $name, $content) = @_;
	
    $self->UpdateStats($name);
	return push( @{ $self->{'~'}{$name}{'~'} }, $content );
}


### ##########################################################################

=item	Get ( [$name, [$indexref], [$joinstring]] ) : string|array|hashref

Get named content. 

Without arguments returns $self->Content().

B<$indexref> must be either numeric or arrayref, if specified. 

B<numeric> gets single value at specified array index. 

B<arrayref> gets joined values at specified array indexes. 

Negative $indexref works same way as with perl arrays, eg index from the end of 
array.

Unless B<$indexref> is specified, all joined values for the B<$name> are 
returned. 

For separating joined values, the B<$joinstring>, $self->{'~JOINSTRING'} or '' 
will be used is this order.

=cut

### --------------------------------------------------------------------------
sub		Get
### --------------------------------------------------------------------------
{
	my( $self, $name, $indexref, $joinstring ) = @_;
	
	return $self->Content() unless defined $name;
	return undef unless exists $self->{'~'}{$name}{'~'};
	$joinstring ||= $self->{'~JOINSTRING'};
	my @values;
	if(		!defined($indexref) )
	{
		@values = @{ $self->{'~'}{$name}{'~'} };
	}
	elsif(	ref($indexref) eq 'ARRAY')
	{
		@values = @{ $self->{'~'}{$name}{'~'}[@$indexref] };
	}
	elsif(	$indexref =~ /^[-]?[0-9]+$/ ) # is-integer-numeric
	{
		@values = ( $self->{'~'}{$name}{'~'}[$indexref] );
	}
	
	my $dirty = 0;
	for(my $i=0; $i<=$#values; $i++ )
	{
		unless( defined $values[$i] )
		{
			$values[$i] = '' ;
			$dirty++;
		}
	}
	warn "[$name] contained [$dirty] undef content value(s)." if $dirty;

	return @values if wantarray;
	return join( $joinstring, @values );
	
}


### ##########################################################################

=item	Content (  ) : hashref

Get the whole content hashref.

=cut

### --------------------------------------------------------------------------
sub		Content
### --------------------------------------------------------------------------
{
	my( $self ) = @_;
	
    return $self->{'~'};
}


### ##########################################################################

=item	Names (  ) : array | arrayref

Get list of content names.

=cut

### --------------------------------------------------------------------------
sub		Names
### --------------------------------------------------------------------------
{
	my( $self ) = @_;
	my @names = keys %{ $self->Content() };
	
    return @names if wantarray;
    return \@names;
}


### ##########################################################################

=item	NewNames (  ) : array | arrayref

Get list of names added during last parsing - see also UpdateStats().

=cut

### --------------------------------------------------------------------------
sub		NewNames
### --------------------------------------------------------------------------
{
	my( $self ) = @_;
    my @list	= keys %{ $self->{'~NEW_KEY'} };
    
    #return  @list if wantarray;
    #return  \@list;
    
    return @list;
}


### ##########################################################################

=item	NewValues ( [ $name ] ) : array | number

Get list of names with new values added during last parsing.
Specifying B<$name> will return number of new 
values added - see also UpdateStats().

=cut

### --------------------------------------------------------------------------
sub		NewValues
### --------------------------------------------------------------------------
{
	my( $self, $name ) = @_;
	
    my  @list = ();
	if( defined $name )
	{
		if( exists($self->{'~NEW_VAL'}{$name}))
		{
            return $self->{'~NEW_VAL'}{$name};
        }
        else
        {
            return undef;
        }
	}
	else
	{
	    return keys %{ $self->{'~NEW_VAL'} };
	}
}


### ##########################################################################

=item	ClearStats ( data ) : true

Clear parsing statistics by deleting ~NEW_KEY and ~NEW_VAL -
see also UpdateStats().

=cut

### --------------------------------------------------------------------------
sub		ClearStats
### --------------------------------------------------------------------------
{
	my( $self, @data ) = @_;

	delete $self->{'~NEW_KEY'};
	delete $self->{'~NEW_VAL'};
	
	return 1;
}
    
###### ##########################################################################
   
=item	UpdateStats ( $name ) : true

Update parsing statistics for given $name :

~NEW_KEY is assigned to 1 if it is first time of B<< Set($name) >>.
~NEW_VAL is allways incremented by 1

B<< $self->{'~NEW_KEY'} >>  and B<< $self->{'~NEW_VAL'} >>
are intended for internal use only.

=cut

### --------------------------------------------------------------------------
sub		UpdateStats
### --------------------------------------------------------------------------
{
	my( $self, $name ) = @_;

    $self->{'~NEW_KEY'}{$name} = 1 
         unless( $self->{'~NEW_VAL'}{$name}++ );

	return 1;
} 
   


=back

=cut


1;

__DATA__

__END__

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: TODO
#


=head1 TODO	


=cut
