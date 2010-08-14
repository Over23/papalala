# Based on: http://pbot2-pl.googlecode.com/svn/trunk/modules/ideone.pl
# That script also has some extensive semi-interactive editing support
# dropped from here.

use strict;
use warnings;
use feature qw(switch);

use Irssi;
use SOAP::Lite;
$SOAP::Constants::DO_NOT_USE_XML_PARSER = 1;
use IPC::Open2;
use HTML::Entities;
use Text::Balanced qw(extract_codeblock extract_delimited);

use vars qw($VERSION %IRSSI);

$VERSION = '0.01';
%IRSSI = (
    authors     => 'pragma_, Petr Baudis',
    name        => 'ideone',
    description => 'ideone IRC frontend for interactive compiling of code snippets',
    license     => 'BSD',
);


our $emsg;

our %languages = (
  'Ada'                          => { 'id' =>    '7', 'name' => 'Ada (gnat-4.3.2)'                                 },
  'asm'                          => { 'id' =>   '13', 'name' => 'Assembler (nasm-2.07)'                            },
  'nasm'                         => { 'id' =>   '13', 'name' => 'Assembler (nasm-2.07)'                            },
  'Assembler'                    => { 'id' =>   '13', 'name' => 'Assembler (nasm-2.07)'                            },
  'Assembler'                    => { 'id' =>   '13', 'name' => 'Assembler (nasm-2.07)'                            },
  'gawk'                         => { 'id' =>  '104', 'name' => 'AWK (gawk) (gawk-3.1.6)'                          },
  'mawk'                         => { 'id' =>  '105', 'name' => 'AWK (mawk) (mawk-1.3.3)'                          },
  'Bash'                         => { 'id' =>   '28', 'name' => 'Bash (bash 4.0.35)'                               },
  'bc'                           => { 'id' =>  '110', 'name' => 'bc (bc-1.06.95)'                                  },
  'Brainfuck'                    => { 'id' =>   '12', 'name' => 'Brainf**k (bff-1.0.3.1)'                          },
  'bf'                           => { 'id' =>   '12', 'name' => 'Brainf**k (bff-1.0.3.1)'                          },
  'gnu89'                        => { 'id' =>   '11', 'name' => 'C (gcc-4.3.4)'                                    },
  'C89'                          => { 'id' =>   '11', 'name' => 'C (gcc-4.3.4)'                                    },
  'C'                            => { 'id' =>   '11', 'name' => 'C (gcc-4.3.4)'                                    },
  'C#'                           => { 'id' =>   '27', 'name' => 'C# (gmcs 2.0.1)'                                  },
  'C++'                          => { 'id' =>    '1', 'name' => 'C++ (gcc-4.3.4)'                                  },
  'C99'                          => { 'id' =>   '34', 'name' => 'C99 strict (gcc-4.3.4)'                           },
  'CLIPS'                        => { 'id' =>   '14', 'name' => 'CLIPS (clips 6.24)'                               },
  'Clojure'                      => { 'id' =>  '111', 'name' => 'Clojure (clojure 1.1.0)'                          },
  'COBOL'                        => { 'id' =>  '118', 'name' => 'COBOL (open-cobol-1.0)'                           },
  'COBOL85'                      => { 'id' =>  '106', 'name' => 'COBOL 85 (tinycobol-0.65.9)'                      },
  'clisp'                        => { 'id' =>   '32', 'name' => 'Common Lisp (clisp) (clisp 2.47)'                 },
  'D'                            => { 'id' =>  '102', 'name' => 'D (dmd) (dmd-2.042)'                              },
  'Erlang'                       => { 'id' =>   '36', 'name' => 'Erlang (erl-5.7.3)'                               },
  'Forth'                        => { 'id' =>  '107', 'name' => 'Forth (gforth-0.7.0)'                             },
  'Fortran'                      => { 'id' =>    '5', 'name' => 'Fortran (gfortran-4.3.4)'                         },
  'Go'                           => { 'id' =>  '114', 'name' => 'Go (gc 2010-01-13)'                               },
  'Haskell'                      => { 'id' =>   '21', 'name' => 'Haskell (ghc-6.8.2)'                              },
  'Icon'                         => { 'id' =>   '16', 'name' => 'Icon (iconc 9.4.3)'                               },
  'Intercal'                     => { 'id' =>    '9', 'name' => 'Intercal (c-intercal 28.0-r1)'                    },
  'Java'                         => { 'id' =>   '10', 'name' => 'Java (sun-jdk-1.6.0.17)'                          },
  'JS'                           => { 'id' =>   '35', 'name' => 'JavaScript (rhino) (rhino-1.6.5)'                 },
  'JScript'                      => { 'id' =>   '35', 'name' => 'JavaScript (rhino) (rhino-1.6.5)'                 },
  'JavaScript'                   => { 'id' =>   '35', 'name' => 'JavaScript (rhino) (rhino-1.6.5)'                 },
  'JavaScript-rhino'             => { 'id' =>   '35', 'name' => 'JavaScript (rhino) (rhino-1.6.5)'                 },
  'JavaScript-spidermonkey'      => { 'id' =>  '112', 'name' => 'JavaScript (spidermonkey) (spidermonkey-1.7)'     },
  'Lua'                          => { 'id' =>   '26', 'name' => 'Lua (luac 5.1.4)'                                 },
  'Nemerle'                      => { 'id' =>   '30', 'name' => 'Nemerle (ncc 0.9.3)'                              },
  'Nice'                         => { 'id' =>   '25', 'name' => 'Nice (nicec 0.9.6)'                               },
  'Ocaml'                        => { 'id' =>    '8', 'name' => 'Ocaml (ocamlopt 3.10.2)'                          },
  'Pascal'                       => { 'id' =>   '22', 'name' => 'Pascal (fpc) (fpc 2.2.0)'                         },
  'Pascal-fpc'                   => { 'id' =>   '22', 'name' => 'Pascal (fpc) (fpc 2.2.0)'                         },
  'Pascal-gpc'                   => { 'id' =>    '2', 'name' => 'Pascal (gpc) (gpc 20070904)'                      },
  'Perl'                         => { 'id' =>    '3', 'name' => 'Perl (perl 5.8.8)'                                },
  'PHP'                          => { 'id' =>   '29', 'name' => 'PHP (php 5.2.11)'                                 },
  'Pike'                         => { 'id' =>   '19', 'name' => 'Pike (pike 7.6.86)'                               },
  'Prolog'                       => { 'id' =>  '108', 'name' => 'Prolog (gnu) (gprolog-1.3.1)'                     },
  'Prolog-gnu'                   => { 'id' =>  '108', 'name' => 'Prolog (gnu) (gprolog-1.3.1)'                     },
  'Prolog-swi'                   => { 'id' =>   '15', 'name' => 'Prolog (swi) (swipl 5.6.64)'                      },
  'Python'                       => { 'id' =>    '4', 'name' => 'Python (python 2.6.4)'                            },
  'Python3'                      => { 'id' =>  '116', 'name' => 'Python3 (python-3.1.1)'                           },
  'R'                            => { 'id' =>  '117', 'name' => 'R (R-2.9.2)'                                      },
  'Ruby'                         => { 'id' =>   '17', 'name' => 'Ruby (ruby 1.8.7)'                                },
  'Scala'                        => { 'id' =>   '39', 'name' => 'Scala (Scalac 2.7.7)'                             },
  'Scheme'                       => { 'id' =>   '33', 'name' => 'Scheme (guile) (guile 1.8.5)'                     },
  'Smalltalk'                    => { 'id' =>   '23', 'name' => 'Smalltalk (gst 3.1)'                              },
  'Tcl'                          => { 'id' =>   '38', 'name' => 'Tcl (tclsh 8.5.7)'                                },
  'Unlambda'                     => { 'id' =>  '115', 'name' => 'Unlambda (unlambda-2.0.0)'                        },
  'VB'                           => { 'id' =>  '101', 'name' => 'Visual Basic .NET (mono-2.4.2.3)'                 },
);

