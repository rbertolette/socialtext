# @COPYRIGHT@
package Socialtext::WikiFixture::SocialRest;
use strict;
use warnings;
use base 'Socialtext::WikiFixture';
use Test::HTTP;
use Test::More;
use Socialtext::WikiFixture::Socialtext;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json/;

=head1 NAME

Socialtext::WikiFixture::SocialRest - Test the REST API without using a browser

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

This module is a subclass of Socialtext::WikiFixture and includes
extra commands specific for testing the Socialtext REST API.

=head1 FUNCTIONS

=head2 new( %opts )

Create a new fixture object.  The same options as
Socialtext::WikiFixture are required, as well as:

=over 4

=item server

Mandatory - The server address to test.

=item username

Mandatory - username to login to the wiki with.

=item password

Mandatory - password to login to the wiki with.

=back

=head2 init()

Creates the Test::HTTP object, and logs into the Socialtext
workspace.

=cut

sub init {
    my ($self) = @_;
    for (qw(browser_url username password)) {
        die "$_ is mandatory!" unless $self->{$_};
    }

    $self->SUPER::init;

    $self->http_user_pass($self->{username}, $self->{password});
}

=head2 http_user_pass ( $username, $password )

Set the HTTP username and password.

=cut

sub http_user_pass {
    my $self = shift;
    my $user = shift;
    my $pass = shift;

    my $name = ($self->{http}) ? $self->{http}->name : 'SocialRest fixture';

    $self->{http} = Test::HTTP->new('SocialRest fixture');
    $self->{http}->username($user) if $user;
    $self->{http}->password($pass) if $pass;
    $self->{http}->name($name);
}

=head2 handle_command( @row )

Run the command.  Subclasses can override this.

=cut

sub handle_command {
    my $self = shift;
    my $command = lc(shift);
    $command =~ s/-/_/g;
    $command =~ s/^\*(.+)\*$/$1/;
    my @opts = $self->_munge_options(@_);

    if ($command eq 'body_like') {
        $opts[0] = $self->quote_as_regex($opts[0]);
    }
    elsif ($command =~ m/_like$/) {
        $opts[1] = $self->quote_as_regex($opts[1]);
    }

    if ($self->can($command)) {
        return $self->$command(@opts);
    }
    if ($self->{http}->can($command)) {
        return $self->{http}->$command(@opts);
    }

    # Lets (ab)use some existing test methods
    if ($command eq 'st_admin') {
        return Socialtext::WikiFixture::Socialtext::st_admin($self, @opts);
    }
    elsif ($command eq 'st_config') {
        return Socialtext::WikiFixture::Socialtext::st_config($self, @opts);
    }
    elsif ($command eq 'st_ldap') {
        return Socialtext::WikiFixture::Socialtext::st_ldap($self, @opts);
    }

    die "Unknown command for the fixture: ($command)\n";

}

=head2 comment ( message )

Use the comment as a test comment

=cut

sub comment {
    my $self = shift;
    $self->{http}->name(shift);
}

=head2 get ( uri, accept )

GET a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub get {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_get($uri, [Accept => $accept]);
}

=head2 delete ( uri, accept )

DELETE a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub delete {
        my ($self, $uri, $accept) = @_;
            $accept ||= 'text/html';

                $self->_delete($uri, [Accept => $accept]);
            }
            

=head2 code_is( code [, expected_message])

Check that the return code is correct.

=cut

sub code_is {
    my ($self, $code, $msg) = @_;
    $self->{http}->status_code_is($code);
    if ($self->{http}->response->code != $code) {
        warn "Response message: "
            . ($self->{http}->response->message || 'None')
            . " url(" . $self->{http}->request->url . ")";
    }
    if ($msg) {
        like $self->{http}->response->content(), $self->quote_as_regex($msg),
             "Status content matches";
    }
}

=head2 has_header( header [, expected_value])

Check that the specified header is in the response, with an optional second check for the header's value.

=cut

