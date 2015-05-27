#!/usr/bin/perl

# Jabber roster utility Common Subroutines
#
#    This contains many oft-used subs for Jabber roster utility programs
#
#    (c) 2001 Mike Szczerban <m@szczerbania.org>
#        2002 M.Kiesel <maqi@exmail.de>
#
#    This script is Free Software.  See the file COPYING included in 
#         this distribution or visit http://www.gnu.org for details.
#



#---------------------------------------------------------------#
#  read_file($filename, $cwd)                                   #
#                                                               #
#    reads the file entered by param; returns file's contents   #
#---------------------------------------------------------------#

sub read_file
{
    my $filename = shift;   
    my $cwd = shift;
    my $list_type = shift;
    my $list = '';

    # Create a complete (starting at the root structure) filename
    $filename = $cwd . '/' . $filename unless (substr($filename, 0, 1) eq '/' || substr($filename, 0, 1) eq '~');


    print "Opening file $filename for reading... \n";
	
    # Open the specified filehandle
    (open (LIST, "$filename") && print "OK\n") or die "\tFAILED: Could not open $filename ($!)\n";

    # In case the system is a windows box
    binmode LIST if ($list_type eq "icq2000b" || $list_type eq "icq99b" || $list_type eq "icq2000" || $list_type eq "icq98" || $list_type eq "sametime" );

    # Copy the file's contents in order to return it
    while( <LIST> )
    {
	$list .= $_;
    }

    # All done with the file, close the sucka
    close LIST;

    # Return the contents of the contacts file
    return $list;
}



#---------------------------------------------------------------#
#  process_gaim_list($list)                                     #
#                                                               #
#    processes gaim list; returns array of buddies & aliases    #
#---------------------------------------------------------------#

sub process_gaim_list
{
    my $list = shift;
    my $buddy = '';
    my @buddies = ();
    my $garbage = '';
    my $current = 0;
    my $num = 0;

    # Remove opening gaim identification(s)
    $list =~ s/m 1//;
    $list =~ s/m 2//;
    $list =~ s/m 3//;
    $list =~ s/m 4//;


    # Remove quotes (there shouldn't be any, but...)
    $list =~ s/"//g;

    # Split file on newlines, put into array
    @buddies = split /\n/, $list;

    # traverse array, marking non-buddy entries NULL
    foreach $buddy (@buddies)
    {
        $buddy_alias = $buddy_aliases[$current];

	if( substr($buddy, 0, 1) ne "b" )
	{
	    $buddy = "NULL";
            $buddy_alias = "NULL";
	}
	else
	{
            # split on b ....
            ($garbage, $buddy) = split /b/, $buddy, 2;
	}
    }

    return @buddies;
}



#---------------------------------------------------------------#
#  process_aim_list($list,$transport,$group)                    #
#                                                               #
#    processes aim list; returns array of buddies               #
#---------------------------------------------------------------#

sub process_aim_list
{
    my $list = shift;
    my $transport = shift;
    my $group = shift;
    my $buddy = '';
    my @buddies = ();
    my $garbage = '';
    
    # Remove spaces
    $list =~ s/ //g;

    # Remove quotes
    $list =~ s/"//g;

    # Get rid of stuff before and after list{} section
    ($garbage, $list) = split /list/, $list, 2;
    ($list, $garbage) = split /}\s\n}\s\n}/, $list, 2;

    # Split on spaces and newlines; enter into array
    @buddies = split /\s/, $list;

    $list = "";
    # Traverse list, marking non-buddies as NULL
    foreach $buddy (@buddies)
    {
        # Set group titles to NULL
        if( $buddy eq ' ' || $buddy eq '' || $buddy eq '{' || $buddy eq '}' || substr ($buddy, -2 ) eq "} "
            || substr( $buddy, -1 ) eq "}" || substr( $buddy, 0, 2 ) eq "{ " || substr( $buddy, 0, 1 ) eq "{"
	    || substr( $buddy, -2 ) eq "{ " || substr( $buddy, -1 ) eq "{" || substr( $buddy, -2 ) eq "{\n" )
        {
            $buddy = "NULL";
        }
        else
        {
            $list .= "+,$buddy\@$transport,$buddy,$group\n";
        }
    }

    return $list;
}



