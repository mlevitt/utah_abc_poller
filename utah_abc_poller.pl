#!/usr/bin/env perl
use feature qw(say);
use strict;
use warnings;
use Mojo::UserAgent;
use Mojo::UserAgent::Transactor;
use Mojo::DOM;
use YAML;
use Getopt::Long;

my $opts = {};
GetOptions(
    $opts,
    'quiet|q',
    'debug|d',
    'exclude_club_stores',
    'config|c=s'
);

if(@ARGV || ! $opts->{'config'} || ! -e $opts->{'config'}) {
    USAGE();
}

my $ua = Mojo::UserAgent->new();
my $config = YAML::LoadFile($opts->{'config'});

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
    $code =~ s/\s*#.*//;  # Remove mid line comnents from the codes
    $names{'ctl00$ContentPlaceHolderBody$tbCscCode'} = $code;
    $tx = $ua->post($config->{url} => form => \%names);

    say $tx->success->body if($opts->{debug});

    $dom = $tx->res->dom;

    my $alcohol_name = '';
    if ($dom->at('#ContentPlaceHolderBody_lblDesc')) {
        $alcohol_name = $dom->at('#ContentPlaceHolderBody_lblDesc')->all_text;
    }

    my $rows = $dom->find('tr.gridViewRow');

    my $qty = 0;
    my @stores;
    for my $row (@$rows) {
        my $store = $row->child_nodes->[2]->all_text . ', ' . $row->child_nodes->[4]->all_text . ', ' . $row->child_nodes->[5]->all_text;
        next if($opts->{'exclude_club_stores'} && $store =~ /Club Store/i);
        $qty += $row->at('span')->all_text;
        push(@stores, $store);
    }
    my $stores_str = join(' | ', @stores);
    say "$alcohol_name - $code - $qty - $stores_str" if($qty || !$opts->{'quiet'});
}


sub USAGE {
    die "USAGE: $0 --config </path/to/configfile.yml> [--quiet] [--debug] [--exclude_club_stores]";
}


