#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 8;
use Socialtext::UserSettingsPlugin;

delimiters '===', '>>>';
run {
    my $case = shift;
    my @got = Socialtext::UserSettingsPlugin->_parse_email_address($case->mail);
    my $expected = YAML::Load($case->expected);
    is YAML::Dump(\@got), YAML::Dump($expected), $case->mail;
};

{
    my $input = <<'EOT';
rking@panoptic.com,
<rking@sharpsaw.org>,rking-afraidofspam@sharpsaw.org,
"Ze Burro" <burro@panoptic.com>, Devin Nullington <devnull9@socialtext.com>
mailto:devnull2@socialtext.com
EOT
    my @actual = Socialtext::UserSettingsPlugin->_split_email_addresses($input);

    my @expected = ( 'rking@panoptic.com',
                     '<rking@sharpsaw.org>',
                     'rking-afraidofspam@sharpsaw.org',
                     q|"Ze Burro" <burro@panoptic.com>|,
                     'Devin Nullington <devnull9@socialtext.com>',
                     'mailto:devnull2@socialtext.com',
                   );
    is_deeply( \@actual, \@expected, 'split_emails_from_blob_of_text' );
}
__DATA__
===
>>> mail: rking@panoptic.com
>>> expected
- rking@panoptic.com
- rking
- ~

===
>>> mail: "Ryan King" <rking@panoptic.com>
>>> expected
- rking@panoptic.com
- Ryan
- King

===
>>> mail: Ryan King <rking@panoptic.com>
>>> expected
- rking@panoptic.com
- Ryan
- King

===
>>> mail: mailto:rking@panoptic.com
>>> expected
- rking@panoptic.com
- rking
- ~

===
>>> mail: <rking@panoptic.com>
>>> expected
- rking@panoptic.com
- rking
- ~

=== (Blank line)
>>> mail:
>>> expected
--- []

=== (Nulls)
>>> mail: rking @pan ptic.com
>>> expected
--- []
