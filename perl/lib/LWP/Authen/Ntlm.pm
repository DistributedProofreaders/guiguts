package LWP::Authen::Ntlm;

use strict;
use vars qw/$VERSION/;

$VERSION = '0.05';

use Authen::NTLM "1.02";
use MIME::Base64 "2.12";

sub authenticate {
	LWP::Debug::debug("authenticate() has been called");
    my($class, $ua, $proxy, $auth_param, $response,
       $request, $arg, $size) = @_;

    my($user, $pass) = $ua->get_basic_credentials($auth_param->{realm},
                                                  $request->url, $proxy);

    unless(defined $user and defined $pass) {
		LWP::Debug::debug("No username and password available from get_basic_credentials().  Returning unmodified response object");
		return $response;
	}

	if (!$ua->conn_cache()) {
		LWP::Debug::debug("Keep alive not enabled, emitting a warning");
		warn "The keep_alive option must be enabled for NTLM authentication to work.  NTLM authentication aborted.\n";
		return $response;
	}

	my($domain, $username) = split(/\\/, $user);

	ntlm_domain($domain);
	ntlm_user($username);
	ntlm_password($pass);

    my $auth_header = $proxy ? "Proxy-Authorization" : "Authorization";

	# my ($challenge) = $response->header('WWW-Authenticate'); 
	my $challenge;
	foreach ($response->header('WWW-Authenticate')) { 
		last if /^NTLM/ && ($challenge=$_);
	}

	if ($challenge eq 'NTLM') {
		# First phase, send handshake
		LWP::Debug::debug("In first phase of NTLM authentication");
	    my $auth_value = "NTLM " . ntlm();
		ntlm_reset();

	    # Need to check this isn't a repeated fail!
	    my $r = $response;
		my $retry_count = 0;
	    while ($r) {
			my $auth = $r->request->header($auth_header);
			++$retry_count if ($auth && $auth eq $auth_value);
			if ($retry_count > 2) {
				    # here we know this failed before
				    $response->header("Client-Warning" =>
						      "Credentials for '$user' failed before");
				    return $response;
			}
			$r = $r->previous;
	    }

	    my $referral = $request->clone;
	    $referral->header($auth_header => $auth_value);
		LWP::Debug::debug("Returning response object with auth header:\n$auth_header $auth_value");
	    return $ua->request($referral, $arg, $size, $response);
	}
	
	else {
		# Second phase, use the response challenge (unless non-401 code
		#  was returned, in which case, we just send back the response
		#  object, as is
		LWP::Debug::debug("In second phase of NTLM authentication");
		my $auth_value;
		if ($response->code ne '401') {
			LWP::Debug::debug("Response from server was not 401 Unauthorized, returning response object without auth headers");
			return $response;
		}
		else {
			my $challenge;
			foreach ($response->header('WWW-Authenticate')) { 
				last if /^NTLM/ && ($challenge=$_);
			}
			$challenge =~ s/^NTLM //;
			ntlm();
			$auth_value = "NTLM " . ntlm($challenge);
			ntlm_reset();
		}

	    my $referral = $request->clone;
	    $referral->header($auth_header => $auth_value);
		LWP::Debug::debug("Returning response object with auth header:\n$auth_header $auth_value");
	    my $response2 = $ua->request($referral, $arg, $size, $response);
		return $response2;
	}
}

1;