#--------------------------------------------------------------------#
#  process_gnomeicu_list($list)                                      #
#                                                                    #
#    processes gnomeicu list; returns array of contacts and aliases  #
#--------------------------------------------------------------------#

sub process_gnomeicu_list
{
    my $list = shift;
    my $contact = '';
    my $contact_alias = '';
    my @contacts = ();
    my @contact_aliases = ();
    my $contact_count = 0;
    my $garbage = '';
    

    # Remove brackets
    $list =~ s/\[//g;
    $list =~ s/\]//g;
    
    # Remove stuff other than NewContacts area
    ($garbage, $list) = split /NewContacts/, $list;
    
    # get contacts in UIN=alias,gnomeicuvars
    @contacts = split /\n/, $list;

    return @contacts;
}
    



#--------------------------------------------------------------------#
#  process_micq_list($list, $transport, $group)                      #
#--------------------------------------------------------------------#

sub process_micq_list
{
    my $list = shift;
    my $transport = shift;
    my $group = shift;
    my $garbage = '';

    # Remove brackets
    $list =~ s/\[//g;
    $list =~ s/\]//g;
    
    # Remove stuff other than the Contacts area
    ($garbage, $list) = split /Contacts/, $list;
    
    # convert contact format
    $list =~ s/^(~|\*)([0-9]*) (.*)$/+,\2\@$transport,\3,$group/gm;

    return $list;
}

#--------------------------------------------------------------------#
#  process_icq2001_list($list, $transport, $group)                   #
#--------------------------------------------------------------------#

sub process_icq2001_list
{
    my $list = shift;
    my $transport = shift;
    my $group = shift;

    # convert contact format
    $list =~ s/^(.*);(.*);(.*);/+,\2\@$transport,\3,\1/gm;

    return $list;
}


#--------------------------------------------------------------------#
#  Routines for Windows ICQ 99b and 2000b imports                    #
#                                                                    #
#                    thanks, tcharron and licq guys!                 #
#--------------------------------------------------------------------#
sub nextPair()
{
    do
    {
	nextKey();
	return 0 if (eof(FILE));
    }
    while (!$key);
    if ($c eq "k")
    {
	nextChar();
	readString();
    }
    elsif ($c eq "i")
    {
	read(FILE, $buffer, 4);
	$value = unpack("V", $buffer);
	nextChar();
    }
    $values[$field] = $value;
    return 1;
}

