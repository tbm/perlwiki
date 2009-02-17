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

package Derbeth::Wiktionary;
require Exporter;

use utf8;
use strict;
use English;

use Derbeth::I18n;
use Derbeth::Wikitools;
use Encode;

our @ISA = qw/Exporter/;
our @EXPORT = qw/add_audio
	add_audio_plwikt
	add_audio_dewikt
	initial_cosmetics
	final_cosmetics
	add_inflection_plwikt
	should_not_be_in_category_plwikt/;
our $VERSION = 0.7.0;

# Parameters:
#   %files - hash (file=>region) eg. 'en-us-solder.ogg' => 'us',
#            'en-solder.ogg' => ''
#
# Returns:
#   $audios - '{{audio|en-us-solder.ogg|audio (US)}}, {{audio...}}'
#   $edit_summary - list of added files
#                   en-us-solder.ogg, en-solder.ogg, en-au-solder.ogg
sub create_audio_entries_enwikt {
	my $plural = shift;
	my %files = @_;
	
	my @audios;
	my @summary;
	while (my ($file,$region) = each(%files)) {
		my $text = '{{audio|'.$file.'|';
		$text .= $plural ? $plural : 'Audio';
		my $edit_summary = $file;
		if ($region ne '') {
			$text .= ' ('.get_regional_name('en',$region).')';
		}
		$text .= '}}';
		
		push @audios, $text;
		push @summary, $edit_summary;
	}
	return (join("\n*", @audios), join(', ', @summary));
}

sub create_audio_entries_dewikt {
	my $plural = shift;
	my %files = @_;
	
	my @audios;
	my @summary;
	while (my ($file,$region) = each(%files)) {
		my $text = '{{Audio|'.$file.'|';
		my $edit_summary = $file;
		if ($plural) {
			$text .= $plural;
		}
		if ($region ne '') {
			$text .= ' ('.get_regional_name('de',$region).')';
		}
		$text .= '}}';
		$text =~ s/\| /|/g;
		$text =~ s/\|}}/}}/g;
		
		push @audios, $text;
		push @summary, $edit_summary;
	}
	return (join(' ', @audios), join(', ', @summary));
}

sub create_audio_entries_plwikt {
	my $plural = shift;
	my %files = @_;
	
	my @audios;
	my @summary;
	while (my ($file,$region) = each(%files)) {
		my $text = '{{audio|'.$file;
		my $edit_summary = $file;
		if ($region ne '') {
			$text .= '|wymowa '.get_regional_name('pl',$region);
		}
		$text .= '}}';
		
		push @audios, $text;
		push @summary, $edit_summary;
	}
	return (join(' ', @audios), join(', ', @summary));
}

# Parameters:
#   $pron - 'en-us-solder.ogg<us>|en-solder.ogg|en-au-solder.ogg<au>'
#   $section - reference to section where pronuciation should be
#              added (read-only)
#   $plural - plural form of word (optional)
#
# Returns:
#   $audios - '{{audio|en-us-solder.ogg|audio (US)}}, {{audio...}}'
#   $audios_count - 3
#   $edit_summary - list of added files
#                   en-us-solder.ogg, en-solder.ogg, en-au-solder.ogg
sub create_audio_entries {
	my ($wikt_lang,$pron,$section,$plural) = @_;
	
	my @prons = split /\|/, $pron;
	my %files; # 'en-us-solder.ogg' => 'us', 'en-solder.ogg' => ''
	
	foreach my $a_pron (@prons) {
		$a_pron =~ /(.*.ogg)(<(.*)>)?/i;
		my $file=$1;
		my $region = $3 ? $3 : '';
		if ($$section =~ /$file/i) {
			next;
		}
		$files{$file} = $region;
	}
	
	my ($audios,$edit_summary);
	if ($wikt_lang eq 'de') {
		($audios,$edit_summary) = create_audio_entries_dewikt($plural,%files);
	} elsif ($wikt_lang eq 'en') {
		($audios,$edit_summary) = create_audio_entries_enwikt($plural,%files);
	} elsif ($wikt_lang eq 'pl') {
		($audios,$edit_summary) = create_audio_entries_plwikt($plural,%files);
	} else {
		die "Wiktionary $wikt_lang not supported";
	}
	
	return ($audios, scalar(keys(%files)),$edit_summary);
}


