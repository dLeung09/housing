#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

my $input_file = $ARGV[0];
my $file_string;

open(my $fh, '<', $input_file) or die "cannot open file $input_file";
{
    local $/ = undef;
    $file_string = <$fh>;
    close($fh);
}

$file_string =~ s/.*\<form\>(.*?)\<\/form\>.*/$1/s;

my %info_hash;

while ($file_string =~ s/(.*?)\<b\>(.*?)\<\/b\>(.*?)/$1 --- $3/s)
{
    my $address = $2;
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

    $info_hash{"$address"}{'Type'} = $type;
    $info_hash{"$address"}{'Rent'} = $rent;
    $info_hash{"$address"}{'NumRooms'} = $numRooms;
    $info_hash{"$address"}{'DateAvail'} = $dateAvailable;

    # Make into a hash?
    $info_hash{"$address"}{'Contact'} = $contact;
}

#print Dumper(\%info_hash);

my $index = 1;

print "Entry:\tAddress\tType\tRent\tNumber of Rooms\tDate Available\tContact\n";

for my $address (keys(%info_hash))
{
    print "$index:\t$address\t$info_hash{$address}{'Type'}\t$info_hash{$address}{'Rent'}\t$info_hash{$address}{'NumRooms'}\t$info_hash{$address}{'DateAvail'}\t$info_hash{$address}{'Contact'}\n";

    $index++;
}

#print $file_string;
