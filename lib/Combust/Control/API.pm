package Combust::Control::API;
use strict;
use base qw(Combust::Control);
use Apache::Constants qw(OK NOT_FOUND);
use JSON;
use Sys::Hostname qw(hostname);
use Return::Value;

sub render {
    my $self = shift;
    my ($uri, $method) = ($self->request->uri =~ m!^(/api/((\w+)/?([a-z]\w+))?)!);

    # MSIE caches POST requests sometimes (?)
    $self->no_cache(1) if $self->r->method eq 'POST';
    
    if ($self->can('check_auth')) {
        unless (my $auth_setup = $self->check_auth($method)) {
            return $self->system_error("$auth_setup" || 'Authentication failure');
        }
    }
    
    my ($result, $meta) = eval {
        $self->api($method, $self->api_params, { json => 1 });
    };
    if ($@) {
        return $self->system_error($@);
    }
    
    return $self->system_error("$uri didn't return a result") unless (defined $result);

    return OK, $result, 'text/javascript';
}

sub api_params {
    shift->request->req_params;
}

my $json = JSON->new(selfconvert => 1, pretty => 1);

sub _format_error {
    my $self = shift;
    my $time = scalar localtime();
    chomp(my $err = join(" ", $time, @_));
    warn "ERROR: $err\n";
    $json->objToJson({ system_error => $err,
                       server       => hostname,
                       datetime     => $time,
                     });
}

sub show_error {
    my $self = shift;
    $self->send_output($self->_format_error(@_), 'text/javascript');
    return 400;
}

sub system_error {
    my $self = shift;
    $self->send_output($self->_format_error(@_), 'text/javascript');
    return 500;
}


1;

