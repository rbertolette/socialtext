package Socialtext::Page::TablePopulator;
# @COPYRIGHT@
use strict;
use warnings;
use Email::Valid;
use Socialtext::Workspace;
use Socialtext::Paths;
use Socialtext::Page;
use Socialtext::Hub;
use Socialtext::User;
use Socialtext::AppConfig;
use Fatal qw/opendir closedir chdir open/;
use Socialtext::SQL qw/sql_execute sql_begin_work sql_commit get_dbh 
                       sql_rollback/;

sub new {
    my $class = shift;
    my %opts  = @_;
    die "workspace is mandatory!" unless $opts{workspace_name};

    my $self = \%opts;
    bless $self, $class;
    $self->{workspace}
        = Socialtext::Workspace->new( name => $opts{workspace_name} );
    die "No such workspace $opts{workspace_name}\n"
        unless $self->{workspace_name};

    return $self;
}

sub populate {
    my $self = shift;
    my $workspace = $self->{workspace};
    my $workspace_name = $self->{workspace_name};

    # Start a transaction, and delete everything for this workspace
    sql_begin_work();
    eval {
        sql_execute(
            'DELETE FROM page WHERE workspace_id = ?',
            $workspace->workspace_id,
        );

        my $workspace_dir
            = Socialtext::Paths::page_data_directory($workspace_name);
        my $hub = $self->{hub}
            = Socialtext::Hub->new( current_workspace => $workspace );
        chdir $workspace_dir;
        opendir(my $dfh, $workspace_dir);
        my @pages;
        my @page_tags;
        while (my $dir = readdir($dfh)) {
            next unless -d $dir;
            next if $dir =~ m/^\./;

            eval {
                my $page = $self->read_metadata($dir);
                my $workspace_id = $workspace->workspace_id;

                my $last_editor = editor_to_id($page->{last_editor});
                my $first_editor = editor_to_id($page->{creator_name});

                push @pages, [
                    $workspace_id,        $page->{page_id}, $page->{name},
                    $last_editor,         $page->{last_edit_time},
                    $first_editor,        $page->{create_time},
                    $page->{revision_id}, $page->{revision_count},
                    $page->{revision_num},
                    $page->{type}, $page->{deleted}, $page->{summary},
                ];

                for my $t (@{ $page->{tags} }) {
                    push @page_tags, [ $workspace_id, $page->{page_id}, $t ];
                }
            };
            warn "Error populating $workspace_name: $@" if $@;
        }
        closedir($dfh);

        # Now add all those pages and tags to the database
        add_to_db('page', \@pages);
        add_to_db('page_tag', \@page_tags);
    };
    if ($@) {
        warn "Error during populate of $workspace_name: $@";
        sql_rollback();
    }
    else {
        sql_commit();
    }
}

sub read_metadata {
    my $self     = shift;
    my $page_dir = shift;

    # Note: This could _could_ just use Socialtext::Page objects to read and
    # parse the page, but choose not to for about a 4x performance gain.
    my $page_file = "$page_dir/index.txt";
    my $pagemeta = fetch_metadata($page_file);

    my $revision_id = readlink($page_file);
    $revision_id =~ s#.+/(.+)\.txt$#$1#;

    my $tags = $pagemeta->{Category} || [];
    $tags = [$tags] unless ref($tags);

    my $subject = $pagemeta->{Subject} || '';
    if (ref($subject)) { # Handle bad duplicate headers
	$subject = shift @$subject;
    }
    my $summary = $pagemeta->{Summary} || '';
    unless ($summary) {
        my $p = Socialtext::Page->new( 
            hub => $self->{hub}, id => $page_dir,
        );
        $summary = $p->preview_text;
        if ($p->can('_store_preview_text')) {
            # Store the preview text back in the file to save work for later
            $p->_store_preview_text($summary);
        }
    }
    if (ref($summary) eq 'ARRAY') {
        # work around a bug where a page has 2 Summary revisions.
        $summary = $summary->[-1];
    }

    my ($num_revisions, $orig_page) = load_original_revision($page_dir);
    # This is special case for any extremely bad data on the system
    $orig_page->{From} ||= $pagemeta->{From};
    $orig_page->{Date} ||= $pagemeta->{Date};

    return {
        page_id => $page_dir,
        name => $subject,
        last_editor => $pagemeta->{From},
        last_edit_time => $pagemeta->{Date},
        revision_id => $revision_id,
        revision_count => $num_revisions,
        revision_num => $pagemeta->{Revision},
        type => $pagemeta->{Type} || 'wiki',
        deleted => ($pagemeta->{Control} || '') eq 'Deleted' ? 1 : 0,
        tags => $tags,
        summary => $summary,
        creator_name => $orig_page->{From},
        create_time => $orig_page->{Date},
    };
}