sub nextKey()
{
    while (ord($c) != 0) { nextChar(); }
    nextChar();
    my $s = "";
    while (ord($c) != 0)
    {
	$s .= $c;
	nextChar();
    }
    for ($i = 0; $i <= $#fieldNames; $i++)
    {
	if ($fieldNames[$i] eq $s)
	{
	    nextChar();  # type
	    $key = $s;
	    $field = $i;
	    return 1;
	}
    }
    $key = "";
    return 0;
}

sub nextChar()
{
    $c = getc(FILE);
    $pos++;
}

sub readString()
{
    $value="";
    my $len = ord($c);
    nextChar();
    return 0 if $c != 0;
    nextChar();
    return 1 if ($len == 0);
    my $i;
    for ($i = 0; $i < $len-1; $i++)
    {
	return 0 if (ord($c) == 0);
	$value .= $c;
	nextChar();
    }
    return 0 if ($c != 0);
    return 1;
 }


#--------------------------------------------------------------------#
#  process_icq2000b_list($list)                                      #
#                                                                    #
#    processes icq2000b or 99b dat file; returns array of contacts   #
#                                              and aliases           #
#--------------------------------------------------------------------#

sub process_icq2000b_list
{
    my $list = shift;
    my $filename = shift;
    @fieldNames=("UIN","MyDefinedHandle","NickName","FirstName","LastName","PrimaryEmail");
    $key = "";
    $position = 0;
    %uins = ();
    my $contact;
    print "....";

    # Open the dat file
    open(FILE, "<$filename") || die "Could not open file $filename: ($!)'\n";

    binmode FILE;    # For Windows...

    # Examine the dat file and extract the good stuff
    nextChar();
    while (nextPair())
    {
	if ($field == 0)
	{
	    if ($values[0] != $own_uin && ($values[1] || $values[2]))
	    {
		if (!$uins{$values[0]})
		{
		    $uins{$values[0]} = 1;
		    $count++;
		}

		if( $values[1] ) { $contact = "$values[0] $values[1]"; }
		elsif( $values[2] ) { $contact = "$values[0] $values[2]"; }
		elsif( $values[3] && $values[4] ) { $contact = "$values[0] $values[3] $values[4]"; }		
		elsif( $values[3] && !$values[4]) { $contact = "$values[0] $values[3] (ICQ User $values[0])"; }
		elsif( $values[4] && !$values[3]) { $contact = "$values[0] $values[4] (ICQ User $values[0])"; }	
		elsif( $values[5] ) { $contact = "$values[0] $values[5] (ICQ User $values[0])"; }
		else { $contact = "$values[0] ICQ User $values[0]"; }

		push @contacts, $contact;
	    }
	    @values = ();
	}
    }

    # Close the file
    close(FILE);

    return @contacts;
}


#--------------------------------------------------------------------#
#  process_licq_files($licq_user_dir)                                #
#                                                                    #
#    goes through licq data & directories;                           #
#     returns array of contact uin file names                        #
#--------------------------------------------------------------------#

sub process_licq_files
{
    # Import the File::Find module to search in the licq directory
    use File::Find;


    # Vars
    my $licq_user_dir = shift;
    my $contact_file = '';
    my @contact_files = ();
    my $suffix = '';
    my $temp_file = '';


    # Find, traverse, smack, befriend, chase, convert, grind, noogie the licq directory
    find(\&wanted, $licq_user_dir);

    # Sub to tell what to do with found files: check suffix and add 'em to the array
    sub wanted
    {
	$suffix = substr($File::Find::name, -4);
	push @contact_files, $File::Find::name if( lc($suffix) eq ".uin" );
        print "UIN file found: $File::Find::name\n" if( lc($suffix) eq ".uin" );
    }

    # Everybody loves a newline!
    print "\n";
    
    return @contact_files;
}

#--------------------------------------------------------------------#
#  process_sametime_list($list)                                      #
#                                                                    #
#    processes IBM SameTime config files; returns array of contacts  #
#                                                    and aliases     #
#--------------------------------------------------------------------#

sub process_sametime_list
{
    my $list = shift;
    
    my $contact = '';
    my $contact_alias = '';
    my $garbage = '';
    my @contacts = ();
    my $count = 0;

    @contacts = split /\n/, $list;

    # For each contact in the contacts array
    foreach $contact (@contacts)
    {
	($garbage, $contact) = split /\s/, $contact, 2;
	# If it is a group, discard (for now)
	# If it is the version statement, discard
	# TODO: add group support
	if( $garbage eq "G" || $garbage eq "V" )
	{
	    $contact = "NULL";
	}
	
	# It's a user
	elsif( $garbage eq "U" )
	{
	    ($garbage, $contact) = split /\s/, $contact, 2; 

	    ($contact, $contact_alias) = split /,/, $contact, 2;
	    
	    ($contact, $garbage) = split /;/, $contact, 2;

	    # Should be sametimeuser%sametimeserver@sametimetransport.jabberserver
	    # $at_sign_replacement is located in the file sametime_config.pl in this directory.
	    $contact =~ s/\@/$at_sign_replacement/;

	    $contact_alias =~ s/;/ /g;
    
	    $contact .= " $contact_alias";
	}
    }
 
    return @contacts;
}
	    


#--------------------------------------------------------------------#
#  process_sametime_list($list)                                      #
#                                                                    #
#    processes IBM SameTime config files; returns array of contacts  #
#                                                    and aliases     #
#--------------------------------------------------------------------#

sub process_gerry_icq_list
{
    my $list = shift;
    
    my $contact = '';
    my $contact_alias = '';
    my $garbage = '';
    my @contacts = ();
    my $count = 0;
    my @lines = ();

    $list =~ s/\r/\n/g;
    ($garbage, @contacts) = split /NEXT/, $list;

    # For each contact in the contacts array
    foreach $contact (@contacts)
    {
	$contact_alias = '';

	@lines = split /\n/, $contact;

	$contact = $lines[0];
	$contact =~ s/\s//g;
	
	foreach $line (@lines)
	{
	    if( substr($line, 0, 4) eq "NICK" )
	    {
		$contact_alias = $line;
		($garbage, $contact_alias) = split /\s/, $contact_alias, 2;
		last;
	    }
	}

	$contact .= " $contact_alias";
    }
 
    return @contacts;
}
	 


#---------------------------------------------------------------------#
#  update_roster($rosterchanges, $br, $hide_updates)                  #
#                                                                     #
#    updates roster with given values                                 #
#---------------------------------------------------------------------#

sub update_roster
{
    my $rosterchanges = shift;
    my $br = shift;
    my $hide_updates = shift;
    my $log = ' ';
    my $current = 0;
    my $contact_jid = '';
    my $contact_alias = '';
    my $contact_group = '';
    my $finished_count = 0;

    @changes = split(/\n/,$rosterchanges);

    # Go through each contact in the contacts array
    foreach $change (@changes)
    {
	$change =~ s/\r//;
	($action,$contact_jid,$contact_alias,$contact_group) = split(/\,/,$change);

	# If the contact is valid
        if( $action && $contact_jid && $contact_alias && $contact_jid ne "NULL" && $contact_alias ne 'NULL' )
        {
	    # delete the contact specified
	    if( $action eq "-" )
	    {
		# Unsubscribe from the contact's presence and remove it from the roster
		$Connection->Subscription(type=> "unsubscribe", to=> $contact_jid );
		$Connection->RosterRemove(jid=> $contact_jid);		
                
                # Removal successful
	        if ( !$hide_updates )
		{
		    print "User updated: $contact_alias ($contact_jid) $br";
		}
		
		
		else    # Removal Unsuccessful
		{
		    print ". . ";
		    print "  ", $finished_count + 1, " users updated $br \n" if( ($finished_count + 1) % 7 == 0 );
		    $log .= "User updated: $contact_alias ($contact_jid) $br";
		}
		
		# Increment the counter
		$finished_count++;
	    }


	    # TRY to add to the roster and subscribe to presence
	    if( $action eq "+" )
	    {
                $Connection->RosterAdd(jid=> $contact_jid, name=> $contact_alias, group=> ($contact_group));
	        $Connection->Subscription(type=> "subscribe", to=> $contact_jid);
	        {
		    # Subscription successful if this is reached
		    if ( !$hide_updates )
		    {
		        print "User updated: $contact_alias ($contact_jid) $br";
		    }
		    else
		    {
		        print ". . ";
		        print "  ", $finished_count + 1, " users updated $br \n" if( ($finished_count + 1) % 7 == 0 );
		        $log .= "User updated: $contact_alias ($contact_jid) $br";
		    }
		
		    # Increment the counter
		    $finished_count++;
	        }
	        # Something's screwy
#	        else
#	        {
#	            print "$br ERROR: $contact_jid was not added to roster $br \n" if( !$hide_updates );
#		    $log .= "$br ERROR: $contact_jid was not added to roster $br";
#	        }
            }
	
            # Sleep for a second to ensure the right pace for the server
	    sleep 1;
        }
	
	# increment the counter for the aliases array
	$current++;
    }	

    print "\n\n$finished_count users were updated.\n", $br, "Your contact list import is complete.\n$br";

    return $log;
}	



sub print_file
{
    my $filename = shift @_;

    open(FILEHANDLE, $filename) || die "Could not open $filename: $!\n";
    print while( <FILEHANDLE> );
    close FILEHANDLE;
}

# It should only be required, not executed on its own, so we have to return 1.
return 1;					     









