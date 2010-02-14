#!/usr/bin/perl -w

use strict;

use Derbeth::Util;
use Derbeth::I18n;
use Derbeth::Wiktionary;
use Getopt::Long;
use Encode;

my $wikt_lang='de';

GetOptions(
	'w|wikt=s' => \$wikt_lang,
) or die;

my %done;
my %langs;

read_hash_loose("done/done_audio_${wikt_lang}.txt", \%done) or die;
while (my ($entry,$result) = each(%done)) {
	my ($lang,$word) = split /-/, $entry;
	if ($result eq 'error') {
		unless(exists $langs{$lang}) {
			$langs{$lang} = [];
		}
		push @{$langs{$lang}}, $word;
	}
}

foreach my $lang (sort(keys(%langs))) {
	print "== ", encode_utf8(get_language_name($wikt_lang, $lang)), "==\n";
	print "{| class=\"wikitable\"\n";
	my %audio;
	my $audio_file;
	{
		my $filtered = "audio/${wikt_lang}wikt_audio_${lang}.txt";
		my $all = "audio/audio_${lang}.txt";
		$audio_file = (-e $filtered) ? $filtered : $all;
	}
	read_hash_loose($audio_file, \%audio) or die "can't open $audio_file";
	my @words = sort(@{$langs{$lang}});
	foreach my $word(@words) {
		my $pron = $audio{$word};
		unless($pron) {
			print STDERR "no audio ", encode_utf8($word), "($lang)\n";
			next;
		}
		my %files = decode_pron($pron);

		print encode_utf8("|-\n| [[$word]] || ");
		my @formatted;
		foreach my $file (keys(%files)) {
			push @formatted, encode_utf8("[[commons:File:$file|$file]]");
		}
		print join(', ', @formatted), "\n";
	}
	print "|}\n\n";
}

