#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

# MAIN CODE
############

{
    my $input_file;
    my $output_file;

    checkArgs(\$input_file, \$output_file);
    my $file_string = ${readFile($input_file)};
    my %info_hash = %{buildHashTable(\$file_string)};
    saveToFile(\$output_file, \%info_hash);
}

# SUBROUTINES
##############

sub checkArgs
{
    my $input_file  = shift;
    my $output_file = shift;

    if (scalar(@ARGV) != 2)
    {
        showHelpAndExit();
    }

    for my $arg (@ARGV)
    {
        showHelpAndExit() if "$arg" eq "--help";
    }

    $$input_file  = $ARGV[0];
    $$output_file = $ARGV[1];
}

sub showHelpAndExit
{
    print "\n";
    print <<EOO;
usage: 
  $0 [--help] <input_file> <output_file>>

where

  <input_file> contains the search results extracted from the Queen's Housing Listing service

  <output_file> is the output (text) file that will contain the properly formatted housing
  information

  --help

EOO
    exit 1;
}

sub readFile
{
    my $input_file = shift;
    my $file_string;

    open(my $fh, '<', $input_file) or die "cannot open file $input_file";
    {
        local $/ = undef;
        $file_string = <$fh>;
        close($fh);
    }

    return \$file_string;
}

sub buildHashTable
{
    my $file_string_ref = shift;
    my %info_hash;
    my $index = 1;

    my $address;
    my $type;
    my $rent;
    my $numRooms;
    my $dateAvailable;
    my $contact;


    # Strip away non-search result data.
    $$file_string_ref =~ s/.*\<form\>(.*?)\<\/form\>.*/$1/s;

    while ($$file_string_ref =~ s/(.*?)\<b\>(.*?)\<\/b\>(.*?)/$1 --- $3/s)
    {
        $address = $2;

        $$file_string_ref =~ s/(.*?)\<strong\>Type\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;
        $type = $2;

        $$file_string_ref =~ s/(.*?)\<strong\>Rent\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;
        $rent = $2;

        $$file_string_ref =~ s/(.*?)\<strong\>Bedrooms\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;
        $numRooms = $2;

        $$file_string_ref =~ s/(.*?)\<strong\>Available\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;
        $dateAvailable = $2;

        $$file_string_ref =~ s/(.*?)\<strong\>Contact\<\/strong\>:\s*(.*?)\s*\<\/div\>(.*?)/$1 --- $3/s;
        $contact = $2;

        $info_hash{$index}{'Address'} = $address;
        $info_hash{$index}{'Type'} = $type;
        $info_hash{$index}{'Rent'} = $rent;
        $info_hash{$index}{'NumRooms'} = $numRooms;
        $info_hash{$index}{'DateAvail'} = $dateAvailable;
        $info_hash{$index}{'Contact'} = $contact;

        $index++;
    }

    return \%info_hash;
}

sub saveToFile
{
    my $output_file = shift;
    my $info_hash_ref = shift;

    my $num = 1;

    my $address;
    my $type;
    my $rent;
    my $num_rooms;
    my $date_avail;
    my $contact;

    open(my $file, '>', $$output_file) or die "cannot open file $$output_file";
    {
        printf $file "%-5s %-50s%-10s%-10s%-16s%-19s%-50s\n", 'Entry', 'Address', 'Type', 'Rent', 'Number of Rooms', 'Date Available', 'Contact';
        printf $file "----------------------------------------------------------------------------------------------------------------------------------------------------------------\n";

        for my $index (sort keys(%$info_hash_ref))
        {
            $address    = $$info_hash_ref{$index}{'Address'};
            $type       = $$info_hash_ref{$index}{'Type'};
            $rent       = $$info_hash_ref{$index}{'Rent'};
            $num_rooms  = $$info_hash_ref{$index}{'NumRooms'};
            $date_avail = $$info_hash_ref{$index}{'DateAvail'};
            $contact    = $$info_hash_ref{$index}{'Contact'};

            printf $file "%4s: %-50s%-10s%-10s%-16s%-19s%-50s\n", $num, $address, $type, $rent, $num_rooms, $date_avail, $contact;

            $num++;
        }
        close $file;
    }
}
