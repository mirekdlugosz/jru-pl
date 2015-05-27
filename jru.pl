#!/usr/bin/perl

# Jabber roster utility --- Web-based
# Derived from JabberTools
#
#    (c) 2002 M.Kiesel (email: maqi@jabberstudio.org)
#        2001 Mike Szczerban (email: mike@aspect.net, jid: mike@jabber.org)
#
#    This script is Free Software.  See the file COPYING included in 
#         this distribution or visit http://www.gnu.org for details.
#

# Require these modules
use CGI;                            # For CGI processes                 
use Net::Jabber qw(Client);         # For Jabber-client-coolness
use vars '$Connection';             # Pseudo-import $Connection

require "jru-common.pl";
do "config.pl";

# Initialize a new CGI object
my $query = new CGI;

# print the HTML headers
print $query->header(-charset=>"UTF-8");

# Initialize and stuff the variables with the passed stuff; nothing if not passed
my $do_getroster = $query->param('do_getroster');
my $do_convert = $query->param('do_convert');
my $do_sendroster = $query->param('do_sendroster');

my $username = $query->param('username');
my $password = $query->param('password');
my $server = $query->param('server');
my $port = $query->param('port');

my $rosterchanges = $query->param('rosterchanges');

my $filename = $query->param('uploaded_file');
my $tmpfilename = $query->tmpFileName($filename);
my $list_type = $query->param('list_type');
my $user_group = $query->param('group');
my $transport_address = $query->param('transport_address');
my $delete_all = $query->param('delete_all');

my $list = ' ';
my @contacts = ();
my @contact_aliases = ();
my $contact_count = 0;
my $contact = ' ';
my $contact_alias = ' ';
my $garbage = ' ';
my $first_run = 1;
my $resource = "JRU";
my $status = ' ';
my @result = ();
my $log = '\n';


# Print out the "top" portion of the web page
&print_file("./jru-top.inc");

# Convert buddy list to roster changes
if( $do_convert )
{
    # store list
    $list = &read_file($tmpfilename, '', $list_type);

    # Print messages for the web interface
    print "\n<br />Processing $list_type list\n";
    $rosterchanges = '';
 
    # AIM list
    if ($list_type eq 'aim')
    {
	# Process aim list
	$rosterchanges = &process_aim_list($list, $transport_address, $user_group);
	print ".\n";
    }

    # GAIM list
    elsif ($list_type eq 'gaim')
    {
	# Process gaim list
	@contacts = &process_gaim_list($list);	
	print ".\n";
	
	foreach $contact (@contacts)
	{	
	    # split at colon, after colon is alias
	    ($contact, $contact_alias) = split /:/, $contact; 
           
	    # Remove spaces from buddy portion
	    $contact =~ s/\s//g;
	    $rosterchanges .= $contact;

	    print ".\n";
	}

    } 

    # mICQ list
    elsif ($list_type eq 'micq')
    {
	$rosterchanges = &process_micq_list($list, $transport_address, $user_group);
	print ".\n";
    }

    # ICQ 2001 list
    elsif ($list_type eq 'icq2001')
    {
	$rosterchanges = &process_icq2001_list($list, $transport_address, $user_group);
	print ".\n";
    }

    # GnomeICU list
    elsif ($list_type eq 'gnomeicu')
    {
	print ".\n";
	# Process GnomeICU list
	@contacts = &process_gnomeicu_list($list);
	print ".\n";
	
	foreach $contact (@contacts)
	{
	    print ".\n";
	    ($contact, $contact_alias) = split /=/, $contact, 2;
	    print ".\n";
	    ($contact_alias, $garbage) = split /,/, $contact_alias, 2;
	    print ".\n";

	    $contact_alias = $contact unless $contact_alias;
	    print ".\n";
	    push @contact_aliases, $contact_alias;
	    print ".\n";
	    $contact_count++;
	}
    }

    # ICQ99b or ICQ2000b
    elsif( $list_type eq "icq2000b" )
    {
	# Process Windows ICQ 2000b or 99b list
	@contacts = &process_icq2000b_list($list, $tmpfilename);
	print ".\n";
	
	foreach $contact (@contacts)
	{
	    print ".\n";
	    ($contact, $contact_alias) = split /\s/, $contact, 2;
	    push @contact_aliases, $contact_alias;
	    print ".\n";
	    $contact_count++;
	}
    }

    # gerry's ICQ
    elsif( $list_type eq "gerry_icq" )
    {
	print ".\n";
	# Process Windows ICQ 2000b or 99b list
	@contacts = &process_gerry_icq_list($list, $tmpfilename);
	print ".\n";
	
	foreach $contact (@contacts)
	{
	    print ".\n";
	    ($contact, $contact_alias) = split /\s/, $contact, 2;
	    if( !$contact_alias || $contact_alias eq " " ) { $contact_alias = $contact; }
	    push @contact_aliases, $contact_alias;
	    print ".\n";
	    $contact_count++;
	}
    }
    $query->param('rosterchanges',$rosterchanges);

    print " OK\n";

    print "<br />Deleting user-uploaded list file on web server...";
    # Unlink (delete) the temporary file
    if ( unlink($tmpfilename) < 1 ) 
    {
	print "\n<br />ERROR: Unable to delete user-uploaded list file.  Do not worry, though, as it will disappear after the next reboot of this machine and it is stored under a randomly-generated filename.<br />\n";
    }
    else { print " OK<br />\n"; }

    print "<hr width=\"75%\" noshade=\"noshade\" />";
}

