#!/usr/bin/env perl
use feature qw(say);
use strict;
use warnings;
use Mojo::UserAgent;
use Mojo::UserAgent::Transactor;
use Mojo::DOM;
use YAML;

my $ua = Mojo::UserAgent->new();
my $config = YAML::LoadFile('utah_abc_poller.yml');

my $tx= $ua->get($config->{url});

if(!$tx->success) {
    my $err = $tx->error;
    die "$err->{code} response: $err->{message}" if $err->{code};
    die "Connection error: $err->{message}";
}

#say $tx->success->body;

my $dom = $tx->res->dom;

my $form = $dom->at('#form1');
my %names;
my $inputs = $form->find('input');
for my $input (@$inputs) {
    $names{$input->attr->{'name'}} = $input->attr->{'value'};
}

for my $code (@{$config->{codes}}) {
    $names{'ctl00$ContentPlaceHolderBody$tbCscCode'} = $code;
    $tx = $ua->post($config->{url} => form => \%names);

    #say $tx->success->body;

    $dom = $tx->res->dom;

    my $alcohol_name = '';
    if ($dom->at('#ContentPlaceHolderBody_lblDesc')) {
        $alcohol_name = $dom->at('#ContentPlaceHolderBody_lblDesc')->all_text;
    }

    my $rows = $dom->find('tr.gridViewRow');

    my $qty = 0;
    for my $row (@$rows) {
        $qty += $row->at('span')->all_text;
    }
    say "$alcohol_name - $code - $qty";
}



