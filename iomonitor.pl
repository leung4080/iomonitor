#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: iomonitor.pl
#
#        USAGE: ./iomonitor.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: LiangHuiQiang (), Leung4080@gmail.com
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 2014/8/20 13:54:49
#     REVISION: ---
#===============================================================================


use strict;
use warnings;
use utf8;
$ENV{LANG} = 'C';

my $INTERVAL=1;
my $COUNT=10000;

my $INTERVAL_Custom=0;
my $COUNT_Custom=0;

my $USAGE="Usage: $ENV{'PWD'}/$0 {--help| [INTERVAL] [COUNT] }";
my $start_time=time;




#===============================================================================
#  FUNCTION DEFINITIONS
#===============================================================================

sub getKernel_Version{
    open (PIPE, "uname -r|");
    my $result = <PIPE>;
    close (PIPE);
    my $tmp = substr($result,0,6);
    return ($tmp);
}

sub getPROC_LIST{ 

open (PS,"ps -eo pid|");
readline PS;
my @PS_LIST = <PS>;
close (PS);
my $i=0;
my $j=0;
foreach my $PID (@PS_LIST){
        if ( $PID == $$ ) {
          $j = $i;
        }
        $PID = trim($PID);
        $i++;
}
my @k=splice (@PS_LIST,$j,2);
return(@PS_LIST);
}

sub getDATE{
    my($sec,$min,$hour,$day,$mon,$year,$weekday,$yeardate,$savinglightday)= (localtime(time));
    $sec = ($sec < 10)? "0$sec":$sec;
    $min = ($min < 10)? "0$min":$min;
    $hour = ($hour < 10)? "0$hour":$hour;
    $day = ($day < 10)? "0$day":$day;
    $mon = ($mon < 9)? "0".($mon+1):($mon+1);
    $year += 1900;
#my $today = "$day.$mon.$year";
    my $date = "$hour:$min:$sec";
    return ($date);
}

