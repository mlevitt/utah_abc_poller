#!/usr/bin/env perl
use feature qw(say);
use strict;
use warnings;
use Mojo::UserAgent;
use Mojo::UserAgent::Transactor;
use Mojo::DOM;
use YAML;
use Getopt::Long;
use String::Util qw(trim);
use File::Basename;

my $opts = {};
GetOptions($opts,
           'config_dir|c=s',
           'debug|d',
           'exclude_club_stores',
           'local_stores',
           'header|h',
           'quiet|q',
           'random|r',
           'template|t=s',
           'yamlarray|y=s',
           'html|w',
          );

my $config_dir = $opts->{'config_dir'};
$config_dir = dirname(__FILE__) unless ($config_dir);
my $config_file = "$config_dir/utah_abc_poller.yml";
my $template_file = "$config_dir/html-template.tmpl";

if (@ARGV || ! $config_dir || !-e $config_dir || !-e $config_file) {
    USAGE();
}

my $ua       = Mojo::UserAgent->new();
my $config   = YAML::LoadFile($config_file);
my $html     = '';

my $myYamlTag = $opts->{'yamlarray'};
$myYamlTag = "codes" unless ($config_dir);

if (! $config->{$myYamlTag}) {
	say "No entries found for $myYamlTag";
	exit 1;
}

my $tx = $ua->get($config->{url});

if ($tx->error) {
    my $err = $tx->error;
    die "$err->{code} response: $err->{message}" if $err->{code};
    die "Connection error: $err->{message}";
}

say $tx->success->body if($opts->{debug});

my $dom = $tx->res->dom;

my $form = $dom->at('#form1');
my %names;
my $inputs = $form->find('input');
for my $input (@$inputs) {
    $names{$input->attr->{'name'}} = $input->attr->{'value'};
}

if ($opts->{'header'}) {
    if ($opts->{'html'}) {
        $html .= "<tr><td>Company Name</td><td>Code</td><td>QT</td><td>Stores</td></tr>\n";
    } else {
        printf("%-41s- %-7s- %-3s- %s\n", "Company Name", "Code", "QT", "Stores");
    }
}

my @codes = (@{$config->{$myYamlTag}});
for my $code (@codes) {
    $code =~ s/\s*#.*//;    # Remove mid line comnents from the codes
    $names{'ctl00$ContentPlaceHolderBody$tbCscCode'} = $code;
    my $tries = 0;
    while ($tries < 5) {
	    $tries = $tries + 1;
	    $tx = $ua->post($config->{url} => form => \%names);
	    last if (! $tx->error);
	    my $err = $tx->error;
	    warn "$err->{code} response: $err->{message}" if $err->{code};
	    warn "Connection error: $err->{message}";
	    sleep(5);
    } 

    say $tx->success->body if ($opts->{debug});

    $dom = $tx->res->dom;

    my $alcohol_name = '';
    if ($dom->at('#ContentPlaceHolderBody_lblDesc')) {
        $alcohol_name = $dom->at('#ContentPlaceHolderBody_lblDesc')->all_text;
    }

    my $alcohol_inventory = '';
    if ($dom->at('#ContentPlaceHolderBody_lblWhsInv')) {
        $alcohol_inventory = $dom->at('#ContentPlaceHolderBody_lblWhsInv')->all_text;
	say "Inventory is $alcohol_inventory"if ($opts->{debug});
    }

    my $alcohol_onOrder = '';
    if ($dom->at('#ContentPlaceHolderBody_lblWhsOnOrder')) {
        $alcohol_onOrder = $dom->at('#ContentPlaceHolderBody_lblWhsOnOrder')->all_text;
	say "On order is $alcohol_onOrder"if ($opts->{debug});
    }

    my $alcohol_price = '';
    if ($dom->at('#ContentPlaceHolderBody_lblPrice')) {
        $alcohol_price = $dom->at('#ContentPlaceHolderBody_lblPrice')->all_text;
	say "Price is $alcohol_price"if ($opts->{debug});
    }

    my $status = '';
    if ($dom->at('#ContentPlaceHolderBody_lblPrice')) {
        $status = $dom->at('#ContentPlaceHolderBody_lblStatusMessage')->all_text;
	say "Status is $status"if ($opts->{debug});
    }

    my $extra = '';
    if ($dom->at('#ContentPlaceHolderBody_lblPrice')) {
        $extra = $dom->at('#ContentPlaceHolderBody_lblStatus')->all_text;
	say "extra is $extra"if ($opts->{debug});
    }

    my $rows = $dom->find('tr.gridViewRow');

    my $qty = 0;
    my @stores;
    for my $row (@$rows) {
	    say "Here's a row :\n$row\n" if ($opts->{debug});
            my $col = trim($row->child_nodes->[1]->all_text); say "Column 1 $col" if ($opts->{debug});
               $col = trim($row->child_nodes->[2]->all_text); say "Column 2 $col" if ($opts->{debug});
            my $thiscity = trim($row->child_nodes->[5]->all_text); say "Column 5 $thiscity" if ($opts->{debug});
            my $thisqty = trim($row->child_nodes->[3]->all_text); say "Column 3 $thisqty" if ($opts->{debug});
               $col = trim($row->child_nodes->[4]->all_text); say "Column 4 $col" if ($opts->{debug});
               $col = trim($row->child_nodes->[5]->all_text); say "Column 5 $col" if ($opts->{debug});
        my $store =
            $thisqty . ', '
          . trim($row->child_nodes->[2]->all_text) . ', '
          . trim($row->child_nodes->[4]->all_text) . ', '
	  . $thiscity;
        $qty += $thisqty;
        next if ($opts->{'exclude_club_stores'} && $store =~ /Club Store/i);
        next if ($opts->{'local_stores'} && $thiscity !~ /(Bountiful|Roy|Taylorsville|Layton|Riverton|Saratoga|Herriman|Salt Lake|Syracuse|Sandy|West Valley|Farmington|Pleasant)/i);
        push(@stores, $store);
    }

    if ($opts->{'html'}) {
        my $stores_str = join('<br>', @stores);
        $html .= "<tr><td>$alcohol_name</td><td>$code</td><td>$alcohol_price</td><td>i$status</td><td>$alcohol_inventory</td><td>$alcohol_onOrder</td><td>$qty</td><td>$stores_str</td></tr>";
    } else {
        my $stores_str = join("\n| ", @stores);
        my $split = ''; $split = "\n| " if ($stores_str);
	# my $more = ''; $more = $status . '|' . $extra if ($status);
	my $more = $status;
        say "$alcohol_name - $alcohol_price - $code - $more - $qty -- $alcohol_inventory -- $alcohol_onOrder$split$stores_str" if ($qty || !$opts->{'quiet'});
    }
    my $sleep_time = int(rand(50)) + 10;
    sleep($sleep_time) if $opts->{'random'};
}

if ($opts->{'html'}) {
    require HTML::Template;
    import HTML::Template;
    my $template = HTML::Template->new(filename => $template_file);
    $template->param(STORES => $html);
    say "Content-Type: text/html";
    say $template->output;
}

sub USAGE {
    die "USAGE: $0 --config </path/to/configfile.yml> [--quiet] [--debug] [--exclude_club_stores]";
}