elsif ( $do_sendroster )
{
    print "Connecting: $username\@$server:$port/$resource\n";

    # initialize the Jabber client object
#    $Connection = new Net::Jabber::Client(debuglevel=>2, debugfile=>"debug", debugtime=>1);
    $Connection = new Net::Jabber::Client;

    print ".\n";
    # try the connection and get the status of it
    $status = $Connection->Connect("hostname" => $server,
				  "port" => $port);
    print ".\n";
    # If something's wrong with the connection
    if (!(defined($status))) 
    {
	print "<br />ERROR:  Jabber server is down or connection was not allowed.\n";
	print "<br />($!)\n";
	
	&print_file("./jru-bottom.inc");
	exit(0);
    }

    print ".\n";

    # Set callbacks for incoming info
    $Connection->SetCallBacks("message" => \&InMessage,
			  "presence" => \&InPresence,
			  "iq" => \&InIQ);

    # Connect!
    $Connection->Connect();
    print ".\n";
    # Try authorization
    @result = $Connection->AuthSend("username" => $username,
				"password" => $password,
				"resource" => $resource);
    print ".\n";
    # If the auth went awry
    if ($result[0] ne "ok") 
    {
	print "<br />ERROR: Authorization failed: $result[0] - $result[1]\n<br />";
	exit(0);
    }
    print ".\n";
    print "<br />Logged in successfully to $server:$port as $username...\n";

    print "<br />Getting your roster...\n";
    $Connection->RosterGet();

    print "<br />Sending presence...\n";
    #XXX TODO $Connection->PresenceSend();

    # Do the roster update!
    while( $first_run && defined($Connection->Process()))
    {
	print "<br />Updating your roster will take around $contact_count seconds or ", substr(($contact_count/60), 0, 4), " minutes.\n";
  
	# Update roster
	$log .= &update_roster( $rosterchanges, "<br />", "hide_updates");

	# Done updating, so stop the loop next time around
	$first_run = 0;
    }

    # Should be all done, so why don't we disconnect?  Sounds like fun to me.. but fun to you?  Could be.  Give it a shot, anyway...
    print "<br />Disconnecting...\n";
    $Connection->Disconnect();

    print "\n<script type=\"text/javascript\">\n<!--\nfunction popUpLog() {\n	newWindow = window.open('', 'newWin', 'toolbar=no,location=no,scrollbars=yes,resizable=yes,width=300,height=300')\n\n   newWindow.document.write(\"<html><head><title>Jabber roster utility Log</title></head><body bgcolor=ffffff text=000000><b><font face=sans-serif><div align=left><br />", $log, "</div></font></b></body></html>\")\n}\n -->\n </script>";
    print "<br /><a href=\"\#\" onmousedown=\"popUpLog(); return true;\">Click here</a> to view a log of all users updated and all errors.\n<br /><br />";

    print "<hr width=\"75%\" noshade=\"noshade\" />";
}

