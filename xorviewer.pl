#!/usr/bin/perl
use CGI qw(:standard :cgi-lib);

my $query=new CGI;
my %in;
CGI::ReadParse(\%in);

print "Content-type: text/html; charset=utf-8\n\n";

my $dump=$in{'dump'};
my $pagesize=int($in{'pagesize'} || 1);
my $npages=int($in{'npages'} || 50);
my $pagefrag=64;
my $start=int($in{'start'} || 0);
my $xormode=int($in{'xormode'} || 0);
my $pagestart=int($in{'pagestart'} || 0);
my $xoroffset=int($in{'xoroffset'} || 0);

sub readfile($)
{
  if(open(RFIN,"<$_[0]"))
  {
    my $old=$/;
    undef $/;
    binmode RFIN;
    my $content=<RFIN>;
    $/=$old;
    close RFIN;
    return($content);
  }
  return "";
}
sub sanitizeHTML
{
  my $d=$_[0];
  $d="" if(not defined($d));
  # Guess that it is Latin1:
  $d=~s/&(?![\w]+;)/&amp;/g if(!$_[1]);
  $d=~s/</&lt;/g;
  $d=~s/&nbsp;/&#160;/g;
  $d=~s/'/&apos;/g;
  $d=~s/"/&quot;/g;
  return $d;
}
sub bin2hex($)
{
  my $orig=$_[0];
  my $value="";
  return "" if(!defined($orig) || $orig eq "");
  foreach(0 .. length($orig)-1)
  {
    $value.=sprintf("%02X",unpack("C",substr($orig,$_,1)));
  }
  return $value;
}

sub bin2hexascii($)
{
  my $orig=$_[0];
  my $value="";
  return "" if(!defined($orig) || $orig eq "");
  foreach(0 .. length($orig)-1)
  {
    $value.=sprintf("%02X",unpack("C",substr($orig,$_,1)));
  }
  $value.=" ";
  foreach(0 .. length($orig)-1)
  {
    my $v=unpack("C",substr($orig,$_,1));
    $value.= ($v>=32 && $v<128)?substr($orig,$_,1):"_";
  }

  return $value;
}

if($dump !~ m/\.(dump|dmp|raw|bin|img|decoded|g|m|xor)$/)
{
  print "For security reasons, this hex viewer currently only allows to display .dump and .dmp files.";
  exit;
}

my $xor=readfile("$dump.xor");

my $pagesperblock=($pagesize && length($xor)) ? length($xor)/int($pagesize) : 1;

my $dumpsize=-s $dump;