# Returns:
#   $result - 0 when ok, 1 when section already has all audio,
#             2 when cannot add audio
#   $added_audios - how many audio files have been added
#   $edit_summary - edit summary text
sub add_audio_enwikt {
	my ($section,$pron,$language,$check_only,$pron_pl,$plural) = @_;
	($pron_pl,$plural) = ('',''); # turned off
	
	my ($audios,$audios_count,$edit_summary)
		= create_audio_entries('en',$pron,$section);
	my ($audios_pl,$audios_count_pl,$edit_summary_pl)
		= create_audio_entries('en',$pron_pl,$section,$plural);
	
	if ($audios eq '' && $audios_pl eq '') {
		return (1,'','');
	}
	if ($check_only) {
		return (0,'','');
	}
	
	$audios_count += $audios_count_pl;
	
	$edit_summary = 'added audio '.$edit_summary;
	$edit_summary .= ' plural ' . $edit_summary_pl if ($edit_summary_pl ne '');
	
	if ($audios_pl ne '') {
		if ($audios eq '') {
			$audios = $audios_pl;
		} else {
			$audios .= ', '.$audios_pl;
		}
	}
	
	#my ($before_etym,$etym,$after_etym);
	#if ($$section =~ /===\s*Etymology([^=]*)={3,}/) {
	#	($before_etym,$etym,$after_etym) = ($PREMATCH,$MATCH,$POSTMATCH);
	#}
	
	# TODO
	
	my $audio_marker = ">>HEREAUDIO<<";
	
	if ($$section =~ /\{\{:/) {
		$edit_summary = 'handling page transclusion not supported';
		return (2,$audios_count,$edit_summary);
	} elsif ($$section =~ /= *Etymology +1 *=/
	|| ($$section =~ /= *Etymology/i && $POSTMATCH =~ /= *Etymology/i)) {
		$edit_summary = 'handling multiple etymologies not supported';
		return (2,$audios_count,$edit_summary);
	} elsif ($$section =~ /= *Pronunciation/i && $POSTMATCH =~ /= *Pronunciation/i) {
		$edit_summary = 'handling multiple pronunciation sections not supported';
		return (2,$audios_count,$edit_summary);
	} elsif ($$section !~ /=== *Pronunciation *===/) {
		$edit_summary .= '; added missing pron. section';
		
		if ($$section =~ /===\s*Etymology\s*={3,}(.|\n|\r|\f)*?==/) {
			unless ($$section =~ s/(=== *Etymology *={3,}(.|\n|\r|\f)*?)(==)/$1===Pronunciation===\n* $audio_marker\n\n$3/) {
				$edit_summary .= '; cannot add pron. after etymology';
				return (2,$audios_count,$edit_summary)
			}
		} else { # no etymology at all
			if ($$section =~ s/(==\s*$language\s*==(.|\n|\r|\f)*?)(==)/$1===Pronunciation===\n* $audio_marker\n\n$3/) {
				# ok, add before first heading after language
			} elsif ($$section =~ s/(==\s*$language\s*==)/$1\n\n===Pronunciation===\n* $audio_marker/) {
				# ok, no heading, so just add after language
			} else {
				$edit_summary .= '; cannot add pron. after section begin';
				return (2,$audios_count,$edit_summary);
			}
		}
	} else {
		unless ($$section =~ s/(===\s*Pronunciation\s*={3,})/$1\n* $audio_marker/) {
			$edit_summary .= '; cannot add audio after pron. section';
			return (2,$audios_count,$edit_summary);
		}
	}
	
	$$section =~ s/\r\n/\n/g;
	while ($$section =~ /(\* *$audio_marker\n)(\*[^\n]+\n)/) {
		my $next_line = $2;
		if ($next_line =~ /homophones|rhymes|hyphenation/i) {
			last;
		} else {
			$$section =~ s/(\* *$audio_marker\n)(\*[^\n]+\n)/$2$1/;
		}
	}
	unless ($$section =~ s/$audio_marker/$audios/) {
		$edit_summary .= '; lost audios marker';
		return (2,$audios_count,$edit_summary);
	}
	
	if ($$section =~ /$audio_marker/) {
		$edit_summary .= '; cannot remove audios marker';
		return (2,$audios_count,$edit_summary);
	}
	
	$$section =~ s/(\n|\r|\f){{IPA/$1*{{IPA/;
	
	#my $cat = '[[Category:Mandarin entries with audio links]]';
	#if ($$section =~ s/(\[\[Category:)/$cat\n$1/){
	#	$edit_summary .= "; + $cat"; # ok
	#} else {
	#	unless ($$section =~ s/(\[\[\w{2}:|----|$)/\n\n$cat\n$1/) {
	#		$edit_summary .= '; cannot add category';
	#	} else {
	#		$$section =~ s/(\n|\r|\f){3,}(\[\[Category)/$1$1$2/g;
	#		$edit_summary .= "; + $cat";
	#	}
	#}
	
	return (0,$audios_count,$edit_summary);
}

# Returns:
#   $result - 0 when ok, 1 when section already has all audio,
#             2 when cannot add audio
#   $added_audios - how many audio files have been added
#   $edit_summary - edit summary text
sub add_audio_dewikt {
	my ($section,$pron,$language,$check_only,$pron_pl,$plural) = @_;
	#print "$$section\n"; # DEBUG
	$pron_pl = '' if (!defined($pron_pl));

	my ($audios,$audios_count,$edit_summary)
		= create_audio_entries('de',$pron,$section);
	my ($audios_pl,$audios_count_pl,$edit_summary_pl)
		= create_audio_entries('de',$pron_pl,$section,$plural);
	
	if ($audios eq '' && $audios_pl eq '') {
		return (1,'','');
	}
	if ($check_only) {
		return (0,'','');
	}
	
	$audios_count += $audios_count_pl;
	
	$edit_summary = '+ Audio '.$edit_summary;
	$edit_summary .= ' Plural: ' . $edit_summary_pl if ($edit_summary_pl ne '');
	
	if ($$section =~ /\{\{kSg\.\}\}/) {
		$edit_summary .= 'met {{kSg.}}, won\'t add audio automatically';
		return (2,$audios_count,$edit_summary);
	}

	my $newipa = ':[[Hilfe:IPA|IPA]]: {{Lautschrift|...}}';
	my $newaudio = ':[[Hilfe:Hörbeispiele|Hörbeispiele]]: {{fehlend}}';
	
	if ($$section =~ /Wortart\s*\|\s*Substantiv/) {
		$newipa .= ', {{Pl.}} {{Lautschrift|...}}';
		$newaudio .= ', {{Pl.}} {{fehlend}}';
	}
	
	if ($$section !~ /{{Aussprache}}/) {
		$edit_summary .= '; + fehlende {{Aussprache}}';
		
		if ($$section !~ /{{Bedeutung/) {
			unless ($$section =~ s/(==== *Übersetzungen)/{{Bedeutungen}}\n\n$1/) {
				$edit_summary .= '; no {{Bedeutungen}} and cannot add it';
				return (2,$audios_count,$edit_summary);
			}
			$edit_summary .= '; + {{Bedeutungen}} (leer)';
		}
		
		unless ($$section =~ s/{{Bedeutung(en)?}}/{{Aussprache}}
$newipa
$newaudio

{{Bedeutungen}}/xi) {
			$edit_summary .= '; cannot add {{Aussprache}}';
			return (2,$audios_count,$edit_summary);
		}
	}
	if ($$section !~ /: *\[\[Hilfe:Hörbeispiele\|Hörbeispiele\]\]:/) {
		$$section =~ s/{{Aussprache}}/{{Aussprache}}
$newaudio/x;
	}
	
	if ($audios ne '') {
		if ($$section =~ /Hörbeispiele\]\]: +(-|–|—|{{fehlend}})/) {
			unless ($$section =~ s/Hörbeispiele\]\]: +(-|–|—|{{fehlend}})/Hörbeispiele]]: $audios/) {
				$edit_summary .= '; cannot replace {{fehlend}}';
				return (2,$audios_count,$edit_summary);
			}
		} else { # already some pronunciation
			unless ($$section =~ s/Hörbeispiele\]\]: */Hörbeispiele]]: $audios /) {
				$edit_summary .= '; cannot append pron.';
				return (2,$audios_count,$edit_summary);
			}
			$$section =~ s/  / /g;
		}
	}
	
	if ($audios_pl ne '') {
		$$section =~ /(:\[\[Hilfe:Hörbeispiele\|Hörbeispiele\]\])([^\r\f\n]*)/;
		my $before = $`.$1;
		my $after = $';
		my $pron_line = $2;
		
		# no plural {{Pl.}} ?
		if ($pron_line !~ /{{Pl.}}/) {
			$pron_line .= ' {{Pl.}} {{fehlend}}';
		}
		
		if ($pron_line =~ /{{Pl.}} +{{fehlend}}/) {
			$pron_line =~ s/{{Pl.}} +{{fehlend}}/{{Pl.}} $audios_pl/;
		} else {
			$pron_line =~ s/{{Pl.}}/{{Pl.}} $audios_pl/;
		}
		
		$$section = $before.$pron_line.$after;
	}
	
	# if audio before ipa, put it after ipa
	$$section =~ s/(:\[\[Hilfe:Hörbeispiele\|Hörbeispiele\]\].*)(\n|\r|\f)(:\[\[Hilfe:IPA\|IPA\]\].*)/$3$2$1/;
	
	# prevent pronunciation being commented out
	#if ($$section =~ /<!--((.|\n|\r|\f)*?Aussprache(.|\n|\r|\f)*?)-->/$1/) {
	#	$edit_summary .= '; ACHTUNG: die Aussprache ist kommentiert';
	#}
	
	return (0,$audios_count,$edit_summary);
}

sub _put_audio_plwikt {
	my ($pron_part_ref,$audios) = @_;
	
	if ($$pron_part_ref =~ /{{IPA/) {
		unless ($$pron_part_ref =~ s/({{IPA[^}]+}})/$1 $audios/) {
			return 0;
		}
	} else {
		$$pron_part_ref = $audios . ' ' . $$pron_part_ref;
	}
	
	return 1;
}

# Input:
#   ...'{{wymowa}} (1.1) {{lp}} {{IPA|a}}; {{lm}} {{IPA2|b}}'...
# Output:
#  (' (1.1) {{lp}} ', '{{IPA|a}};', '{{IPA2|b}}')
sub _split_pron_plwikt {
	my ($section_ref) = @_;

	$$section_ref =~ /{{wymowa}}([^\r\n\f]*)/;
	my $pron_line = $1;
	die if $pron_line =~ /\n|\r|\f/;
	my $pron_line_prelude='';
	
	if ($pron_line =~ /^ *\([^)]+\) */) { # {{wymowa}} (1.1)
		$pron_line_prelude .= $MATCH;
		$pron_line = $POSTMATCH;
	}
	if ($pron_line =~ /^.*{{lp}} */) {
		$pron_line_prelude .= $MATCH;
		$pron_line = $POSTMATCH;
	}
	
	my ($pron_line_sing,$pron_line_pl);
	if ($pron_line =~ /^(.*){{lm}}/) {
		$pron_line =~ /^(.*){{lm}}/;
		$pron_line_sing = $1;
		$pron_line_pl = $POSTMATCH;
	} else {
		($pron_line_sing,$pron_line_pl) = ($pron_line,'');
	}
	
	#print "pron:[$pron_line_prelude|$pron_line_sing|$pron_line_pl]\n";
	return ($pron_line_prelude,$pron_line_sing,$pron_line_pl);
}

# Parameters:
#   $pron_pl - additional parameter; plural pronunciation
#   $ipa_sing - IPA for singular, without brackets
#   $ipa_plural
#
# Returns:
#   $result - 0 when ok, 1 when section already has all audio,
#             2 when cannot add audio
#   $added_audios - how many audio files have been added
#   $edit_summary - edit summary text
sub add_audio_plwikt {
	my ($section_ref,$pron,$language,$check_only,$pron_pl,$plural,$ipa_sing,$ipa_pl) = @_;
	$pron_pl = '' if (!defined($pron_pl));
	$ipa_sing = '' if (!defined($ipa_sing));
	$ipa_pl = '' if (!defined($ipa_pl));
	my @summary;
	
	my ($audios,$audios_count,$edit_summary_sing)
		= create_audio_entries('pl',$pron,$section_ref);
	my ($audios_pl,$audios_count_pl,$edit_summary_pl)
		= create_audio_entries('pl',$pron_pl,$section_ref);
	
	if ($$section_ref !~ /{{wymowa}}/) {
		push @summary, '+ brakująca sekcja {{wymowa}}';
		unless ($$section_ref =~ s/{{znaczenia}}/{{wymowa}}\n{{znaczenia}}/) {
			push @summary, 'nie udało się dodać sekcji "wymowa"';
			return (2,$audios_count,join('; ', @summary));
		}
	}
	
	my ($pron_line_prelude,$pron_line_sing,$pron_line_pl)
		= _split_pron_plwikt($section_ref);
	
	my $can_add_ipa = ($ipa_sing ne '' && $pron_line_sing !~ /{{IPA/)
	|| ($ipa_pl ne '' && $pron_line_pl !~ /{{IPA/);
	
	if ($audios eq '' && $audios_pl eq '' && !$can_add_ipa) {
		return (1,'','');
	}
	if ($check_only) {
		return (0,'','');
	}
	
	$audios_count += $audios_count_pl;
	
	if ($edit_summary_sing ne '') {
		push @summary, '+ audio '.$edit_summary_sing;
	}
	if ($edit_summary_pl ne '') {
		push @summary, '+ audio dla lm '.$edit_summary_pl;
	}
	
	if ($ipa_sing ne '' && $pron_line_sing !~ /{{IPA/) {
		$pron_line_sing = "{{IPA3|$ipa_sing}} " . $pron_line_sing;
		push @summary, '+ IPA dla lp z de.wikt';
	}
	if ($ipa_pl ne '' && $pron_line_pl !~ /{{IPA/) {
		$pron_line_pl = "{{IPA4|$ipa_pl}} " . $pron_line_pl;
		push @summary, '+ IPA dla lm z de.wikt';
	}
	
	if ($audios ne '') {
		unless (_put_audio_plwikt(\$pron_line_sing,$audios)) {
			push @summary, 'nie udało się dodać audio dla lp';
			return (2,$audios_count,join('; ', @summary));
		}
	}
	if ($audios_pl ne '') {
		unless (_put_audio_plwikt(\$pron_line_pl,$audios_pl)) {
			push @summary, 'nie udało się dodać audio dla lm';
			return (2,$audios_count,join('; ', @summary));
		}
	}
	
	my $pron_line = ' '.$pron_line_prelude.$pron_line_sing;
	if ($pron_line_pl =~ /\w/) {
		$pron_line .= ' {{lm}} ' . $pron_line_pl;
	}
	$pron_line =~ s/ {2,}/ /g;
	$pron_line =~ s/ +$//;
	
	if ($pron_line =~ /\//) {
		push @summary, 'UWAGA: napotkano IPA bez szablonu';
	}
	
	$$section_ref =~ s/{{wymowa}}(.*)/{{wymowa}}$pron_line/;
	
	return (0,$audios_count,join('; ', @summary));
}

# Parameters:
#   $section_ref - reference to text of section in processed language
#   $pron - 'en-us-solder.ogg<us>|en-solder.ogg'
#   $language - language of section, 'English', 'Polish', 'Japanese'
#   $check_only - if true, only checks whether to add pronunciation
#                 but does not modify anything (optional)
#
# Returns:
#   $result - 0 when ok, 1 when section already has all audio,
#             2 when cannot add audio
#   $added_audios - how many audio files have been added
#   $edit_summary - edit summary text
sub add_audio {
	my ($wikt_lang,$section_ref,$pron,$language,$check_only,$pron_pl,$plural,$ipa_sing,$ipa_pl) = @_;
	
	if ($wikt_lang eq 'en') {
		return add_audio_enwikt($section_ref,$pron,$language,$check_only,$pron_pl,$plural,$ipa_sing,$ipa_pl);
	} elsif ($wikt_lang eq 'de') {
		return add_audio_dewikt($section_ref,$pron,$language,$check_only,$pron_pl,$plural,$ipa_sing,$ipa_pl);
	} elsif ($wikt_lang eq 'pl') {
		return add_audio_plwikt($section_ref,$pron,$language,$check_only,$pron_pl,$plural,$ipa_sing,$ipa_pl);
	} else {
		die "Wiktionary $wikt_lang not supported";
	}
}



sub initial_cosmetics_enwikt {
	return '';
}

sub initial_cosmetics_dewikt {
	my $page_text_ref = shift;
	my @summary;
	my $comment_removed = 0;
	
	if ($$page_text_ref =~ s/({{Aussprache}}) +(\[\[Hilfe:IPA\|)/$1\n:$2/g) {
		push @summary, '{{Aussprache}} und IPA waren in einer Zeile';
	}
	
	if ($$page_text_ref =~ s/Wiktionary:Hörbeispiele/Hilfe:Hörbeispiele/g) {
		push @summary, 'Linkkorr.';
	}
	
	my $repeat=1;
	while($repeat) {
		$repeat=0;
		while ($$page_text_ref =~ /<!--((.|\n|\r|\f)*?)-->/gc) {
			my $comment = $MATCH;
			my $inside = $1;
			if ($inside =~ /Hilfe:Hörbeispiele|{{Aussprache}}/) {
				# prepare to serve as regexp
				#$comment =~ s/([^\\])([\[|])/$1\\$2/g;
				$comment =~ s/(\[|\||\(|\))/\\$1/g;
				#print $comment;
				unless ($$page_text_ref =~ s/$comment/$inside/) {
					# fatal error
					push @summary, 'Entfernen des Kommentars um Aussprache fehlgeschlagen';
					last;
				}
				$comment_removed = 1;
				$repeat=1;
				#last;
			}
		}
	}
	$$page_text_ref =~ s/ +{{Aussprache}}/{{Aussprache}}/g;
	$$page_text_ref =~ s/ +(:\[\[Hilfe:(IPA|Hörbeispiele))/$1/g;
	if ($comment_removed) {
		push @summary, 'ein Kommentar um Aussprache wurde entfernt';
	}
		
	if ($$page_text_ref =~ s/(\n|\r|\f) *(\[\[Hilfe:(IPA|Hörbeispiele))/$1:$2/g) {
		push @summary, '+ ":"';
	}
	
	if ($$page_text_ref =~ s/(\n|\r|\f){2,}(:\[\[Hilfe:(IPA|Hörbeispiele))/$1$2/g) {
		push @summary, '- leere Zeile';
	}
	
	if ($$page_text_ref =~ s/(:\[\[Hilfe:(Hörbeispiele|IPA)[^\r\f\n]*)''Plural:?''/$1\{\{Pl.}}/g) {
		push @summary, "''Plural'' -> {{Pl.}}";
	}
	if ($$page_text_ref =~ s/{{Bedeutung}}/{{Bedeutungen}}/gi) {
		push @summary, '{{Bedeutung}} -> {{Bedeutungen}}';
	}
	
	if ($$page_text_ref =~ /(\[\[Hilfe:IPA\|IPA\]\])([^\r\f\n]*)/) {
		my $before = $`.$1;
		my $after = $';
		my $ipa_line = $2;
		if ($ipa_line =~ s/&nbsp;/ /g) {
			push @summary, 'nbsp wurde entfernt';
		}
		if ($ipa_line =~ s/( )\[([^[\]]*)]/$1\{\{Lautschrift|$2}}/g) {
			push @summary, '{{Lautschrift)} wurde in IPA eingefügt';
		}
		$ipa_line =~ s/ {2,}/ /g;
		$$page_text_ref =$before.$ipa_line.$after;
	}
	
	return join(', ', @summary);
}

