#!/usr/bin/perl -w

# MIT License
#
# Copyright (c) 2007 Derbeth
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

use MediaWiki::Bot;
use Derbeth::I18n;
use Derbeth::Util;
use Derbeth::Wikitools;
use Encode;
use Getopt::Long;
use Pod::Usage;
use Term::ANSIColor;

use strict;
use utf8;

# ========== settings
my $category_name = 'German pronunciation';
my $lang_code = 'de';
my $page_regex = undef;
my $limit=undef;
my $pause=2;
my $clean=0;
my $verbose=0;
my $debug=0;
my $dry_run=undef;
my $show_help=0;

my $donefile = "done/sort_commons_cat.txt";
# ============ end settings

GetOptions(
	'c|category=s' => \$category_name,
	'l|lang=s' => \$lang_code,
	'r|regex=s' => \$page_regex,
	'limit=i' => \$limit,
	'clean' => \$clean,
	'd|debug' => \$debug,
	'p|pause=i' => \$pause,
	'v|verbose' => \$verbose,
	'dry-run:s' => \$dry_run,
	'h|help' => \$show_help,
) or pod2usage('-verbose'=>1,'-exitval'=>1);
pod2usage('-verbose'=>2,'-noperldoc'=>1) if ($show_help);
pod2usage('-verbose'=>1,'-noperldoc'=>1, '-msg'=>'No args expected') if ($#ARGV != -1);

$page_regex ||= "File:$lang_code".'[- ]([^.]+)\.og[ag]';

die "regex '$page_regex' needs to have a capture group" if $page_regex !~ /\([^)]+\)/;

print "Fixing pages like $page_regex in $category_name\n";

my %settings = load_hash('settings.ini');
my %done;
unlink $donefile if ($clean && -e $donefile);
read_hash_loose($donefile, \%done);

$SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub { print_progress(); save_results(); exit 1; };

# ======= main

my $editor = MediaWiki::Bot->new({
	assert => 'bot',
	host => 'commons.wikimedia.org',
	debug => $debug,
	login_data => {'username' => $settings{bot_login}, 'password' => $settings{bot_password}},
	operator => $settings{bot_operator},
});

if (scalar(keys %done) == 0) {
	foreach my $page (Derbeth::Wikitools::get_category_contents_perlwikipedia($editor, "Category:$category_name",undef,{file=>1})) {
		$done{$page} = 'not_done';
	}
}

my $pages_count = scalar(keys %done);
print "$pages_count pages\n";
my $progress_every = $pages_count < 400 ? 50 : 100;
my $visited_pages=0;
my $processed_pages=0;
my $fixed_count=0;

if (defined $dry_run) {
	if ($dry_run) {
		if ($dry_run =~ /$page_regex/i) {
			print encode_utf8("Matched $dry_run: sort key is '$1'\n");
		} else {
			print encode_utf8("Did not match $dry_run\n");
		}
	}
	exit;
}

foreach my $page (sort keys(%done)) {
	++$processed_pages;

	print_progress() if $visited_pages > 0 && $processed_pages % $progress_every == 0;

	my $is_done = $done{$page};
	next if ($is_done eq 'not_fixed' || $is_done eq 'skipped' || $is_done eq 'fixed');

	if ($page !~ /$page_regex/io) {
		print "skipping because of name ", encode_utf8($page), "\n" if $verbose;
		$done{$page} = 'skipped';
		next;
	}
	my $sortkey = $1;
	$sortkey =~ s/^(at)-//i;

	++$visited_pages;
	sleep $pause;

	my $text = $editor->get_text($page);
	unless (defined($text)) {
		if ($editor->{error} && $editor->{error}->{code}) {
			print colored('cannot','red'), encode_utf8(" get text of $page: "), $editor->{error}->{details}, "\n";
		} else {
			print 'unknown ', colored('error','red'), encode_utf8(" getting text of $page\n");
		}
		last;
	}

	# initial cosmetics
	$text =~ s/\[\[ *Category *: */[[Category:/g;
	while ($text =~ s/\[\[ *Category *: *([^_\]|]+)_/[[Category:$1 /g) {};

	my $changed = ($text =~ s/\[\[ *Category *: *($category_name) *\]\]/[[Category:$1|$sortkey]]/);
	if (!$changed) {
		print "nothing to fix: ", encode_utf8($page), "\n";
		$done{$page} = 'not_fixed';
		next;
	}
	my $edited = $editor->edit({page=>$page, text=>$text, bot=>1, minor=>1,
		summary=>"sort in Category:$category_name ($sortkey)"});
	if (!$edited) {
		print colored('failed','red'), " to fix ", encode_utf8($page);
		print " details: $editor->{error}->{details}" if $editor->{error};
		print "\n";
		last;
	}
	print encode_utf8("fixed $page using sort '$sortkey'\n");
	$done{$page} = 'fixed';
	++$fixed_count;

	if ($limit && $fixed_count >= $limit) {
		last;
	}
}

print_progress();
save_results();

# ======= end main

sub print_progress {
	my ($sec,$min,$hour) = localtime();
	printf '%02d:%02d %d/%d', $hour, $min, $processed_pages, $pages_count;
	printf colored(' %2.0f%%', 'green'), 100*$processed_pages/$pages_count;
	print " fixed $fixed_count\n";
}

sub save_results {
	save_hash_sorted($donefile, \%done);
}

=head1 NAME

sort_commons_cat - adds sort key to audio files on Commons

=head1 SYNOPSIS

 plnews_month.pl [options]

 Options:
   -c --category <cat>    category name like 'German pronunciation' (required)
   -l --lang <lang>       language code like 'de' used to create the regular expression
   -r --regex <regex>     regular expression used to match file names and get sort key
                          defaults to "File:$lang_code".'[- ]([^.]+)\.og[ag]'
      --limit <limit>     edit at most <limit> pages, then finish
   -p --pause <pause>     pause for <pause> seconds before fetching each page
                          defaults to 2
      --clean             forget what was done before
                          needed if you change category since last run
      --dry-run[=exmpl]   do not make any modifications, just print what will be edited
                          if the example is provided, a match against the regular expression will be tried

   -v --verbose           print diagnostic messages
   -d --debug             print diagnostic messages for MediaWiki bot
   -h --help              show full help and exit

=head1 EXAMPLE

 ./sort_commmons_cat.pl -c 'German pronunciation' -l 'de' --pause 4
 ./sort_commmons_cat.pl -c 'English pronunciation' -r 'File:En-ca[- ]([^.]+)\.og[ag]' --dry-run='File:En-ca-cat.ogg'

=head1 AUTHOR

Derbeth <https://github.com/Derbeth>

=cut