if(open($IN,"<$dump"))
{
  binmode $IN;
  my $base1="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&xormode=\"+mydivtoggle+\"&xoroffset=".int($xoroffset)."&pagestart=".int($pagestart)."&start=";
  my $base1a="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&xormode=$xormode&xoroffset=".int($xoroffset)."&pagestart=".int($pagestart)."&start=";
  my $left=$base1.($start-($pagefrag>>1));
  my $right=$base1.($start+($pagefrag>>1));
  my $base2="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&xormode=\"+mydivtoggle+\"&xoroffset=".int($xoroffset)."&start=".int($start)."&pagestart=";
  my $up=$base2.($pagestart-1);
  my $down=$base2.($pagestart+1);
  my $pageup=$base2.($pagestart-$pagesperblock);
  my $pagedown=$base2.($pagestart+$pagesperblock);
  my $base3="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&xormode=\"+mydivtogle+\"&start=".int($start)."&pagestart=".int($pagestart)."&xoroffset=";
  my $minus=$base3.($xoroffset-1);
  my $plus=$base3.($xoroffset+1);
  my $toggle="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&xormode=\"+mydivtoggle+\"&xoroffset=".int($xoroffset)."&pagestart=".int($pagestart)."&start=".int($start);
  print <<EOF
<html>
<script>
	var mydivtoggle=$xormode;
	function mytoggle()
	{
	  mydivtoggle=1-mydivtoggle; 
	  document.getElementById('mydiv1').style=mydivtoggle?'position:fixed; opacity:20%; color: red; z-index: 0':'position:fixed; opacity:100%; color: red; z-index: 1'; 
	  document.getElementById('mydiv2').style=mydivtoggle?'position:fixed; opacity:100%; color:darkgreen; z-index: 1':'position:fixed; opacity:20%; color:darkgreen; z-index: 0';
	}
	function mymovefunc(e)
	{
	  var ecode=e.code;
	  if(e.ctrlKey)
	  {
	    if(ecode=='Home')
	    {
	      location.href="$base2";
	    }
	  }
	  else if(ecode=='ArrowRight' || ecode=='KeyD')
	  { 
    	    location.href="$right";
	  }
	  else if(ecode=='ArrowLeft' || ecode=='KeyA')
	  {
	    location.href="$left";
	  }
	  else if(ecode=='ArrowUp' || ecode=='KeyW')
	  {
	    location.href="$up";
	  }
	  else if(ecode=='ArrowDown' || ecode=='KeyS')
	  {
	    location.href="$down";
	  }
	  else if(ecode=='PageUp')
	  {
	    location.href="$pageup";
	  }
	  else if(ecode=='PageDown')
	  {
	    location.href="$pagedown";
	  }
	  else if(ecode=='Home')
	  {
	    location.href="$base1";
	  }
	  else if(ecode=='Comma')
	  {
	    location.href="$plus";
	  }
	  else if(ecode=='Period')
	  {
	    location.href="$minus";
	  }
	  else if(ecode=='Space')
	  {
	    mytoggle();
	  }
	  else
	  {
	    //alert(ecode);
	  }
	}
</script>
<body onkeydown='javscript:mymovefunc(event)'>
EOF
;

print "<div style='position:fixed'>Stats: pagesize:".int($pagesize)." pagesperblock:$pagesperblock".(length($xor)?" xorsize:".length($xor):"")." start:".int($start)." pagestart:".int($pagestart)." block:".int($pagestart/$pagesperblock)."/page:".($pagestart % $pagesperblock)." Total-Blocks:".int($dumpsize/$pagesize/$pagesperblock).(length($xor)?" XOR-Offset:".int($xoroffset):"")."</div><br/>\n";

if(length($xor))
{
print <<EOF
	<input type="button" onclick="javascript:mytoggle();" value='XOR ON/OFF'/>
EOF
;
}

print "<div id='mydiv1' style='".($xormode?'position:fixed; opacity:20%; color: red; z-index: 0':'position:fixed; opacity:100%; color: red; z-index: 1')."'/><pre>";
#print tell($IN)."\n";

my $ret=seek($IN,$pagestart*$pagesize,0);
#print "R:$ret ".($pagestart*$pagesize)."\n";
foreach(0 .. $npages)
{
  my $content="";
  #print tell($IN)."\n";
  read $IN,$content,$pagesize;
  #print tell($IN)."\n";
  print sanitizeHTML(bin2hexascii(substr($content,$start,$pagefrag)))."\n";
}
print "</pre></div>\n";

if(defined($xor))
{
  print "<div id='mydiv2' style='".($xormode?'position:fixed; opacity:100%; color:darkgreen; z-index: 1':'position:fixed; opacity:20%; color:darkgreen; z-index: 0')."'/><pre>";
  my $ret2=seek($IN,$pagestart*$pagesize,0);
  #print "R:$ret2 ".($pagestart*$pagesize)."\n";
  foreach(0 .. $npages)
  {
    my $content="";
    #print tell($IN)."\n";
    read $IN,$content,$pagesize;
    #print tell($IN)."\n";
    my $xorpage=($_+$pagestart+$xoroffset) % $pagesperblock;
    $xorpage=int($xorpage/3) if(($pagestart/$pagesperblock)<207 && $dump=~m/2251-11/);
    print sanitizeHTML(bin2hexascii(substr(($content ^ substr($xor,$xorpage*$pagesize,$pagesize)),$start,$pagefrag)))."\n";
  }
  print "</pre></div>\n";
}



my $casefn=$dump; $casefn=~s/[^\/\\]*$/download.case/;
if(open CASE,"<$casefn")
{
  print "<table align='right'><tr><th>Page structure</th></tr>";
  my $count=0;
  while(<CASE>)
  {
    if(m/<Record StructureDefinitionName="([^"]+)" StartAddress="(\d+)" StopAddress="(\d+)"/)
    {
      $count++;
      my $a=($2<=$start && $start <=$3)?1:0;
      print "<tr><td>$count <a href='$base1a$2'>".($a?"<b>":"").sanitizeHTML($1).($a?"</b>":"")."</a></td></tr>";
    }
  }
  close CASE;
  print "</table>";
}

print "</body>\n";



}
else
{
  print "Could not open dump file: ".sanitizeHTML($!)."<br/>\n";
}
