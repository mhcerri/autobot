#!/usr/bin/perl
use strict;
use utf8;
use AnyEvent;
use AnyEvent::Log;
use File::Spec;

package FileUtils;

sub concat_filename($$) {
	my ($dirpath, $filename) = @_;

	opendir(my $dir, $dirpath) || do {
		AE::log error => "Failed to open directory \"" . $dirpath . "\".";
		return undef;
	};
	my %entries = map { $_ => 1 } readdir($dir);
	if (!defined $entries{$filename}) {
		AE::log error => "Filename \"" . $filename . "\" not found";
		closedir($dir);
		return undef;
	}
	closedir($dir);

	my $filepath = File::Spec->join($dirpath, $filename);
	if (!-f $filepath) {
		AE::log error => "The path \"" . $filepath . "\" is not a file";
		return undef;
	}
	return $filepath;
}

1;
