package Socialtext::Pluggable::Plugin;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::TT2::Renderer;
use Socialtext::AppConfig;
use Class::Field 'field';
use Socialtext::URI;
use Socialtext::Storage;
use Socialtext::AppConfig;


my $code_base = Socialtext::AppConfig->code_base;

# Class Methods

my %hooks;
my %rests;

field hub => -weak;
field uri => -init => '$self->hub->current_workspace->uri . Socialtext::AppConfig->script_name';

# perldoc Socialtext::URI for arguments
#    path = '' & query => {}

sub make_uri {
  my ($self,%args) = @_;
  return Socialtext::URI::uri(%args);
}

sub code_base {
   return Socialtext::AppConfig->code_base;
}

sub current_workspace {
  my $self = shift;
  return $self->hub->current_workspace->name;
}

sub add_rest {
    my ($self,%rest) = @_;
    my $class = ref($self) || $self;
    push @{$rests{$class}}, \%rest;
}


sub add_hook {
    my ($self,$hook,$method) = @_;
    my $class = ref($self) || $self;
    push @{$hooks{$class}}, {
        method => $method,
        name => $hook,
        class => $class,
    };
}

sub hooks {
    my $self = shift;
    my $class = ref($self) || $self;
    return $hooks{$class} ? @{$hooks{$class}} : ();
}

sub rests {
    my $self = shift;
    my $class = ref($self) || $self;
    return $rests{$class} ? @{$rests{$class}} : ();
}

# Object Methods

sub new { 
    my ($class, %args) = @_;
    # TODO: XXX: DPL, not sure what args are required but because the object
    # is actually instantiated deep inside nlw we can't just use that data
    my $self = {
#        %args,
    };
    bless $self, $class;
    return $self;
}
sub storage {
    my ($self,$id) = @_;
    die "Id is required for storage\n" unless $id;
    return Socialtext::Storage->new($id);
}

sub plugin_dir {
    my $self = shift;
    my $name = $self->name || die "Plugins must define a 'name' subroutine";
    return "$code_base/../plugin/$name";
}

sub username {
    my $self = shift;
    return $self->hub->current_user->username,
}

sub cgi_vars {
    my $self = shift;
    return $self->hub->cgi->vars;
}

sub redirect {
    my ($self,$target) = @_;
    unless ($target =~ /^(https?:|\/)/i or $target =~ /\?/) {
        $target = $self->hub->cgi->full_uri . '?' . $target;
    }
    $self->hub->headers->redirect($target);
}

sub template_render {
    my ($self, $template, %args) = @_;

    my %template_vars = $self->hub->main ?
                        $self->hub->helpers->global_template_vars :
                        ();

    warn "NO MAIN!!" unless %template_vars;
    
    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => $template,
        paths => [ $self->plugin_dir . "/template" ],
        vars     => {
            workspaces => [$self->hub->current_user->workspaces->all],
            as_json => sub { JSON::Syck::Dump(@_) },
            %template_vars,
            %args,
        },
    );
}

1;