# This method was copied from Socialtext::Page, to remove a dependency
# should that module change in the future.  
# (One less thing to think about then.)
sub parse_headers {
    my $headers = shift;
    my $metadata = {};
    for (split /\n/, $headers) {
        next unless /^(\w\S*):\s*(.*)$/;
        my ($attribute, $value) = ($1, $2);
        if (defined $metadata->{$attribute}) {
            $metadata->{$attribute} = [$metadata->{$attribute}]
              unless ref $metadata->{$attribute};
            push @{$metadata->{$attribute}}, $value;
        }
        else {
            $metadata->{$attribute} = $value;
        }
    }
    return $metadata;
}

sub add_to_db {
    my $table = shift;
    my $rows = shift;

    unless (@$rows) {
        warn "No rows to add to $table.\n";
        return;
    }

    my $dbh = get_dbh();

    my $vals = join ',', map { '?' } @{ $rows->[0] };
    my $sth = $dbh->prepare(<<EOT);
INSERT INTO $table VALUES ($vals);
EOT
    my $row;
    eval {
        for $row (@$rows) {
            $sth->execute(@$row);
        }
    };
    if ($@) {
        die "Error during execute - (INSERT INTO $table) - bindings=("
            . join(', ', @$row) . ') - '
            . $sth->errstr;
    }
}

sub load_original_revision {
    my $page_dir = shift;

    opendir my $dir, $page_dir or die "Couldn't open $page_dir";
    my @ids = grep defined, map { /(\d+)\.txt$/; $1; } readdir $dir;
    closedir $dir;

    @ids = sort @ids;
    my $orig_rev = shift @ids;

    my $file = "$page_dir/$orig_rev.txt";
    die "$file does not exist!" unless -e $file;
    my $orig_metadata = fetch_metadata($file);
    return (scalar(@ids), $orig_metadata);
}

sub fetch_metadata {
    my $file = shift;

    my $content = '';
    open(my $fh, $file);
    while(my $line = <$fh>) {
        last if $line eq "\n";
        $content .= $line;
    }

    return parse_headers($content);
}

{
    my %userid_cache;

    # This code inspired by Socialtext::Page::last_edited_by
    sub editor_to_id {
        my $email_address = shift || '';
        unless ( $userid_cache{ $email_address } ) {
            # We have some very bogus data on our system, so this is a really
            # horrible hack to fix it.
            unless ( Email::Valid->address($email_address) ) {
                my ($name) = $email_address =~ /([\w-]+)/;
                $name = 'unknown' unless defined $name;
                $email_address = $name . '@example.com';
            }

            # Load or create a new user with the given email.
            # Email addresses are always written to disk, even for ldap users.
            my $user = Socialtext::User->new(email_address => $email_address);
            unless ($user) {
                warn "Creating user account for '$email_address'\n";
                $user = Socialtext::User->create(
                    email_address => $email_address,
                    username      => $email_address,
                );
                $user ||= Socialtext::User->SystemUser();
            }

            $userid_cache{ $email_address } = $user->user_id;
        }
        return $userid_cache{ $email_address };
    }
}

1;
