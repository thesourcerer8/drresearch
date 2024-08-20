#!/usr/bin/perl
use CGI qw(:standard :cgi-lib);
use MIME::Base64 qw(encode_base64);
use GD;

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

my $displayhex=1;

if($xormode & 2)
{
  $pagefrag=168;
  $npages=812;
  $displayhex=0;
}


my $img = new GD::Image($pagefrag*8,$npages);
my $white = $img->colorAllocate(255,255,255);
my $black = $img->colorAllocate(0,0,0);
my $red = $img->colorAllocate(255,0,0);
my $green = $img->colorAllocate(0,255,0);

$img->setAntiAliasedDontBlend($white);
$img->setAntiAliasedDontBlend($black);
$img->setAntiAliasedDontBlend($green);
$img->setAntiAliasedDontBlend($red);
#$img->fill(0,0,$black);

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

my $pagesperblock=int($in{'pagesperblock'} || (($pagesize && length($xor)) ? length($xor)/int($pagesize) : 1));

my $dumpsize=-s $dump;

if(open($IN,"<$dump"))
{
  binmode $IN;
  my $base1="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&pagesperblock=$pagesperblock&xormode=\"+mydivtoggle+\"&xoroffset=".int($xoroffset)."&pagestart=".int($pagestart)."&start=";
  my $stay=$base1.$start;
  my $base1a="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&pagesperblock=$pagesperblock&xormode=$xormode&xoroffset=".int($xoroffset)."&pagestart=".int($pagestart)."&start=";
  my $left=$base1.($start-($pagefrag>>1));
  my $right=$base1.($start+($pagefrag>>1));
  my $base2="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&pagesperblock=$pagesperblock&xormode=\"+mydivtoggle+\"&xoroffset=".int($xoroffset)."&start=".int($start)."&pagestart=";
  my $up=$base2.($pagestart-1);
  my $down=$base2.($pagestart+1);
  my $up2=$base2.($pagestart-$npages);
  my $down2=$base2.($pagestart+$npages);
  my $pageup=$base2.($pagestart-$pagesperblock);
  my $pagedown=$base2.($pagestart+$pagesperblock);
  my $base3="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&pagesperblock=$pagesperblock&xormode=\"+mydivtogle+\"&start=".int($start)."&pagestart=".int($pagestart)."&xoroffset=";
  my $minus=$base3.($xoroffset-1);
  my $plus=$base3.($xoroffset+1);
  my $toggle="?dump=".sanitizeHTML($dump)."&pagesize=".sanitizeHTML($pagesize)."&pagesperblock=$pagesperblock&xormode=\"+mydivtoggle+\"&xoroffset=".int($xoroffset)."&pagestart=".int($pagestart)."&start=".int($start);
  my $tit=sanitizeHTML($dump);
  print <<EOF
<html>
<head><title>$tit</title>
<style>
* {font-family: Verdana; line-height:14px }
pre {font-family: Courier New ; font-size: 13px ; line-height: 14px}
</style>
<script>
	var mydivtoggle=$xormode;
	function mytoggle()
	{
	  mydivtoggle=mydivtoggle ^ 1;
	  document.getElementById('mydiv1').style=mydivtoggle?'position:absolute; opacity:20%; color: red; z-index: 0':'position:absolute; opacity:100%; color: red; z-index: 1';
	  document.getElementById('mydiv2').style=mydivtoggle?'position:absolute; opacity:100%; color:darkgreen; z-index: 1':'position:absolute; opacity:20%; color:darkgreen; z-index: 0';
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
	    else if(ecode=='ArrowUp' || ecode=='KeyW')
	    {
	      location.href="$up2";
	    }
	    else if(ecode=='ArrowDown' || ecode=='KeyS')
	    {
	      location.href="$down2";
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
	  else if(ecode=='Digit1')
	  {
	    mydivtoggle=0;
	    location.href="$stay";
	  }
	  else if(ecode=='Digit2')
	  {
	    mydivtoggle=1;
	    location.href="$stay";
	  }
	  else if(ecode=='Digit3')
	  {
	    mydivtoggle=2;
	    location.href="$stay";
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
  function updatecoords(a)
  {
    document.getElementById('coords').innerHTML='X:'+event.offsetX+' Y:'+event.offsetY;
  }
  function gotocoords()
  {
    location.href="$base2"+($pagestart+event.offsetY);
  }
</script>
</head>
<body onkeydown='javscript:mymovefunc(event)'>
EOF
;

my $casefn=$dump; $casefn=~s/[^\/\\]*$/download.case/;
if(open CASE,"<$casefn")
{
  print "<table align='right' style='line-height:14px'><tr><th>Page structure</th></tr>";
  my $count=0;
  while(<CASE>)
  {
    if(m/<Record StructureDefinitionName="([^"]+)" StartAddress="(\d+)" StopAddress="(\d+)"/)
    {
      $count++;
      my $a=($2<=$start && $start <=$3)?1:0;
      next if($1 eq "Page");
      print "<tr><td>$count <a href='$base1a$2'>".($a?"<b>":"").sanitizeHTML($1).($a?"</b>":"")."</a>";
      my $d=$3-$2+1;
      if($1 eq "DATA" && $d>512)
      {
        foreach(1 .. ($d/512)-1)
	{
          print " <a href='$base1a".($2+$_*512)."'>+$_</a>";
	}
      }
      print "</td></tr>";
    }
  }
  close CASE;
  print "</table>\n";
}


print "<div>Stats: pagesize:".int($pagesize)." pagesperblock:$pagesperblock".(length($xor)?" xorsize:".length($xor):"")." start:".int($start)." pagestart:".int($pagestart)." block:".int($pagestart/$pagesperblock)."/page:".($pagestart % $pagesperblock)." Total-Blocks:".int($dumpsize/$pagesize/$pagesperblock).(length($xor)?" XOR-Offset:".int($xoroffset):"")."</div><br/>\n";

if(length($xor))
{
print <<EOF
	<input type="button" onclick="javascript:mytoggle();" value='XOR ON/OFF'/>
EOF
;
}

print "<div id='mydiv1' style='".(($xormode&1)?'position:absolute; opacity:20%; color: red; z-index: 0':'position:absolute; opacity:100%; color: red; z-index: 1')."'/><br/><br/><br/><pre>";
#print tell($IN)."\n";

my $ret=seek($IN,$pagestart*$pagesize,0);
#print "R:$ret ".($pagestart*$pagesize)."\n";
foreach(0 .. $npages)
{
  my $content="";
  #print tell($IN)."\n";
  read $IN,$content,$pagesize;
  #print tell($IN)."\n";
  my $fragment=substr($content,$start,$pagefrag);
  print sanitizeHTML(bin2hexascii($fragment))."\n" if($displayhex);
  if(!defined($xor))
  {
    foreach my $x(0 .. $pagefrag*8)
    {
      $img->setPixel($x,$_,vec($fragment,$x,1)?$white:$black);
    }
  }
}
print "</pre></div>\n";

if(defined($xor))
{
  print "<div id='mydiv2' style='".(($xormode&1)?'position:absolute; opacity:100%; color:darkgreen; z-index: 1':'position:absolute; opacity:20%; color:darkgreen; z-index: 0')."'/><br/><br/><br/><pre>";
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
    my $plainfragment=substr($content,$start,$pagefrag);
    my $xorfragment=$plainfragment ^ substr($xor,$xorpage*$pagesize+$start,$pagefrag);
    print sanitizeHTML(bin2hexascii($xorfragment))."\n" if($displayhex);
    foreach my $x(0 .. $pagefrag*8)
    {
      $img->setPixel($x,$_,vec($xorfragment,$x,1)?(vec($plainfragment,$x,1)?$white:$green):(vec($plainfragment,$x,1)?$red:$black));
    }

  }
  print "</pre></div>\n";
}

print "Image: ";

print "\n<img src='data:image/png;base64,".encode_base64($img->png)."' style='box-shadow: 0px 0px 2px 2px gold' onmousemove='updatecoords(this); return(true);' onclick='gotocoords(this);')/>";

print "<div id='coords'>...</div>";

print "</body>\n</html>";



}
else
{
  print "Could not open dump file: ".sanitizeHTML($!)."<br/>\n";
}