sub has_header {
    my ($self, $header, $value) = @_;
    my $hval = $self->{http}->response->header($header);
    ok $hval, "header $header is defined";
    if ($value) {
        like $hval, $self->quote_as_regex($value), "header content matches";
    }
}

=head2 post( uri, headers, body )

Post to the specified URI

=cut

sub post { shift->_call_method('post', @_) }

=head2 post_json( uri, body )

Post to the specified URI with header 'Content-Type=application/json'

=cut

sub post_json { 
    my $self = shift;
    my $uri = shift;
    $self->post($uri, 'Content-Type=application/json', @_);
}

=head2 put( uri, headers, body )

Put to the specified URI

=cut

sub put { shift->_call_method('put', @_) }

=head2 set_from_content ( name, regex )

Set a variable from content in the last response.

=cut

sub set_from_content {
    my $self = shift;
    my $name = shift || die "name is mandatory for set-from-content";
    my $regex = $self->quote_as_regex(shift || '');
    my $content = $self->{http}->response->content;
    if ($content =~ $regex) {
        if (defined $1) {
            $self->{$name} = $1;
            warn "# Set $name to '$1' from response content\n";
        }
        else {
            die "Could not set $name - regex didn't capture!";
        }
    }
    else {
        die "Could not set $name - regex ($regex) did not match $content";
    }
}

=head2 st-clear-events

Delete all events

=cut

sub st_clear_events {
    sql_execute('DELETE FROM event');
}


=head2 st-delete-people-tags

Delete all people tags.

=cut

sub st_delete_people_tags {
    sql_execute('DELETE FROM tag_people__person_tags');
    sql_execute('DELETE FROM person_tag');
}

=head2 json-parse

Try to parse the body as JSON, remembering the result for additional tests.

=cut

sub json_parse {
    my $self = shift;
    $self->{json} = undef;
    $self->{json} = eval { decode_json($self->{http}->response->content) };
    ok !$@ && defined $self->{json} && ref($self->{json}) =~ /^ARRAY|HASH$/,
        $self->{http}->name . " parsed content" . ($@ ? " \$\@=$@" : "");
}

=head2 json-array-size

Confirm that the resulting body is a JSON array of length X.

=cut

sub json_array_size {
    my $self = shift;
    my $comparator = shift;
    my $size = shift;

    if (!defined($size) or $size eq '') {
        $size = $comparator;
        $comparator = '==';
    }

    my $json = $self->{json};
    if (not defined $json ) {
        fail $self->{http}->name . " no json result";
    }
    elsif (ref($json) ne 'ARRAY') {
        fail $self->{http}->name . " json result is not an array";
    }
    else {
        cmp_ok scalar(@$json), $comparator, $size, 
            $self->{http}->name . " array is expected size" ;
    }
}


sub body_unlike {
    my ($self, $expected) = @_;
    my $body = $self->{http}->response->content;
    unlike $body, $self->quote_as_regex($expected), 
        $self->{http}->name() . " checking body-unlike";
}

sub _call_method {
    my ($self, $method, $uri, $headers, $body) = @_;
    if ($headers) {
        $headers = [
            map {
                my ($k,$v) = split m/\s*=\s*/, $_;
                $k =~ s/-/_/g;
                ($k,$v);
            } split m/\s*,\s*/, $headers
        ];
    }
    $self->{http}->$method($self->{browser_url} . $uri, $headers, $body);
}

sub _get {
    my ($self, $uri, $opts) = @_;
    $self->{http}->get( $self->{browser_url} . $uri, $opts );
}

sub _delete {      
        my ($self, $uri, $opts) = @_;
            $self->{http}->delete( $self->{browser_url} . $uri, $opts );
}


=head1 AUTHOR

Luke Closs, C<< <luke.closs at socialtext.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-socialtext-editpage at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Socialtext-WikiTest>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Socialtext::WikiFixture::SocialRest

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Socialtext-WikiTest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Socialtext-WikiTest>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Socialtext-WikiTest>

=item * Search CPAN

L<http://search.cpan.org/dist/Socialtext-WikiTest>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008 Luke Closs, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
