#!/usr/bin/perl
use strict;

my $usage = <<USAGE;
Usage:
    perl $0 tblastn.format6.tab homolog_proteins.fasta coverage_ratio E_value > homolog_gene_region.tab

For example:
    perl $0 blast.tab homolog.fasta 0.4 1e-9 > homolog_gene_region.tab

USAGE
if (@ARGV == 0){die $usage}

open IN, $ARGV[0] or die $!;
my (%stats);
while (<IN>) {
    chomp;
    @_ = split /\t/;
    $stats{$_[0]}{$_[1]}{"$_[8]\t$_[9]"}{"region"} = "$_[6]\t$_[7]";
    $stats{$_[0]}{$_[1]}{"$_[8]\t$_[9]"}{"evalue"} = "$_[10]";
    $stats{$_[0]}{$_[1]}{"$_[8]\t$_[9]"}{"score"} = "$_[11]";
}
close IN;

open IN, $ARGV[1] or die $!;
my (%protein_length, $protein_ID);
while (<IN>) {
    chomp;
    if (/>(\S+)/) { $protein_ID = $1; }
    else { $protein_length{$protein_ID} += length $_; }
}
close IN;

my %result;
foreach my $query (keys %stats) {
    foreach my $subject (keys %{$stats{$query}}) {
        my @blast_subject_regions = sort {$a <=> $b} keys %{$stats{$query}{$subject}};
        my @split;
        my $firt_subject_regions = shift @blast_subject_regions;
        push @{$split[0]}, $firt_subject_regions;
        my $number = 0;
        my $end = $1 if $firt_subject_regions =~ m/(\d+)/;
        foreach (@blast_subject_regions) {
            if (m/(\d+)/ && (abs($1 - $end)) >= 20000) { $number ++; $end = $1; }
            push @{$split[$number]}, $_;
        }

        foreach (@split) {
            my (@align_protein_region, @evalue, @score, @region);
            foreach (@{$_}) {
                push @region, $_;
                push @align_protein_region, $stats{$query}{$subject}{$_}{"region"};
                push @evalue, $stats{$query}{$subject}{$_}{"evalue"};
                push @score, $stats{$query}{$subject}{$_}{"score"};
            }
            my $align_length = &cover_length(@align_protein_region);
            my $protein_length = $protein_length{$query};
            my $coverage = $align_length / $protein_length;
            my $region = &region(@region);
            @region = sort {$stats{$query}{$subject}{$b}{"score"} <=> $stats{$query}{$subject}{$a}{"score"}} @region;
            $region[0] =~ m/(\d+)\t(\d+)/;
            my $strand = "plus";
            $strand = "minus" if $1 > $2;
            @evalue = sort {$a <=> $b} @evalue;
            @score = sort {$b <=> $a} @score;
            $result{$subject}{$region}{$query}{"coverage"} = $coverage;
            $result{$subject}{$region}{$query}{"evalue"} = $evalue[0];
            $result{$subject}{$region}{$query}{"score"} = $score[0];
            $result{$subject}{$region}{$query}{"strand"} = $strand;
        }
    }
}

my %intergration1;
foreach my $subject (sort keys %result) {
    foreach my $region (sort {$a <=> $b} keys %{$result{$subject}}) {
        foreach my $query (sort keys %{$result{$subject}{$region}}) {
            my $coverage = $result{$subject}{$region}{$query}{"coverage"};
            my $evalue = $result{$subject}{$region}{$query}{"evalue"};
            my $score = $result{$subject}{$region}{$query}{"score"};
            my $strand = $result{$subject}{$region}{$query}{"strand"};
            if ($coverage >= $ARGV[2] && $evalue <= $ARGV[3]) {
                $intergration1{$subject}{$region}{"$query\t$strand\t$coverage\t$evalue\t$score"} = 1;
            }
            #print "$subject\t$region\t$query\t$strand\t$coverage\t$evalue\t$score\n";
        }
    }
}

my %intergration;
foreach my $subject (sort keys %intergration1) {
    my @region = sort {$a <=> $b} keys %{$intergration1{$subject}};

    my %aligments;
    my $first_region = shift @region;
    foreach (keys %{$intergration1{$subject}{$first_region}}) {
        $aligments{$_} = 1;
    }
    my ($start, $end) = ($1, $2) if $first_region =~ m/(\d+)\t(\d+)/;
    foreach my $region (@region) {
        $region =~ m/(\d+)\t(\d+)/;
        if ($1 <= $end) {
            $end = $2 if $end < $2;
            foreach (keys %{$intergration1{$subject}{$region}}) { $aligments{$_} = 1; }
        }
        else {
            my %sort;
            foreach (keys %aligments) {
                m/(\S+)$/;
                $sort{$_} = $1;
            }
            my @aligments =  sort {$sort{$b} <=> $sort{$a}} keys %aligments;
            $intergration{$subject}{"$start\t$end"} = $aligments[0];
            #print "$subject\t$start\t$end\t$aligments[0]\n";
            %aligments = ();
            foreach (keys %{$intergration1{$subject}{$region}}) { $aligments{$_} = 1; }
            ($start, $end) = ($1, $2);
        }
    }
    my %sort;
    foreach (keys %aligments) { m/(\S+)$/; $sort{$_} = $1; }
    my @aligments =  sort {$sort{$b} <=> $sort{$a}} keys %aligments;
    $intergration{$subject}{"$start\t$end"} = $aligments[0];
}

foreach my $subject (sort keys %intergration) {
    foreach (sort {$a <=> $b} keys %{$intergration{$subject}}) {
            print "$subject\t$_\t$intergration{$subject}{$_}\n";
    }
}

sub region {
    my @number;
    foreach (@_) {
        m/(\d+)\t(\d+)/;
        push @number, ($1, $2);
    }
    @number = sort {$a <=> $b} @number;
    my $out = "$number[0]\t$number[-1]";
    return $out;
}

sub cover_length {
    my (%sort1, %sort2);
    foreach (@_) {
        m/(\d+)\t(\d+)/;
        $sort1{$_} = $1;
        $sort2{$_} = $2;
    }
    @_ = sort {$sort1{$a} <=> $sort1{$b} or $sort2{$a} <=> $sort2{$b}} @_;

    my $first_region = shift @_;
    $first_region =~ m/(\d+)\t(\d+)/;
    my ($start, $end) = ($1, $2);
    my $total_length;
    foreach (@_) {
        m/(\d+)\t(\d+)/;
        if ($1 > $end) {
            $total_length += $end - $start + 1;
            ($start, $end) = ($1, $2);
        }
        elsif ($1 <= $end) {
            $end = $2;
        }
    }
    $total_length += $end - $start + 1;
    return $total_length;
}
