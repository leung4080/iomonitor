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
#      CREATED: 2014/8/21 4:53:40
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

my $INTERVAL=1;
my $COUNT=10000;


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

my $today = "$day.$mon.$year";
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

sub getProcIO{
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
sub getPROC_COMM{
    my $proc_id=$_[0];
    my $PS_CMD;
    my	$IO_file_name = "ps -p $proc_id -o args|";		# input file name

    open (my $IO, $IO_file_name)
        or return (0);
    readline $IO;
    $PS_CMD = <$IO>;

    close  $IO
        or warn "$0 : failed to close input file '$IO_file_name' : $!\n";
    return ($PS_CMD);

}


#===============================================================================
#  MAIN SCRIPT
#===============================================================================

my $K_Ver=getKernel_Version;
if ( $K_Ver lt "2.6.20" ){
    die ("The Linux kernel Version is $K_Ver ; this script not support! exit;\n");
}

my $Collect_sec="per second";
if ( $INTERVAL > 1 ){
    $Collect_sec="every $INTERVAL seconds";
}

print ("Collect and report Process IO (once $Collect_sec)\n");
print ("Loop Time : $COUNT\n");
print ("Use 'CTRL-C' when you're done collecting data\n\n");

printf ("%s\t%10s\t%8s\t%8s\t%10s\n\n",getDATE,"PID","Read","Write","COMMAND");

my $i=0;
while ( $i <= $COUNT ) {

my @proc_list=getPROC_LIST();
my @proc_list_pre;
my @proc_list_next;
 foreach my $PID (@proc_list) {
     my @proc_IO=getProcIO($PID);
    
     my @LINE_ARR;
     push @LINE_ARR,$PID;
     push @LINE_ARR,$proc_IO[0];
     push @LINE_ARR,$proc_IO[1];
     #push @LINE_ARR,$CMDLINE; 
     push @proc_list_pre,[ @LINE_ARR ];

 }

 sleep($INTERVAL);

 foreach my $PID (@proc_list){
    my @proc_IO=getProcIO($PID);
    my @LINE_ARR;
    push @LINE_ARR,$PID;
    push @LINE_ARR,$proc_IO[0];
    push @LINE_ARR,$proc_IO[1];
    push @proc_list_next,[ @LINE_ARR ];
 }
 my @proc_list_new;
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
     my @LINE_ARR;
     push @LINE_ARR,$PID;
     push @LINE_ARR,$READ;
     push @LINE_ARR,$WRITE;
     
     push @proc_list_new,[ @LINE_ARR ];
 }
 my @haveIO_list;
    
 for ( my $i=0; $i<=$#proc_list_new  ;$i++  ) {
     if ( $proc_list_new[$i][1] !=0 || $proc_list_new[$i][2] !=0){
         my @LINE_ARR;
         push @LINE_ARR,$proc_list_new[$i][0];
         push @LINE_ARR,format_IO($proc_list_new[$i][1]);
         push @LINE_ARR,format_IO($proc_list_new[$i][2]);
        push @haveIO_list,[ @LINE_ARR ];
     }
 }
 
 for (my $i=0;$i<=$#haveIO_list;$i++){
    printf ("%s\t%10s\t%8s\t%8s\t%10s\n",getDATE,"$haveIO_list[$i][0]","$haveIO_list[$i][1]","$haveIO_list[$i][2]",getPROC_COMM($haveIO_list[$i][0]));
 }

 $i++;
}
# print ("THIS PID = $$\n");