elsif( $do_getroster )
{
    print "Connecting: $username\@$server:$port/$resource\n";

    # initialize the Jabber client object
#    $Connection = new Net::Jabber::Client(debuglevel=>2, debugfile=>"debug", debugtime=>1);
    $Connection = new Net::Jabber::Client;

    print ".\n";
    # try the connection and get the status of it
    $status = $Connection->Connect("hostname" => $server,
				  "port" => $port);
    print ".\n";
    # If something's wrong with the connection
    if (!(defined($status))) 
    {
	print "<br />ERROR:  Jabber server is down or connection was not allowed.\n";
	print "<br />($!)\n";
	
	&print_file("./jru-bottom.inc");
	exit(0);
    }

    print ".\n";

    # Set callbacks for incoming info
    $Connection->SetCallBacks("message" => \&InMessage,
			  "presence" => \&InPresence,
			  "iq" => \&InIQ);

    # Connect!
    $Connection->Connect();
    print ".\n";
    # Try authorization
    @result = $Connection->AuthSend("username" => $username,
				"password" => $password,
				"resource" => $resource);
    print ".\n";
    # If the auth went awry
    if ($result[0] ne "ok") 
    {
	print "<br />ERROR: Authorization failed: $result[0] - $result[1]\n<br />";
	exit(0);
    }
    print ".\n";
    print "<br />Logged in successfully to $server:$port as $username...\n";

    print "<br />Getting your roster...\n";
    %roster = $Connection->RosterGet();

    print "<br />Sending your presence...\n";
    #XXX TODO $Connection->PresenceSend();

    # Parse roster.
    $rosterchanges = '';
    $log = '';
    while( $first_run && defined($Connection->Process()))
    {
	foreach $item (keys(%roster)) {
		$rosterchanges .= "+,$item,$roster{$item}->{name},$roster{$item}->{groups}[0]\n";
		$log .= "$item<br />";
	}
	$query->param('rosterchanges',$rosterchanges);
	$first_run = 0;
    }

    # Should be all done, so why don't we disconnect?  Sounds like fun to me.. but fun to you?  Could be.  Give it a shot, anyway...
    print "<br />Disconnecting...\n";
    $Connection->Disconnect();

    print "\n<script type=\"text/javascript\">\n<!--\nfunction popUpLog() {\n	newWindow = window.open('', 'newWin', 'toolbar=no,location=no,scrollbars=yes,resizable=yes,width=300,height=300')\n\n   newWindow.document.write(\"<html><head><title>Jabber roster utility Log</title></head><body bgcolor=ffffff text=000000><b><font face=sans-serif><div align=left><br />", $log, "</div></font></b></body></html>\")\n}\n -->\n </script>";
    print "<br /><a href=\"\#\" onmousedown=\"popUpLog(); return true;\">Click here</a> to view a log of all users updated and all errors.\n<br /><br />";

    print "<hr width=\"75%\" noshade=\"noshade\" />";
}

# Print the formeroo
&print_form($query);

# Print the bottom portion of the web interface
&print_file("./jru-bottom.inc");


#
#  Callbacks & subs
#


sub is_invalid
{
    my $query = shift;
    my $errors = '';

    $errors .= "<li>Username</li>\n" unless $username;
    $errors .= "<li>Password</li>\n" unless $password;
    $errors .= "<li>Server</li>\n" unless $server;
    $errors .= "<li>Port</li>\n" unless $port;
    $errors .= "<li>Type of buddy list or configuration file</li>\n" unless $list_type;
    $errors .= "<li>Transport Address</li>\n" unless $transport_address;
    $errors .= "<li>Filename to Upload</li\n" unless $filename;

    return $errors;
}



