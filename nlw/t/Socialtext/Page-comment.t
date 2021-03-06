#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Carp;

use Test::Socialtext tests => 1;
fixtures( 'admin' );
use Socialtext::l10n qw(loc loc_lang);

use Readonly;

Readonly my $COMMENT => 'You call that a blog post?!';

my $share_dir = Socialtext::AppConfig->new->code_base();
my $l10n_dir = "$share_dir/l10n";

my $hub = new_hub('admin');
my $prefs = $hub->preferences_object;
$prefs->locale->value('en');
loc_lang('en');

my $page = $hub->pages->new_from_name("Admin wiki");

my $original_body = $page->content;

$page->add_comment( $COMMENT );

like(
    $page->content,
    qr/ \A \Q$original_body\E \s* \n
        --+ \s* \n
        \Q$COMMENT\E \s* \n
        _contributed \s+ by \s+ \{user:\s*devnull1\@socialtext\.com\} \s+
        on \s+ \{date:[^}]+\}_
        \s* \z
    /xsm,
    'Commented page looks correct.'
);
