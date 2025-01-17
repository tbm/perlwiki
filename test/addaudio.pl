#!/usr/bin/perl -w

use strict;
use lib '.';
use Derbeth::Wikitools;
use Derbeth::Wiktionary;
use Derbeth::I18n;
use Derbeth::Inflection;
use Derbeth::Util;
use Derbeth::Web;
use Getopt::Long;
use Encode;

my $interactive=0; # run kdiff3

GetOptions('i|interactive!'=> \$interactive) or die;

my @VALID_ARGS = qw{added_audios audio audio_pl ipa ipa_pl lang_code  plural result word};
my $TESTDATA_DIR = 'testdata';
my $TEST_TEMP_DIR = '/tmp/testaddaudio-test';

my @tested_wikts = qw/de en pl/;

`rm -rf $TEST_TEMP_DIR/`;
`mkdir $TEST_TEMP_DIR`;

my %valid_args;
foreach (@VALID_ARGS) { $valid_args{$_} = 1; }

for my $wikt_lang(@tested_wikts) {
	my $passed=1;
	my $i=0;
	while(1) {
		my $test_input = "${TESTDATA_DIR}/$wikt_lang/in${i}.txt";
		my $test_output = "${TEST_TEMP_DIR}/out${i}.txt";
		my $test_expected = "${TESTDATA_DIR}/$wikt_lang/out${i}.txt";
		my $args_file = "${TESTDATA_DIR}/$wikt_lang/arg${i}.ini";

		unless (-e $test_input) {
			last;
		}
		
		my %args;
		read_hash_loose($args_file, \%args);
		validate_args($args_file, %args);
		my ($success,$summary) = do_test($test_input, $wikt_lang, $test_input, $test_output, %args);
		my $identical = $success ? compare_files($test_output, $test_expected) : 0;
		if (!$identical) {
			print "Test $i failed.\n";
			print encode_utf8("Edit summary: $summary\n");
			if ($interactive) {
				system("kdiff3 $test_output $test_expected -L1 Received -L2 Expected");
				exit(11);
			} else {
				system("diff -u $test_output $test_expected");
				$passed = 0;
			}
		}

		++$i;
	}
	exit(11) unless ($passed);
	print "$wikt_lang: $i tests succeeded.\n";
	system("rm -f $TEST_TEMP_DIR/*");
}
print "all ok\n";
exit(0);

# returns true if files are identical, otherwise false.
# when files are not identical, prints diff to standard output.
sub compare_files {
	my ($file1,$file2) = @_;
	my $result = `diff $file1 $file2`;
	if ($result eq '') {
		return 1;
	} else {
		#print $result;
		return 0;
	}
}

sub do_test {
	my ($file, $wikt_lang, $test_input, $test_output, %args) = @_;
	open(OUT,">$test_output");

	my $text = text_from_file($test_input);
	my $lang_code = 'en';
	$lang_code = $args{'lang_code'} if (exists $args{'lang_code'});
	my $word = $args{'word'};
	unless($word) {
		print "missing 'word' parameter for $file\n";
		return (0, '');
	}

	my $initial_summary = initial_cosmetics($wikt_lang,\$text);
	my ($before, $section, $after) = split_article_wikt($wikt_lang,$lang_code,$text,1);
	my ($result,$added_audios,$edit_summary) = add_audio($wikt_lang,\$section,$args{'audio'},$lang_code,0,$word,$args{'audio_pl'},$args{'plural'},$args{'ipa'},$args{'ipa_pl'});
	$text = $before.$section.$after;
	my $final_summary = final_cosmetics($wikt_lang, \$text, $word, $args{'plural'});
	print OUT encode_utf8($text);
	close(OUT);
	$edit_summary .= '; '.$initial_summary if ($initial_summary);
	$edit_summary .= '; '.$final_summary if ($final_summary);

	if (exists($args{'result'}) && $args{'result'} != $result) {
		print encode_utf8("$file: expected result $args{result} but got $result\n");
		return (0, $edit_summary);
	}
	if (exists($args{'added_audios'}) && $args{'added_audios'} != $added_audios) {
		print encode_utf8("$file: expected added $args{added_audios} but got $added_audios\n");
		return (0, $edit_summary);
	}
	return (1, $edit_summary);
}

sub validate_args {
	my ($args_file, %args) = @_;
	foreach my $k (sort keys %args) {
		unless(exists $valid_args{$k}) {
			die "$args_file: illegal argument '$k'. Valid arguments are: @VALID_ARGS";
		}
	}
}
