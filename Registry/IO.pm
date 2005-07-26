package Win32::Registry;
#version 0.00.28

$Win32::Registry::IO_loaded=1;

use Cwd;

sub Save
{
 my $self=shift;$self=Open($self) unless ref($self) eq 'Win32::Registry';
 my $Result;

 if($#_ != 0 ){
  die 'usage: Save( $FileName )';
 }

 my $FileName = $_[0];


 if (Win32::IsWin95) { # This workaround wouldn't be necessary if Microsloths did their job.
    my ($dir,$name);
    $FileName =~ m#^(.*)[\\/](.*?)$#
     and
     ($dir,$name) = ($1,$2)
     or ($dir,$name) = (getcwd(),$FileName);
    unless (-d $dir) {
        $! = 2;
        return undef;
    }
    $dir = Win32::GetShortPathName $dir;
    if ($name =~ /^[^\.]{0,8}(\.[^\.]{0,3})?$/) {
#        $Result=RegSaveKey( $self->{'handle'},$dir.'\\'.$name );
         eval "use Win32::API";
         my $RegSaveKey = new Win32::API('advapi32', 'RegSaveKey', ['L','P','P'],'L')
          or return;
         my $file = $dir.'\\'.$name."\0";
         $Result =  ($RegSaveKey->Call( $self->{'handle'}, $file, 0) == 0);

    } else {
        my ($shortname,$ext) = $name =~ /^([^\.]{0,8})[^\.]*(\..{0,3})?.*$/;
        while (-e $dir.'\\'.$shortname.$ext) {$shortname++}
        $Result=RegSaveKey( $self->{'handle'},$dir.'\\'.$shortname.$ext )
        and rename $dir.'\\'.$shortname.$ext, $dir.'\\'.$name;
    }

 } else {

    $Result=RegSaveKey( $self->{'handle'},$FileName );

 }


 if( !$Result){
  $!=Win32::GetLastError();
 }

 return($Result);
}

sub Load
{
 my $self = shift;$self=Open($self) unless ref($self) eq 'Win32::Registry';
 my $Result;
 if($#_ != 1 and $#_ != 2 ){
  die 'usage: Load( $SubKey, $FileName [,  REG_LOADPERSISTENT | REG_LOADTEMPORARY ] )';
 }

 my ($SubKey,$FileName) = @_;

 if (Win32::IsWin95) {
  $FileName =  Win32::GetShortPathName $FileName ;
  eval "use Win32::API";
  my $RegLoadKey = new Win32::API('advapi32', 'RegLoadKey', ['L','P','P'],'L')
   or return;

  $FileName .= "\0";
  $SubKey .= "\0";

  $Result =  ($RegLoadKey->Call( $self->{'handle'}, $SubKey, $FileName) == 0);

 } else {
  $Result=RegLoadKey( $self->{'handle'},$SubKey,$FileName);
 }


 if( !$Result){
  $!=Win32::GetLastError();
 } elsif ($_[2] == REG_LOADTEMPORARY) {
  $::Win32_Registry_loaded_keys{$self->Root.'\\'.$SubKey}=1;
 }

 return($Result);
}

*Unload=\&UnLoad;
sub UnLoad
{
 my $self = shift;$self=Open($self) unless ref($self) eq 'Win32::Registry';
 my $Result;
 if($#_ != 0 ){
  die 'usage: UnLoad( $SubKey)';
 }

 my $SubKey = $_[0];


 $Result=RegUnLoadKey( $self->{'handle'},$SubKey);


 if( !$Result){
  $!=Win32::GetLastError();
 } else {

  delete $::Win32_Registry_loaded_keys{$self->Root . '\\' . $SubKey};
 }

 return($Result);
}

