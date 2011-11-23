package DNS::PunyDNS

use 5.006;
use strict;
use warnings;
use LWP::UserAgent;
use XML::Simple;
use Readonly;

=head1 NAME

DNS::PunyDNS - Interact with your SAPO dynamic dns entries

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

Readonly::Scalar my $BASE_URL => 'https://services.sapo.pt/PunyUrl/DNS/';

Readonly::Scalar my $LISTDNS     => 'ListDns';
Readonly::Scalar my $LISTDNSINFO => 'ListDnsInfo';
Readonly::Scalar my $GETDNSINFO  => 'GetDnsInformation';
Readonly::Scalar my $ADDDNS      => 'AddDns';
Readonly::Scalar my $REMOVEDNS   => 'RemoveDns';
Readonly::Scalar my $UPDATEDNS   => 'UpdateDns';

=head1 SYNOPSIS

This module allows you to create/remove/update your SAPO dynamic dns entries (L<http://sl.pt>)

	use DNS::PunyDNS;

	my $dns = DNS::PunyDNS->new({'username' => '<sapousername>', password => '<sapopassword>' } );

	my $added = $dns->add_dns( $domain, $ip, $record_type );

	if (!$added) {
		print STDERR $dns->{'error'};
	}
    ...


=head1 METHODS

=head2 new

Creates a new DNS::PunyDNS object


	DNS::PunyDNS->new( { 'username' => '<sapousername>', 'password' => '<sapopassword>' } )

Your SAPO username and password must be provided

=head2 add_dns

Adds a dynamic dns entry

	$dns->add_dns( $domain, $ip, $record_type )

This function returns false if the operation fails , the cause of the failure is set in  $dns->{'error'}

=head2 update_dns

Updates a dynamic dns entry

	$dns->update_dns( $domain, $ip, $record_type , [$old_record_type])

This function returns false if the operation fails , the cause of the failure is set in  $dns->{'error'}

=head2 get_dns_info

Gets dns information of a specific entrry

	my $info = $dns->get_dns_info( $domain );


=head2 list_dns 

Gets all the dynamic dns entry names  associated with your account

	my $list = $dns->list_dns();

=head2 list_dns_info

Gets all the dynamic dns entrys information

 	my $list_info = $dns->list_dns_info(); 

=head2 remove_dns

Removes a dns entry 

	$removed = $dns->remove_dns( $domain, [$record_type] )

This function returns false if the operation fails , the cause of the failure is set in $dns->{'error'}


=cut

sub new {
    my ( $class, @args ) = @_;
    my $self = {};
    bless $self, $class || $class;
    $self->{'username'} = $args[0]->{'username'} || die "No username provided";
    $self->{'password'} = $args[0]->{'password'} || die "No password provided";

    return $self;
}

sub update_dns {
    my ( $self, $domain, $ip, $record_type, $old_record_type ) = @_;
    die "You must provide a domain"      if !$domain;
    die "You must provide an IP address" if !$ip;

    my %args = (
        'domain'      => $domain,
        'ip'          => $ip,
        'record_type' => $record_type,
    );
    $args{'old_record_type'} = $old_record_type if $old_record_type;
    my $response = $self->get_it( $UPDATEDNS, \%args );
    return $response;

}

sub remove_dns {
    my ( $self, $domain, $record_type ) = @_;
    die "You must provide a domain" if !$domain;
    my %args = ( 'domain' => $domain );
    $args{'record_type'} = $record_type if $record_type;
    my $response = $self->get_it( $REMOVEDNS, \%args );
    return 0 if ( $self->{'error'} );
    return 1;
}

sub add_dns {
    my ( $self, $domain, $ip, $record_type ) = @_;
    die "You must provide a domain"      if !$domain;
    die "You must provide an IP address" if !$ip;
    die "You must provide a Record Type" if !$record_type;
    my $response = $self->get_it(
        $ADDDNS,
        {
            'domain'      => $domain,
            'ip'          => $ip,
            'record_type' => $record_type
        } );
    return 0 if ( $self->{'error'} );
    return 1;
}

sub get_dns_info {
    my ( $self, $domain ) = @_;
    die "You must provide a domain to check" if ( !$domain );
    my $response = $self->get_it( $GETDNSINFO, { 'domain' => $domain } );
    return if ( $self->{'error'} );
    my @domain_info = ();
    my $info        = $response->{'info'};
    if ( ref($info) eq 'ARRAY' ) {
        for my $dnsinfo ( @{$info} ) {
            my %tmp_info;
            $tmp_info{'domain'} = $response->{'domain'};
            $tmp_info{'ip'}     = $dnsinfo->{'ip'};
            $tmp_info{'type'}   = $dnsinfo->{'type'};
            push @domain_info, \%tmp_info;
        }
    } else {
        my %tmp_info = (
            'domain' => $response->{'domain'},
            'ip'     => $info->{'ip'},
            'type'   => $info->{'type'},
        );
        push @domain_info, \%tmp_info;
    }

    return \@domain_info;
} ## end sub get_dns_info

sub list_dns_info {
    my ($self)   = @_;
    my $response = $self->get_it($LISTDNSINFO);
    my @domains  = ();
    if ( $response->{'domains'}{'domain'} ) {
        if ( ref( $response->{'domains'}{'domain'} ) eq 'ARRAY' ) {
            push @domains, @{ $response->{'domains'}{'domain'} };
        } else {
            push @domains, $response->{'domains'}{'domain'};
        }
    }
    return \@domains;
}

sub list_dns {
    my ($self)   = @_;
    my $response = $self->get_it($LISTDNS);
    my @domains  = ();
    if ( $response->{'domain'} ) {
        if ( ref( $response->{'domains'} ) eq 'ARRAY' ) {
            push @domains, @{ $response->{'domain'} };
        } else {
            push @domains, $response->{'domain'};
        }
    }
    return \@domains;
}

sub build_request {
    my ( $self, $endpoint, $args ) = @_;
    $args->{'ESBUsername'} = $self->{'username'};
    $args->{'ESBPassword'} = $self->{'password'};
    $args->{'lang'}        = 'en';
    my @keys = keys %{$args};

    my $url = $BASE_URL . $endpoint . '?' . join( '&', map { $_ . '=' . $args->{$_} } @keys );

    return $url;
}

sub get_it {
    my ( $self, $endpoint, $args ) = @_;

    my $url = $self->build_request( $endpoint, $args );
    delete $self->{'error'};

    my $ua       = new LWP::UserAgent();
    my $req      = new HTTP::Request( 'GET', $url );
    my $response = $ua->request($req);

    if ( $response->is_success ) {
        my $content = $response->content;
        my $decoded_content = XMLin( \$content, KeyAttr => 'domain' );
        if ( $decoded_content->{'error'} ) {
            $self->{'error'} = $decoded_content->{'error'};
        }
        return $decoded_content;
    } else {
        die "There was a problem with the request\n" . $response->status_line;
    }

} ## end sub get_it

=head1 AUTHOR

Bruno Martins, C<< <bruno-martins at telecom.pt> >>

=head1 NOTES

=head2 Errors

There are several ways that the operations can fail, for example, you can try to add a dns entry that already exists or you can try to update a dns entry that is not under your account, etc. 

Each time an operation is executed and raises an error $dns->{'error'} is set with the error reason,

=head2 SAPO dynamic dns API authentication

SAPO dynamic dns API is only available over https, so your username and password are not sent I<clean>

=head2 Record Types

SAPO dynamic dns API only allows A and AAAA record types


=head1 BUGS

Please report any bugs or feature requests to C<bug-punyurl-dns at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DNS::PunyDNS>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DNS::PunyDNS


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DNS-PunyDNS>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DNS::PunyDNS>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DNS::PunyDNS>

=item * Search CPAN

L<http://search.cpan.org/dist/DNS::PunyDNS/>

=back


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Bruno Martins  C<< <bruno-martins at telecom.pt> >> and SAPO L<http://www.sapo.pt>, all rights reserved.


This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of DNS::PunyDNS