# C    11
# C99  34
# C++  1

sub ideone {
	my ($nick, $code) = @_;

	my $user = 'test';
	my $pass = 'test';
	my $soap = SOAP::Lite->new(proxy => 'http://ideone.com/api/1/service');
	my $result;

	my $MAX_UNDO_HISTORY = 100;

	my $output = "";
	my $nooutput = 'No output.';


	my %preludes = ( 
			 '34'  => "#define _GNU_SOURCE 1\n#include <stdbool.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <unistd.h>\n#include <math.h>\n#include <limits.h>\n#include <sys/types.h>\n#include <stdint.h>\n",
			 '11'  => "#define _GNU_SOURCE 1\n#include <stdbool.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <unistd.h>\n#include <math.h>\n#include <limits.h>\n#include <sys/types.h>\n#include <stdint.h>\n",
			 '1'   => "#include <iostream>\n#include <cstdio>\n",
		       );

	if (not $code) {
		return "Usage: cc [-lang=<language> | -nowarn] [-showurl] <code> [-input=<...>] (http://ideone.com/)\n";
	}

	open FILE, ">> ideone_log.txt";
	print FILE "$nick: $code\n";

	my $lang = "C99";
	$lang = $1 if $code =~ s/-lang=([^\b\s]+)//i;
	$lang = "C" if $code =~ s/-nowarn[ings]*//i;

	my $show_link = 0;
	$show_link = 1 if $code =~ s/-showurl//i;

	my $l = (grep { uc $lang eq uc $_ } keys %languages )[0];
	if(not $l) {
		return "$nick: Invalid '$lang'. Supported: ", (join ", ", sort { uc $a cmp uc $b } keys %languages);
	}
	$lang = $l;

	my $input = "";
	$input = $1 if $code =~ s/-input=(.*)$//i;

	$code =~ s/#include <([^>]+)>/\n#include <$1>\n/g;
	$code =~ s/#([^ ]+) (.*?)\\n/\n#$1 $2\n/g;
	$code =~ s/#([\w\d_]+)\\n/\n#$1\n/g;

	my $precode = $preludes{$languages{$lang}{'id'}} // '';
	$precode .= $code;
	$code = '';

	if($languages{$lang}{'id'} == 1 or $languages{$lang}{'id'} == 11 or $languages{$lang}{'id'} == 34) {
		my $has_main = 0;

		my $prelude = '';
		$prelude = "$1$2" if $precode =~ s/^\s*(#.*)(#.*?[>\n])//s;

		while($precode =~ s/([ a-zA-Z0-9_*\[\]]+)\s+([a-zA-Z0-9_*]+)\s*\((.*?)\)\s*({.*)//) {
			my ($ret, $ident, $params, $potential_body) = ($1, $2, $3, $4);

			my @extract = extract_codeblock($potential_body, '{}');
			my $body;
			if(not defined $extract[0]) {
				$output .= "error: unmatched brackets for function '$ident';\n";
				$body = $extract[1];
			} else {
				$body = $extract[0];
				$precode .= $extract[1];
			}
			$code .= "$ret $ident($params) $body\n\n";
			$has_main = 1 if $ident eq 'main';
		}

		$precode =~ s/^\s+//;
		$precode =~ s/\s+$//;

		if(not $has_main) {
			$code = "$prelude\n\n$code\n\nint main(int argc, char **argv) { $precode return 0;}\n";
			$nooutput = "Success [no output].";
		} else {
			$code = "$prelude\n\n$precode\n\n$code\n";
			$nooutput = "No output.";
		}
	} else {
		$code = $precode;
	}

#	if($languages{$lang}{'id'} == 1 or $languages{$lang}{'id'} == 11 or $languages{$lang}{'id'} == 35
#			or $languages{$lang}{'id'} == 27 or $languages{$lang}{'id'} == 10 or $languages{$lang}{'id'} == 34) {
#		$code = pretty($code) 
#	}

	$code =~ s/\\n/\n/g if $languages{$lang}{'id'} == 13 or $languages{$lang}{'id'} == 101;
	$code =~ s/;/\n/g if $languages{$lang}{'id'} == 13;
	$code =~ s/\|n/\n/g;
	$code =~ s/^\s+//;
	$code =~ s/\s+$//;

	$result = get_result($soap->createSubmission($user, $pass, $code, $languages{$lang}{'id'}, $input, 1, 1));
	return $emsg unless defined $result;

	my $url = $result->{link};

# wait for compilation/execution to complete
	while(1) {
	  $result = get_result($soap->getSubmissionStatus($user, $pass, $url));
	  return $emsg unless defined $result;
	  last if $result->{status} == 0;
	  sleep 1;
	}

	$result = get_result($soap->getSubmissionDetails($user, $pass, $url, 0, 0, 1, 1, 1));
	return $emsg unless defined $result;

	my $COMPILER_ERROR = 11;
	my $RUNTIME_ERROR = 12;
	my $TIMELIMIT = 13;
	my $SUCCESSFUL = 15;
	my $MEMORYLIMIT = 17;
	my $ILLEGAL_SYSCALL = 19;
	my $INTERNAL_ERROR = 20;

# signals extracted from ideone.com
	my @signame; $signame[0] = 'SIGZERO'; $signame[1] = 'SIGHUP'; $signame[2] = 'SIGINT'; $signame[3] = 'SIGQUIT'; $signame[4] = 'SIGILL'; $signame[5] = 'SIGTRAP'; $signame[6] = 'SIGABRT'; $signame[7] = 'SIGBUS'; $signame[8] = 'SIGFPE'; $signame[9] = 'SIGKILL'; $signame[10] = 'SIGUSR1'; $signame[11] = 'SIGSEGV'; $signame[12] = 'SIGUSR2'; $signame[13] = 'SIGPIPE'; $signame[14] = 'SIGALRM'; $signame[15] = 'SIGTERM'; $signame[16] = 'SIGSTKFLT'; $signame[17] = 'SIGCHLD'; $signame[18] = 'SIGCONT'; $signame[19] = 'SIGSTOP'; $signame[20] = 'SIGTSTP'; $signame[21] = 'SIGTTIN'; $signame[22] = 'SIGTTOU'; $signame[23] = 'SIGURG'; $signame[24] = 'SIGXCPU'; $signame[25] = 'SIGXFSZ'; $signame[26] = 'SIGVTALRM'; $signame[27] = 'SIGPROF'; $signame[28] = 'SIGWINCH'; $signame[29] = 'SIGIO'; $signame[30] = 'SIGPWR'; $signame[31] = 'SIGSYS'; $signame[32] = 'SIGNUM32'; $signame[33] = 'SIGNUM33'; $signame[34] = 'SIGRTMIN'; $signame[35] = 'SIGNUM35'; $signame[36] = 'SIGNUM36'; $signame[37] = 'SIGNUM37'; $signame[38] = 'SIGNUM38'; $signame[39] = 'SIGNUM39'; $signame[40] = 'SIGNUM40'; $signame[41] = 'SIGNUM41'; $signame[42] = 'SIGNUM42'; $signame[43] = 'SIGNUM43'; $signame[44] = 'SIGNUM44'; $signame[45] = 'SIGNUM45'; $signame[46] = 'SIGNUM46'; $signame[47] = 'SIGNUM47'; $signame[48] = 'SIGNUM48'; $signame[49] = 'SIGNUM49'; $signame[50] = 'SIGNUM50'; $signame[51] = 'SIGNUM51'; $signame[52] = 'SIGNUM52'; $signame[53] = 'SIGNUM53'; $signame[54] = 'SIGNUM54'; $signame[55] = 'SIGNUM55'; $signame[56] = 'SIGNUM56'; $signame[57] = 'SIGNUM57'; $signame[58] = 'SIGNUM58'; $signame[59] = 'SIGNUM59'; $signame[60] = 'SIGNUM60'; $signame[61] = 'SIGNUM61'; $signame[62] = 'SIGNUM62'; $signame[63] = 'SIGNUM63'; $signame[64] = 'SIGRTMAX'; $signame[65] = 'SIGIOT'; $signame[66] = 'SIGCLD'; $signame[67] = 'SIGPOLL'; $signame[68] = 'SIGUNUSED';

	if($result->{result} != $SUCCESSFUL or $languages{$lang}{'id'} == 13) {
		$output .= $result->{cmpinfo};
		$output =~ s/[\n\r]/ /g;
	}

	if($result->{result} == $RUNTIME_ERROR) {
		$output .= "\n[Runtime error]";
		if($result->{signal}) {
			$output .= "\n[Signal: $signame[$result->{signal}] ($result->{signal})]";
		}
	} else {
		if($result->{signal}) {
			$output .= "\n[Exit code: $result->{signal}]";
		}
	}

	if($result->{result} == $TIMELIMIT) {
		$output .= "\n[Time limit exceeded]";
	}

	if($result->{result} == $MEMORYLIMIT) {
		$output .= "\n[Out of memory]";
	}

	if($result->{result} == $ILLEGAL_SYSCALL) {
		$output .= "\n[Disallowed system call]";
	}

	if($result->{result} == $INTERNAL_ERROR) {
		$output .= "\n[Internal error]";
	}

	$output .= "\n" . $result->{stderr};
	$output .= "\n" . $result->{output}; 

	#$output = decode_entities($output);

	$output =~ s/cc1: warnings being treated as errors//;
	$output =~ s/ Line \d+ ://g;
	$output =~ s/ \(first use in this function\)//g;
	$output =~ s/error: \(Each undeclared identifier is reported only once.*?\)//msg;
	$output =~ s/prog\.c[:\d\s]*//g;
	$output =~ s/ld: warning: cannot find entry symbol _start; defaulting to [^ ]+//;
	$output =~ s/error: (.*?) error/error: $1; error/msg;

	my $left_quote = chr(226) . chr(128) . chr(152);
	my $right_quote = chr(226) . chr(128) . chr(153);
	$output =~ s/$left_quote/'/g;
	$output =~ s/$right_quote/'/g;

	$output = $nooutput if $output =~ m/^\s+$/;
	$output =~ s/^\n+//g;
	$output =~ s/\n/ /g;

	print FILE localtime() . "\n";
	print FILE "$nick: [ http://ideone.com/$url ] $output\n\n";
	close FILE;

	if($show_link) {
	  return "$nick: [ http://ideone.com/$url ] $output\n";
	} else {
	  return "$nick: $output\n";
	}

# ---------------------------------------------

	sub get_result {
	  my $result = shift @_;

	  if($result->fault) {
	    $emsg = join ', ', $result->faultcode, $result->faultstring, $result->faultdetail;
	    return undef;
	  } else {
	    if($result->result->{error} ne "OK") {
	      $emsg = $result->result->{error};
	      return undef;
	    } else {
	      return $result->result;
	    }
	  }
	}

	sub pretty {
		my $code = join '', @_;
		my $result;

		my $pid = open2(\*IN, \*OUT, 'astyle -Upf');
		print OUT "$code\n";
		close OUT;
		while(my $line = <IN>) {
			$result .= $line;
		}
		close IN;
		waitpid($pid, 0);
		return $result;
	}

}

sub on_msg {
	my ($server, $message, $nick, $hostmask, $channel) = @_;
	my $cp = Irssi::settings_get_str('bot_cmd_prefix');
	my $isprivate = !defined $channel;
	my $dst = $isprivate ? $nick : $channel;

	return unless $message =~ s/^${cp}cc\b//;

	my $result = ideone($nick, $message);
	$server->send_message($dst, "$result", 0);
}

Irssi::signal_add('message public', 'on_msg');
Irssi::signal_add('message private', 'on_msg');

Irssi::settings_add_str('bot', 'bot_cmd_prefix', '`');
