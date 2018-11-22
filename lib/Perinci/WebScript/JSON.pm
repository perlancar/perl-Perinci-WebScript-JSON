package Perinci::WebScript::JSON;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Mo qw(build default);

has url => (is=>'rw');
has riap_client => (is=>'rw');
has riap_client_args => (is=>'rw');

sub BUILD {
    my ($self, $args) = @_;

    if (!$self->{riap_client}) {
        require Perinci::Access::Lite;
        my %rcargs = (
            riap_version => $self->{riap_version} // 1.1,
            %{ $self->{riap_client_args} // {} },
        );
        $self->{riap_client} = Perinci::Access::Lite->new(%rcargs);
    }
}

sub run {
    my $self = shift;

    # get Rinci metadata
    my $res = $self->riap_client->request(meta => $self->url);
    die $res unless $res->[0] == 200;
    my $meta = $res->[2];

    # create PSGI app
    require JSON::MaybeXS;
    require Perinci::Sub::GetArgs::WebForm;
    require Plack::Request;
    my $app = sub {
        my $req = Plack::Request->new($_[0]);
        my $args = Perinci::Sub::GetArgs::WebForm::get_args_from_webform(
            $req->parameters, $meta, 1);
        my $res = $self->riap_client->request(call => $self->url);
        [
            $res->[0],
            ['Content-Type' => 'application/json; charset=UTF-8'],
            [JSON::MaybeXS::encode_json($res->[2])],
        ],
    };

    # determine appropriate deployment
    if ($0 =~ /\.cgi\z/) {
        require Plack::Handler::CGI;
        Plack::Handler::CGI->new->run($app);
    } elsif ($0 =~ /\.fcgi\z/) {
        require Plack::Handler::FCGI;
        Plack::Handler::FCGI->new->run($app);
    } else {
        die "Can't determine what deployment to use";
    }
}

1;
# ABSTRACT: From Rinci + function, Create Plack application that returns JSON response

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

In F<My/App.pm>:

 package My::App;
 use Encode::Simple;

 our %SPEC;
 $SPEC{uppercase} = {
     v => 1.1,
     args => {
         input => {schema=>'str*', req=>1},
     },
     args_as => 'array',
     result_naked => 1,
 };
 sub uppercase {
     my ($input) = @_;
     uc(decode 'UTF-8', $input);
 }
 1;

To run as CGI script, create F<app.cgi>:

 #!/usr/bin/env perl
 use Perinci::WebScript::JSON;
 Perinci::WebScript::JSON->new(url => '/My/App/uppercase')->run;

To run as FCGI script, create F<app.fcgi>:

 #!/usr/bin/env perl
 use Perinci::WebScript::JSON;
 Perinci::WebScript::JSON->new(url => '/My/App/uppercase')->run;
