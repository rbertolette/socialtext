# @COPYRIGHT@
package Socialtext::Pageset;
use strict;
use warnings;

use base 'Data::Pageset';

use Class::Field qw( const field );
use constant PAGE_SIZE => 10;
use constant MAX_PAGE_SIZE => 100;

sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;
    my $offset =
        $self->{offset} ||
        $self->{cgi}->{offset} ||
        0;
    ($offset) = ($offset =~ /^(\d+)$/);
    $offset ||= 0;
    $self->{offset} = $offset;

    my $limit =
        $self->{limit} ||
        $self->{cgi}->{limit} ||
        10;
    ($limit) = ($limit =~ /^(\d+)$/);
    $limit ||= PAGE_SIZE;
    if ($limit > MAX_PAGE_SIZE) {
        $limit = MAX_PAGE_SIZE;
    }
    $self->{limit} = $limit;

    my $total_entries = $self->{total_entries}
        or die "Pageset needs total_entries";

    my $pages_per_set =
        $self->{pages_per_set} || 5;

    $self->{pager} = Data::Pageset->new({
        total_entries    => $total_entries,
        current_page     => int($offset / $limit) + 1,
        entries_per_page => $limit,
        pages_per_set    => $pages_per_set,
        mode             => 'slide',
    });
    
    return $self;
}

sub template_vars {
    my $self = shift;

    my $offset = $self->{offset};
    my $limit = $self->{limit};
    my $total_entries = $self->{total_entries};

    my $previous_page_offset = $offset - $limit;
    $previous_page_offset = 0
        if $previous_page_offset < 0;
    my $next_page_offset = $offset + $limit;
    $next_page_offset = ($total_entries - $limit - 1)
        if $next_page_offset >= $total_entries;
    my $last_page_offset = int(($total_entries - 1) / $limit) * $limit;
    my $last = $offset + $limit;
    $last = $total_entries
        if $last > $total_entries;

    return (
        pager => $self->{pager},
        offset => $offset,
        last =>  $last,
        last_page_offset => $last_page_offset,
        previous_page_offset => $previous_page_offset,
        next_page_offset => $next_page_offset,
    );
}

1;
