#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

# GLOBAL VARIABLES
##################


# MAIN CODE
############

#{
#}

# SUBROUTINES
##############

#sub checkArgs
#{
#}

#sub readFile
#{
#}

#sub buildHashTable
#{
#}

#sub saveToFile
#{
#}

my $input_file = $ARGV[0];
my $output_file = $ARGV[1];
my $file_string;

open(my $fh, '<', $input_file) or die "cannot open file $input_file";
{
    local $/ = undef;
    $file_string = <$fh>;
    close($fh);
}

$file_string =~ s/.*\<form\>(.*?)\<\/form\>.*/$1/s;

my %info_hash;
my @addresses;

my $index = 1;

while ($file_string =~ s/(.*?)\<b\>(.*?)\<\/b\>(.*?)/$1 --- $3/s)
{
    my $address = $2;
    push @addresses, $address;
    my $type;
    my $rent;
    my $numRooms;
    my $dateAvailable;
    my $contact;

    $file_string =~ s/(.*?)\<strong\>Type\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;

    $type = $2;

    $file_string =~ s/(.*?)\<strong\>Rent\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;

    $rent = $2;

    $file_string =~ s/(.*?)\<strong\>Bedrooms\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;

    $numRooms = $2;

    $file_string =~ s/(.*?)\<strong\>Available\<\/strong\>:\s*(.*?)\<br \/\>(.*?)/$1 --- $3/s;

    $dateAvailable = $2;

    $file_string =~ s/(.*?)\<strong\>Contact\<\/strong\>:\s*(.*?)\s*\<\/div\>(.*?)/$1 --- $3/s;

    $contact = $2;

    #print "$address\n\t$type\n\t$rent\n\t$numRooms\n\t$dateAvailable\n\t$contact\n";

    $info_hash{$index}{'Address'} = $address;
    $info_hash{$index}{'Type'} = $type;
    $info_hash{$index}{'Rent'} = $rent;
    $info_hash{$index}{'NumRooms'} = $numRooms;
    $info_hash{$index}{'DateAvail'} = $dateAvailable;

    # Make into a hash?
    $info_hash{$index}{'Contact'} = $contact;

    $index++;
}

#print Dumper(\@addresses);

#print Dumper(\%info_hash);

my $num = 1;

open(my $file, '>', $output_file) or die "cannot open file $output_file";
{
    printf $file "%-5s %-50s%-10s%-10s%-16s%-19s%-50s\n", 'Entry', 'Address', 'Type', 'Rent', 'Number of Rooms', 'Date Available', 'Contact';
    printf $file "----------------------------------------------------------------------------------------------------------------------------------------------------------------\n";

    for my $index (sort keys(%info_hash))
    {
        printf $file "%4s: %-50s%-10s%-10s%-16s%-19s%-50s\n", $num, $info_hash{$index}{'Address'}, $info_hash{$index}{'Type'}, $info_hash{$index}{'Rent'}, $info_hash{$index}{'NumRooms'}, $info_hash{$index}{'DateAvail'}, $info_hash{$index}{'Contact'};

        $num++;
    }
    close $file;
}

#print $file_string;