sub printKey {
	my $hkey = $_[0];
	my $root = $hkey->Root;
	$root =~ s/\\\\.*?\\//;
	print "[",$root,$hkey->Path,"]\n";

	my $i=0;

	my ($name, $type, $value);
    while (
		RegEnumValue( $hkey->{'handle'}, $i++,$name, &NULL, $type, $value)
	) {
		my $sname;
		if ($name) {
			$sname = '"'.$name.'"'
		} else {
			$sname = '@'
		}

		if ($type == &REG_SZ) {

			$value =~ s/\\/\\\\/g;
			$value =~ s/"/\\"/g;
			print( qq{$sname="$value"\n}, );

		} elsif ($type == &REG_DWORD) {

			printf( qq{$sname=dword:%08x\n}, $value);

		} elsif ($type == &REG_BINARY) {

			my $data = unpack('H*', $value);
			$data =~ s/(..)/$1,/g;chop($data);
			$data = "$sname=hex:" . $data;
			$data =~ s/(.{74,76},)/$1\\\n  /g;
			print $data,"\n";

		} else {

			my $data = unpack('H*', $value);
			$data =~ s/(..)/$1,/g;chop($data);
			$data = "$sname=hex($type):" . $data;
			$data =~ s/((?:^..|).{74,76},)/$1\\\n  /g;
			print $data;
			print ",00";# if $type == 7; #&REG_EXPAND_SZ;
			print "\n";


		}
	}
	print "\n";
}


sub Export {
    my $self = shift;$self=Open($self) unless ref($self) eq 'Win32::Registry';

    my ($file,$cont) = @_;
    my $hndl;
    $cont=0 unless defined $cont;
	local *REG;
    if (defined $file) {
     $file = '>'.$file if $cont; # append if continuing
     open REG, ">$file" or return undef;
     $hndl = select REG;
    }
    print "REGEDIT4\n" unless $cont;
    print "\n";

    $self->printKey();
    $self->FindKey(\&printKey);

    if (defined $file) {
     select $hndl;
     close REG;
    }
}

{
package Win32::Registry::IO::Scalar;
sub TIEHANDLE {
    my $self = [split "\r?\n", $_[1]];
    bless $self, $_[0];
}
sub READLINE  {
 if (wantarray) {
  my $self = $_[0];
  undef $_[0];
  @$self;
 } else {
  shift(@{shift()})
 }
}
sub close { undef $_[0]; 1;}
*CLOSE = \&close;
*DESTROY = \&close;
}

sub ImportStr {
    my $self = (ref $_[0] eq 'Win32::Registry' ? shift : $Win32::Registry::HKLM);
    my $str = shift or return undef;
    $self->Import( \$str, @_);
}

sub Import {
    my $self = (ref $_[0] eq 'Win32::Registry' ? shift : $Win32::Registry::HKLM);

    my ($file,$keyfun,$valuefun) = @_;

    @_ = ();

	local *REG;
    if (ref $file) {
        tie *REG, 'Win32::Registry::IO::Scalar', $$file;
    } else {
        open REG, "<$file" or return undef;
    }

#    if (<REG> ne "REGEDIT4\n" or <REG> ne "\n") {return undef}

    my $key;
    while (<REG>) {

        (/^REGEDIT4$/ or /^$/) and next;
        /\[(.*)\]/ and $key = $1;

        if ($keyfun) {
            $key = &$keyfun($key);
            unless ($key) {
                while (defined($_ = <REG>) and $_ ne "\n"){};
                next;
            }
        }
        my ($reg, $name, $type, $value);
        $reg = $self->Open($key)
        or
        $reg = $self->Create($key)
        or
        return undef;
        while (defined($_ = <REG>) and $_ ne "\n") {
            s/^\s*(?:"(.*?)"|\@)=// or return undef;
            $name = $1 || '';
            if (/^"(.*)"$/) {
                $type = &REG_SZ;
                $value = $1;
                $value =~ s/\\(["\\])/$1/g;
            } elsif (/^dword:([\da-fA-F]+)$/) {
                $type = &REG_DWORD;
                $value = hex($1);
            } elsif (/^hex(?:\(([\da-fA-F]+)\))?:(.*)$/) {
                $type = $1 || &REG_BINARY;
                $value = $2;
                $value =~ s/,//g;
                while ($value =~ /\\$/) {
                    chop $value;
                    $_ = <REG>;chomp;
                    s/[ ,]//g;
                    $value.=$_;
                }
                $value = pack('H*',$value);
                chop $value if ($type != &REG_BINARY);
            }
            next if ($valuefun and !(&$valuefun($name,$type,$value,$key,$reg)));
            $reg->SetValues($name,$type,$value)
        }
    }
    close REG;
    return 1;
}

1;

