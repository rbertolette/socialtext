package Socialtext::Rest::WorkspaceUsers;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Collection';
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::WorkspaceInvitation;

# FIXME: POST is not yet implemented
#sub allowed_methods {'GET, HEAD, POST'}
sub allowed_methods {'GET, HEAD, POST'}
sub collection_name { "Users in workspace " . $_[0]->ws }

sub _user_representation {
    my ( $self, $user_info ) = @_;
    my $user  = $user_info->[0];
    my $role  = $user_info->[1];
    my $name  = $user->username;
    my $email = $user->email_address;
    return +{
        name               => $name,
        email              => $email,
        is_workspace_admin => ( $role->name eq 'workspace_admin' ),
        role_name          => $role->name,
        uri                => "/data/users/$name",
    };
}

# REVIEW: Any need for a query language here yet?
sub get_resource {
    my ( $self, $rest ) = @_;

    my $acting_user = $self->rest->user;

    # REVIEW: A permissions issue at this stage will result in a 404
    # which might not be the desired result. In a way it's kind of good,
    # in an information hiding sort of way, but....
    if (
        $self->workspace->permissions->user_can(
            user       => $acting_user,
            permission =>
                Socialtext::Permission->new( name => 'admin_workspace' ),
        )
        # REVIEW: {bz: 1265} requires everybody with "Email this Page"
        # permission to see the workspace user list.  Is this desired?
            or 
        $self->workspace->permissions->user_can(
            user       => $acting_user,
            permission =>
                Socialtext::Permission->new( name => 'email_out' ),
        )


        ) {

        return [
            $self->_limit_collectable(
                map { $self->_user_representation($_) }
                    $self->workspace->users_with_roles->all
            )
        ];
    }
    return [];
}

sub _user_may_subscribe {
    my $self = shift;

    return $self->rest->user->is_business_admin()
        || $self->rest->user->is_technical_admin()
        || $self->hub->checker->check_permission('admin_workspace');
}

sub POST {
    my $self = shift;
    my $rest = shift;

    unless ( $self->_user_may_subscribe() ) {
        $rest->header( -status => HTTP_403_Forbidden );
        return '';
    }

    my $create_request_hash = decode_json( $rest->getContent() );

    unless ( $create_request_hash->{username} and
             $create_request_hash->{rolename} ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type  => 'text/plain', );
        return "username, rolename required";
    }

    my $workspace_name = $self->ws;
    my $username = $create_request_hash->{username};
    my $rolename = $create_request_hash->{rolename};

    my $workspace = Socialtext::Workspace->new( name => $workspace_name );
    
    unless( $workspace ) {
        return $self->no_workspace();
    }

    eval {
        if ( $create_request_hash->{send_confirmation_invitation} ) {
            my $from_user = $self->rest->user;
            my $username = $create_request_hash->{username};
            die "username is required\n" unless $username;
            if ( $create_request_hash->{from_address} ) {
                my $from_address = $create_request_hash->{from_address};
                $from_user =
                  Socialtext::User->new( email_address => $create_request_hash->{from_address} );
                die "from_address: $from_address must be valid Socialatext user\n"
                  unless $from_user;
            }
            my $invitation =
              Socialtext::WorkspaceInvitation->new( workspace => $workspace,
                                                    from_user => $from_user,
                                                    invitee   => $username );
            $invitation->send( );
        } else {
            my $user = Socialtext::User->new( username => $username );
            my $role = Socialtext::Role->new( name => $rolename );
        
            unless( $user && $role ) {
                die "both username, rolename must be valid\n";
            }
        
            $workspace->add_user( user => $user,
                                  role => $role );
            $workspace->assign_role_to_user( user => $user, role => $role, is_selected => 1 );
        }
    };
    
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        $rest->header(
                      -status => HTTP_400_Bad_Request,
                      -type   => 'text/plain' );
        return join( "\n", $e->messages );
    } elsif ( $@ ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain' );
        # REVIEW: what kind of system logging should we be doing here?
        return "$@";
    }


    $rest->header(
        -status => HTTP_201_Created,
        -type   => 'application/json',
        -Location => $self->full_url('/', ''),
    );

    return '';
}

1;