sub initial_cosmetics_plwikt {
	my $page_text_ref = shift;
	my @summary;
	my $comm_removed=0;
	
	$$page_text_ref =~ s/''l(p|m)''/{{l$1}}/g;
	
	if ($$page_text_ref =~ s/<!-- *{{IPA[^}]+}} *-->//g) {
		push @summary, '- zakomentowane puste IPA';
		$comm_removed = 1;
	}
	if ($$page_text_ref =~ s/<!-- *\[\[Aneks:IPA\|(IPA)?\]\]:.*?-->//g) {
		push @summary, '- zakomentowane puste IPA' if (!$comm_removed);
	}
	if ($$page_text_ref =~ s/{{wymowa}} +\[\[Aneks:IPA\|IPA\]\]:\s*(?:\/\s*\/\s*)?(\n|\r|\f)/{{wymowa}}$1/g) {
		push @summary, 'usun. pustego IPA';
	}
	
	if ($$page_text_ref =~ s/{{IPA.?\|}}//g) {
		push @summary, 'usun. pustego IPA';
	}
	if ($$page_text_ref =~ s/(\{\{IPA[^}]+\}\}) +({{lp}})/$2 $1/g) {
		push @summary, 'formatowanie wymowy';
	}
	if ($$page_text_ref =~ s/\[\[(Image|Grafika|File):/[[Plik:/g) {
		push @summary, 'Grafika: -> Plik:';
	}
	
	return join(', ', @summary);
}

sub initial_cosmetics {
	my ($wikt_lang, $page_text_ref) = @_;
	
	# remove all underscores from audio
	my $repeat=1;
	while ($repeat) {
		$repeat=0;
		while ($$page_text_ref =~ /{{audio([^}]+)}}/igc) {
			my $inside = $1;
			if ($inside =~ /_/) {
				my $changed = $inside;
				$changed =~ s/_/ /g;
				$inside =~ s/(\[|\||\(|\))/\\$1/g;
				$$page_text_ref =~ s/$inside/$changed/g;
				$repeat = 1;
			}
		}
	}
	
	if ($wikt_lang eq 'de') {
		return initial_cosmetics_dewikt($page_text_ref);
	} elsif ($wikt_lang eq 'en') {
		return initial_cosmetics_enwikt($page_text_ref);
	} elsif ($wikt_lang eq 'pl') {
		return initial_cosmetics_plwikt($page_text_ref);
	} else {
		die "Wiktionary $wikt_lang not supported";
	}
}

sub final_cosmetics_dewikt {
	my $page_text_ref = shift;
	my @summary;
	
	if ($$page_text_ref =~ s/(:\[\[Hilfe:Hörbeispiele\|Hörbeispiele\]\].*)(\n|\r|\f)(:\[\[Hilfe:IPA\|IPA\]\].*)/$3$2$1/g) {
		push @summary, 'korr. Reihenfolge von IPA und Hörbeispielen';
	}
	
	return join(', ', @summary);
}

sub final_cosmetics_enwikt {
	return '';
}

sub final_cosmetics_plwikt {
	my $page_text_ref = shift;
	my @summary;
	
	if ($$page_text_ref =~ s/----(\n|\r|\f)//g) {
		push @summary, 'usun. poziomej linii';
	}
	
	if ($$page_text_ref =~ s/{{zobtlum/{{zobtłum/g) {
		push @summary, 'popr. zobtłum';
	}
	
	if ($$page_text_ref =~ s/ ''(w|f|m|n)''( *$| \(|,|;)/ {{$1}}$2/g) {
		push @summary, 'popr. rodzajników';
	}
	
	if ($$page_text_ref =~ s/(\n|\r|\f){3,}/$1$1/g) {
		push @summary, 'usun. pustych linii';
	}
	$$page_text_ref =~ s/(\n|\r|\f){2}\{\{wymowa\}\}/$1\{\{wymowa}}/g;
	if ($$page_text_ref =~ s/ {2,}/ /g) { # remove double spaces
		push @summary, 'usun. podw. spacji';
	}
	
	my ($before,$after) = split_before_sections($$page_text_ref);
	
	if ($before =~ s/('{2,3})?(z|Z)obacz (też|także|tez):?\s*('{2,3})?\s*\[\[([^\]]+)\]\]\s*\n/{{zobteż|$5}}\n/) {
		push @summary, 'popr. zobteż';
	}
	$before =~ s/(\n|\r|\f)+({{zobteż[^}]+}})(\n|\r|\f)+/$1$2$3/;
	$before =~ s/(\n|\r|\f){2,}$/$1/;
	
	$$page_text_ref = $before.$after;
	
	my $fixed_graphics=0;
	while ($$page_text_ref =~ s/(\[\[(?:Grafika|Image|Plik|File):.*)(\n|\r|\f){1,}(==.*)/$3$2$1/g) {
		$fixed_graphics = 1;
	}
	push @summary, 'popr. grafiki przed sekcją' if ($fixed_graphics);
	
	return join(', ', @summary);
}

# Returns: edit summary (may be empty)
sub final_cosmetics {
	my ($wikt_lang, $page_text_ref) = @_;
	
	if ($wikt_lang eq 'de') {
		return final_cosmetics_dewikt($page_text_ref);
	} elsif ($wikt_lang eq 'en') {
		return final_cosmetics_enwikt($page_text_ref);
	} elsif ($wikt_lang eq 'pl') {
		return final_cosmetics_plwikt($page_text_ref);
	} else {
		die "Wiktionary $wikt_lang not supported";
	}
}

# Parameters:
#   $section_ref
#   $inflection - {{lp}} der Bus, Busses, ~, ~; {{lm}} Busse, Busse, Bussen, Busse
#   $word - 'Bus'
#
# Returns:
#   0 if not added
#   1 if added
sub add_inflection_plwikt {
	my ($section_ref, $inflection,$word) = @_;
	unless ($$section_ref =~ /{{odmiana[^}]*}}(.*)/) {
		return (0,'brak sekcji odmiana');
	}
	my $infl_line=$1;
	if ($inflection !~ /\w/ || $infl_line =~ /\w/) {
		return (0,'');
	}
	$$section_ref =~ s/({{odmiana[^}]*}})(.*)/$1 $inflection/;
	
	return (1, "+ odmiana z [[:de:$word|de.wikt]]");
}

# Parameters:
#   $article - full article title
# 
# Returns:
#   true if the article is beyond main namespace
sub should_not_be_in_category_plwikt {
	my ($article) = @_;
	return ($article =~ /^(Dyskusja|Szablon|Kategoria|Wikipedysta|Grafika|Plik|Użytkownik|Aneks|Plwikt)/i);
}

1;