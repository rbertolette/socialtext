# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::ChangeEvent::RampupIndexAttachment - specialization of
L<Socialtext::ChangeEvent::Attachment> for updating rampup search indexes.

=head1 SEE

See L<Socialtext::ChangeEvent::Attachment>.

=cut

package Socialtext::ChangeEvent::RampupIndexAttachment;

use base 'Socialtext::ChangeEvent::Attachment';

use Carp 'croak';
use Readonly;

Readonly my $LINK_BASENAME => 'RampupIndexAttachment-';

sub new {
    my ( $class, $path, $link_path ) = @_;

    ( $link_path =~ qr{$LINK_BASENAME} ) or return '';

    $class->SUPER::new($path, $link_path);
}

sub _link_to { shift->SUPER::_link_to(@_, $LINK_BASENAME); }

1;
