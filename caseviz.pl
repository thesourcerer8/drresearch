#!/usr/bin/perl -w


open IN,"<".$ARGV[0];
open OUT,">".$ARGV[1];

print OUT '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1000" height="900" viewBox="-50 -50 800 700">';

print OUT <<EOF
<style type="text/css">
 <![CDATA[
rect {
  stroke: #306f91;
  stroke-width: 1;
  fill: none;
  }
line {
  stroke: #306f91;
  stroke-width: 1;
  fill: #dfac20;
  }
text {
  font-size: 9px;
  fonf-face: Verdana;
  stroke-width: 1;
  text-anchor: middle;
  fill: #2f2c20;
  }

 ]]>
</style>
EOF
;


my $objx=0;
my $objy=0;
my $objid=0;
my %xpos=();
my %ypos=();
my $width=45;
my $spacing=5;

while(<IN>)
{
  if(m/<Node ClassName="(\w+)" Identificator="(\d+)" X="(-?\d+)" Y="(-?\d+)">/)
  {
    my $type=$1; $objid=$2; $objx=$3; $objy=$4;
    $ypos{'In'}=$4;
    $ypos{'Out'}=$4;
    my $tx=($objx+$width/2);

    $type=~s/DumpProviderControl//; $type=~s/ProviderControl//; $type=~s/ShadowCopy/<tspan x='$tx' >Shadow<\/tspan><tspan x='$tx' dy='1em'>Copy<\/tspan>/;
    print OUT "<rect x='$objx' y='$objy' width='$width' height='$width' fill='blue' rx='2' ry='2'/>\n";
    print OUT "<text x='$tx' y='".($objy+$width/2)."'>$type</text>\n";

  }
  elsif(m/<Node>/)
  {
    print "NOT PARSED: $_\n";
  }
  elsif(m/<Connector Name="([^"]*)" Direction="(Out|In)" ID="([\w\-]+)" \/>/)
  {
    #print "Connector name:$1 dir:$2 id:$3\n";	  
    my $x=$objx+($2 eq "Out"?$width:0);
    $xpos{$3}=$x;
    $ypos{$2}+=$spacing;
    $ypos{$3}=$ypos{$2};

  }
  elsif(m/<Edge HeadConnectorGuid="([\w\-]+)" TailConnectorGuid="([\w\-]+)" \/>/)
  {
    print OUT "<line x1='$xpos{$1}' y1='$ypos{$1}' x2='$xpos{$2}' y2='$ypos{$2}'/>\n";
  }


}

print OUT "</svg>";