sub print_form
{
    my $query = shift @_;

    print $query->start_multipart_form();

    print "<h3>Server information</h3>";

    print "Username: \n";
    print $query->textfield(-name=>'username',
			    -size=>20,
			    -maxlength=>40), "\n\n<br /><br />";

    print "Password: \n";
    print $query->password_field(-name=>'password',
			   -size=>20,
			   -maxlength=>40), "\n\n<br /><br />";

    print "Server: \n";
    print $query->textfield(-name=>'server',
			   -default=>$default_server,
			   -size=>20,
			   -maxlength=>40), "\n\n";

    print "Port: \n";
    print $query->textfield(-name=>'port',
			   -default=>$default_port,
			   -size=>6,
			   -maxlength=>10), "\n\n<br /><br />";

    print $query->submit(-name=>'do_getroster',
			 -value=>'Get roster from Jabber server');
    print "<br /><i>Click only once - this may take up to several minutes</i>";

    print "<h3>Roster changes</h3>";

    print $query->textarea(-name=>'rosterchanges',
			   -default=>'#+,12345@icq.server.net,Nick,Group',
			   -rows=>10,
			   -columns=>70), "\n\n<br /><br />";

    print $query->submit(-name=>'do_sendroster',
			 -value=>'Send roster changes to Jabber server');
    print "<br /><i>Click only once - this may take up to several minutes</i>";

    print "<h3>Convert buddy list to roster changes</h3>";

    print "Type of buddy list or configuration file (<a href=\"jru-help.html#licq\">Licq help</a>): \n";
    print $query->popup_menu(-name=>'list_type',
#			     -values=>['aim','gaim','gnomeicu','micq','icq2000b','icq2001','gerry_icq'],
			     -values=>['aim','micq','icq2000b','icq2001'],
			     -labels=>{'aim' => 'AOL IM (Windows, Mac, Linux)',
				       'gaim' => 'Gaim (Linux)',
				       'gnomeicu' => 'GnomeICU (Linux)',
				       'micq' => 'mICQ (Linux)',
				       'icq2000b' => 'ICQ2000b or ICQ99b (Windows)',
				       'icq2001' => 'ICQ2001/2002 (Windows)',
				       'gerry_icq' => 'Gerry\'s ICQ (Mac)'},
			     -default=> 'icq2001'), "\n\n<br /><br />";

    print "Transport address: \n";
    print $query->textfield(-name=>'transport_address',
			   -default=>$default_transport,
			   -size=>20,
			   -maxlength=>50), "\n\n<br /><br />";

    print "Contacts go to user group: \n";
    print $query->textfield(-name=>'group',
			   -size=>20,
			   -maxlength=>50), "\n\n<br /><br />";

    print "Contact list or configuration file (<a href=\"jru-help.html#list_types\">help</a>): \n";
    print $query->filefield(-name=>'uploaded_file', 
                            -size=>35,
                            -maxlength=>150), "\n\n<br /><br />\n";
    $filename = $query->param('uploaded_file');
    $tmpfilename = $query->tmpFileName($filename);

    print $query->submit(-name=>'do_convert',
			 -value=>'Convert file');

    print $query->end_form();
}


sub InMessage
{
    my $sid = shift;
    my $message = shift;
    my $type = $message->GetType();
    my $from = $message->GetFrom("jid")->GetJID();
    my $body = $message->GetBody();
    print "<h3>Message from $from: $body</h3>\n";
}



sub InIQ
{
    my $sid = shift;
    my $IQ = shift;

    my $from = $IQ->GetFrom("jid")->GetJID();
    my $xmlns = $IQ->GetQuery()->GetXMLNS();

    print "<br /><b>IQ from $from ($xmlns)</b>";
}


sub InPresence
{
    my $sid = shift;
    my $presence = new Net::Jabber::Presence(@_);
    my $from = $presence->GetFrom();
    my $type = $presence->GetType();
    my $status = $presence->GetStatus();
}