sub format_IO{
  my $X = shift; 
  my $var;
  
  my $BS="b";
  my $MS="Mb";
  my $KS="Kb";

  if ( $X < 1024 ) {
      $var=sprintf("%.2f",$X);
      $var .= $BS;
  }
  elsif ( $X >= 1048576 ) {
      my $tmp=$X/1048576;
      $var=sprintf("%.2f",$tmp);
      $var .= $MS; 
  }
  else { 
    my $tmp=$X/1024;
      $var=sprintf("%.2f",$tmp);
      $var .= $KS; 
  }
  return $var;
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

sub getPROC_IO{
    my $proc_id=$_[0];
    my	$IO_file_name = "/proc/$proc_id/io";		# input file name

    open  my $IO, '<', $IO_file_name
        or return (0,0); 

     my ($READ,$WRITE);
      while (<$IO>){
            if (/^read_bytes/){
                $READ= $_;
                $READ=~ s/[a-z_:]+//;
                $READ=trim($READ);
            }
            if (/^write_bytes/){
                $WRITE= $_;
                $WRITE=~ s/[a-z_:]+//;
                $WRITE=trim($WRITE);
            }
        }

    close  $IO
        or warn "$0 : failed to close input file '$IO_file_name' : $!\n";
    my @tmp=($READ,$WRITE);
    return @tmp;
}
sub getPROC_Args{
    my $proc_id=$_[0];
    my $PS_CMD;
    my	$IO_file_name = "ps -p $proc_id -o args|";		# input file name

    open (my $IO, $IO_file_name)
        or return (0);
    readline $IO;
    $PS_CMD = <$IO>;

    close  $IO
        or return ("[Proc Not exist!]");
    return ($PS_CMD);

}
sub getPROC_Comm{
    my $proc_id=$_[0];
    my $PS_CMD;
    my	$IO_file_name = "ps -p $proc_id -o comm|";		# input file name

    open (my $IO, $IO_file_name)
        or return (0);
    readline $IO;
    $PS_CMD = <$IO>;

    close  $IO
        or return("[Proc Not exist!]");
    $PS_CMD=trim($PS_CMD);
    return ($PS_CMD);

}

sub mesh_array{
    my @array_a=@_[1 .. $_[0]+1];
    my @array_b=@_[$_[0]+2 .. $#_];
    for(my $i=0;$i<=$#array_a;$i++){
        for (my $j=0;$j<=$#array_b;$j++){
            if( $array_a[$i][0] == $array_b[$j][0]){
                $array_a[$i][1] += $array_b[$j][1];
                $array_a[$i][2] += $array_b[$j][2];
                splice @array_b,$j,1;
                last;
            }
        }
    }
    push @array_a,@array_b;
    return (@array_a);


}


#===============================================================================
#  MAIN SCRIPT
#===============================================================================

my $K_Ver=getKernel_Version;
if ( $K_Ver lt "2.6.20" ){
    die ("The Linux kernel Version is $K_Ver ; this script not support! exit;\n");
}


foreach my $var (@ARGV){

    SWITCH:{
        $var =~ /^[0-9]+$/ && do
        {
               
                if( $INTERVAL_Custom == 1 && $COUNT_Custom == 0 ){
                    $COUNT=$var;    
                    $COUNT_Custom=1;
                }
                 if ( $INTERVAL_Custom==0 ){
                    $INTERVAL=$var;
                    $INTERVAL_Custom=1;
                }

        last SWITCH; };
        $var eq "--help"  && do {
            
            print ("$USAGE\n");
            exit;
        
        last SWITCH; };
    }
}




my $Collect_sec="per second";
if ( $INTERVAL > 1 ){
    $Collect_sec="every $INTERVAL seconds";
}

print ("Collect and report Process IO (once $Collect_sec)\n");
print ("Loop : $COUNT\n");
print ("Type [Q] and [Return] to quit when you're done collecting data\n\n");

printf ("%s\t%10s\t%8s\t%8s\t%10s\n\n",getDATE,"PID","Read","Write","COMMAND");


my @haveIO_totle;
my $input;
my $rin = "";
vec($rin,fileno(STDIN),1)=1;

my $index=1;
while ( $index <= $COUNT ) {

    my @proc_list_pre;
    my @proc_list_next;
    my @haveIO_list;
    #print ("$#proc_list\n");
    
    my @proc_list=getPROC_LIST();
    foreach my $PID (@proc_list) {
        my @proc_IO=getPROC_IO($PID);
    
        my @LINE_ARR;
        push @LINE_ARR,$PID;
        push @LINE_ARR,$proc_IO[0];
        push @LINE_ARR,$proc_IO[1];
        push @proc_list_pre,[ @LINE_ARR ];

    }

    sleep($INTERVAL);

    #@proc_list=getPROC_LIST();
    foreach my $PID (@proc_list){
        my @proc_IO=getPROC_IO($PID);
        my @LINE_ARR;
        push @LINE_ARR,$PID;
        push @LINE_ARR,$proc_IO[0];
        push @LINE_ARR,$proc_IO[1];
        push @proc_list_next,[ @LINE_ARR ];
    }

    for ( my $i=0;$i<=$#proc_list_pre;$i++  ) {
        my $PID=$proc_list[$i];
        my $READ;
        my $WRITE;
        if ( $proc_list_next[$i][1] >= $proc_list_pre[$i][1] ) {
            $READ=$proc_list_next[$i][1]-$proc_list_pre[$i][1];
        }
        else {
            $READ=0;
        }

        if ( $proc_list_next[$i][2] >= $proc_list_pre[$i][2] ) {
            $WRITE=$proc_list_next[$i][2]-$proc_list_pre[$i][2];
        }
        else{
            $WRITE=0;
        }
        if ( $WRITE != 0 || $READ != 0){
            my @LINE_ARR;
            push @LINE_ARR,$PID;
            push @LINE_ARR,$READ;
            push @LINE_ARR,$WRITE;
     
            push @haveIO_list,[ @LINE_ARR ];
        }
    }

    for (my $i=0;$i<=$#haveIO_list;$i++){
        $haveIO_list[$i][3]=getPROC_Comm($haveIO_list[$i][0]);
        printf ("%s\t%10s\t%8s\t%8s\t%10s\n",getDATE,"$haveIO_list[$i][0]",format_IO($haveIO_list[$i][1]),format_IO($haveIO_list[$i][2]),getPROC_Args($haveIO_list[$i][0]));
    }
    
    if ( $#haveIO_totle == -1 ) {
        @haveIO_totle=@haveIO_list;
    }else{
        @haveIO_totle=mesh_array($#haveIO_totle,@haveIO_totle,@haveIO_list);
    }
 


    if (select(my $ro=$rin,"","",0)){
        chomp($input=uc(<>));
        $index+=$COUNT if ($input eq "Q");
    }

#print ("$i\n");
    $index++;
 
}

my $now=getDATE();
my $ltime=time-$start_time;
print ("=== USE Times: $ltime sec ===\n");
print ("=== $now ===\n");
my $proc_attr;
 for (my $i=0;$i<=$#haveIO_totle;$i++){
    
     if ( getPROC_Comm($haveIO_totle[$i][0]) eq "[Proc Not exist!]" ){
            $proc_attr="-->This Process has quit!"
     }else{$proc_attr="";}
     printf ("%5s\t%8s\tread size:%10s\twrite size:%10s\t%10s\n","$haveIO_totle[$i][0]",$haveIO_totle[$i][3],format_IO($haveIO_totle[$i][1]),format_IO($haveIO_totle[$i][2]),$proc_attr);
    }


exit;
# print ("THIS PID = $$\n");

