#!/usr/bin/perl
use strict;
use utf8;
use AnyEvent;
use AnyEvent::Log;

package ChildProcess;

sub run {
    my (%args) = @_;
    my $cmd = $args{cmd} || die "missing cmd";
    my $env = $args{env} || {};
    my $cb = $args{cb};
    my $bytes_per_read = $args{bytes_per_read} || 1024;
    my $timeout = $args{timeout} || 10;

    # Create pipes for stdin, stdout and stderr
    pipe my $child_in_fh, my $in_fh or die;
    pipe my $out_fh, my $child_out_fh or die;
    pipe my $err_fh, my $child_err_fh or die;

    my $pid = fork;
    die "fork() failed: $!" unless defined $pid;
    if (! $pid) {
        # Child process. Set env variables:
        foreach my $key (keys %$env) {
            if (defined $env->{$key}) {
                $ENV{$key} = $env->{$key};
            } else {
                delete $ENV{$key};
            }
        }
        # Connect pipes to the standard input and output
        open(STDIN, "<&=" . fileno($child_in_fh)) or die;
        open(STDOUT, ">&=" . fileno($child_out_fh)) or die;
        open(STDERR, ">&=" . fileno($child_err_fh)) or die;
        # Execute
        if (ref($cmd) eq 'ARRAY') {
            exec { $cmd->[0] } @$cmd;
        } else {
            exec $cmd;
        }
        exit(1);
    }

    # Close stdin and set stdout and stderr for non blocking reads
    close($in_fh);
    $out_fh->blocking(0);
    $err_fh->blocking(0);

    # Create an watcher to buffer all data
    sub buffer_watcher ($) {
        my ($fh) = @_;
        my $watcher;
        my $buffer = '';
        my $read_data = sub {
            while (1) {
                my $chunk;
                my $rc = sysread $fh, $chunk, $bytes_per_read;
                if (!defined $rc) {
                    if (! $!{EAGAIN}) {
                        # That's a real error:
                        AE::log error => $!;
                        $watcher->stop if defined $watcher;
                        undef $watcher;
                    }
                    # Otherwise, just wait another call
                    return undef;
                } elsif ($rc == 0) {
                    # End of file
                    $watcher->stop if defined $watcher;
                    undef $watcher;
                    return $buffer;
                }
                $buffer .= $chunk;
            }
        };
        $watcher = AnyEvent->io(
            fh => $fh,
            poll => 'r',
            cb => $read_data
        );
        return [ $watcher, $read_data ];
    }

    my $out_watcher = buffer_watcher $out_fh;
    my $err_watcher = buffer_watcher $err_fh;

    # Kill process if timeout is exceeded
    my $timeout_watcher; $timeout_watcher = AnyEvent->timer(
        after => $timeout,
        cb => sub {
            kill 'KILL', $pid;
            undef $timeout_watcher;
        });

    # Wait for process to finish (even when killed due to a timeout):
    # This watcher keeps references for all the other watches.
    my $pid_watcher; $pid_watcher = AnyEvent->child(
        pid => $pid,
        cb => sub {
            my ($pid, $status) = @_;
            my @out;
            foreach my $w ($out_watcher, $err_watcher) {
                my $buffer;
                eval {
                    $buffer = @$w[1]->();
                    1;
                } or AE::log error => $!;
                push @out, $buffer;
                undef $w;
            }
            defined $cb and $cb->($pid, $status, @out);
            undef $timeout_watcher;
            undef $pid_watcher;
        });
    return { pid => $pid, watcher => $pid_watcher };
}

1;
