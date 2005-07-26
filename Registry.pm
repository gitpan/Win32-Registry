package Win32::Registry;

use strict;
use Carp;

use vars qw'$VERSION $Version';
$Win32::Registry::VERSION = '0.07';

$Win32::Registry2::VERSION='0.00.28'; # to allow me to change the Perl part without recompiling the XS
$Win32::Registry::Version=$Win32::Registry::VERSION.substr($Win32::Registry2::VERSION,4);
######
#Perl Module for Registry Extensions
# This module creates an object oriented interface to the Win32 Registry.
#
# Perl part made by Jan Krynicky <Jenda@Krynicky.cz> based on work by Hip Communications/ActiveWare/ActiveState
#
######

require Exporter;       #to export the constants to the calling space
require DynaLoader;     # to dynaload the module.
use Win32::WinError;    # for windows constants.
use Win32 ();

if (0) {
	require 'Win32/Registry/IO.pm';
	require 'Win32/Registry/Find.pm';
} # this block above is there to let PerlApp, Perl2Exe, PerlCtrl and PAR know I may need those files.

@Win32::Registry::ISA= qw( Exporter DynaLoader );
@Win32::Registry::EXPORT = qw(
 HKEY_LOCAL_MACHINE
 $HKEY_LOCAL_MACHINE
 HKEY_CLASSES_ROOT
 $HKEY_CLASSES_ROOT
 HKEY_USERS
 $HKEY_USERS
 HKEY_CURRENT_USER
 $HKEY_CURRENT_USER

 HKEY_CURRENT_CONFIG
 $HKEY_CURRENT_CONFIG
 HKEY_DYN_DATA
 $HKEY_DYN_DATA
 HKEY_PERFORMANCE_DATA
 $HKEY_PERFORMANCE_DATA
 HKEY_PERFORMANCE_NLSTEXT
 $HKEY_PERFORMANCE_NLSTEXT
 HKEY_PERFORMANCE_TEXT
 $HKEY_PERFORMANCE_TEXT
 $HKLM
 $HKU
 $HKCU
 $HKCR

 KEY_ALL_ACCESS
 KEY_CREATE_LINK
 KEY_CREATE_SUB_KEY
 KEY_ENUMERATE_SUB_KEYS
 KEY_EXECUTE
 KEY_NOTIFY
 KEY_QUERY_VALUE
 KEY_READ
 KEY_SET_VALUE
 KEY_WRITE
 REG_BINARY
 REG_CREATED_NEW_KEY
 REG_DWORD
 REG_DWORD_BIG_ENDIAN
 REG_DWORD_LITTLE_ENDIAN
 REG_EXPAND_SZ
 REG_FULL_RESOURCE_DESCRIPTOR
 REG_LEGAL_CHANGE_FILTER
 REG_LEGAL_OPTION
 REG_LINK
 REG_MULTI_SZ
 REG_NONE
 REG_NOTIFY_CHANGE_ATTRIBUTES
 REG_NOTIFY_CHANGE_LAST_SET
 REG_NOTIFY_CHANGE_NAME
 REG_NOTIFY_CHANGE_SECURITY
 REG_OPENED_EXISTING_KEY
 REG_OPTION_BACKUP_RESTORE
 REG_OPTION_CREATE_LINK
 REG_OPTION_NON_VOLATILE
 REG_OPTION_RESERVED
 REG_OPTION_VOLATILE
 REG_REFRESH_HIVE
 REG_RESOURCE_LIST
 REG_RESOURCE_REQUIREMENTS_LIST
 REG_SZ
 REG_WHOLE_HIVE_VOLATILE
 REG_LOADPERSISTENT
 REG_LOADTEMPORARY
 %RegType
);

@Win32::Registry::EXPORT_OK = qw(
    RegCloseKey
    RegConnectRegistry
    RegCreateKey
    RegCreateKeyEx
    RegDeleteKey
    RegDeleteValue
    RegEnumKey
    RegEnumValue
    RegEnumKeyEx
    RegFlushKey
    RegGetKeySecurity
    RegLoadKey
    RegNotifyChangeKeyValue
    RegOpenKey
    RegOpenKeyEx
    RegQueryInfoKey
    RegQueryValue
    RegQueryValueEx
    RegReplaceKey
    RegRestoreKey
    RegSaveKey
    RegSetKeySecurity
    RegSetValue
    RegSetValueEx
    RegUnLoadKey
);
$Win32::Registry::EXPORT_TAGS{ALL}= \@Win32::Registry::EXPORT_OK;

sub import {
	my( $pkg )= shift;
	if( defined $_[0] and "Win32" eq $_[0] ) {
		Exporter::export( $pkg, "Win32", @Win32::Registry::EXPORT_OK );
		shift;
	}
	if( defined $_[0] and "nothing" eq lc $_[0] ) {
		return 1;
	}
	unshift @_, $pkg;
	goto &Exporter::import;
}

# this hash is used for configuration.
use vars qw(%CFG);

 $CFG{'canonpath'} = 1; # process '.' and '..'
 $CFG{'expand'} = 0; # expand %VARIABLES%

######
# This function loads the constants from the autoloadable module,
# otherwise it tries to find the functions in Win32::Registry::IO and Win32::Registry::Find.

use vars qw($Find_loaded $IO_loaded);
sub AUTOLOAD {
    my($constname);
    ($constname = $Win32::Registry::AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    $!=0;
    my $val = constant($constname, 0);
    if ($! != 0) {
	if ($! =~ /Invalid/) {

        if ((! $Win32::Registry::Find_loaded) and ($Win32::Registry::AUTOLOAD =~ /^Win32::Registry::Find/)) {
            eval "use Win32::Registry::Find;";
            die "use Win32::Registry::Find failed : $@\n" if $@;
            goto &$Win32::Registry::AUTOLOAD;
    	} elsif (! $Win32::Registry::IO_loaded) {
            eval "use Win32::Registry::IO;";
            die "use Win32::Registry::IO failed : $@\n" if $@;
            goto &$Win32::Registry::AUTOLOAD;
    	} else {
    	    my ($package, $file, $line) = caller;
            die "Undefined method/function $constname called at $file:$line! Win32::Registry(tweak $Win32::Registry2::VERSION)\n";
    	}
	} else {

	    my ($pack,$file,$line) = caller;
	    die "Your vendor has not defined Win32::Registry macro $constname, used at $file line $line.";
	}
    }
    eval "sub $Win32::Registry::AUTOLOAD { $val }";
    goto &$Win32::Registry::AUTOLOAD;
}

sub DESTROY {
 my $self=shift;
 return if ! exists $self->{'handle'};
 RegCloseKey($self->{'handle'})
}

sub show_me
{
 my $self=shift;
 print "Hndl: $self->{'handle'}\nRoot: $self->{'root'}\nPath: $self->{'path'}\n";
}

######
# _new is a private constructor, not intended for public use.
#

sub _new
{
 my $self={};
 if ($_[0]){
  $self->{'handle'} = $_[0];
  $self->{'path'} = $_[1];    # the path to this key
  $self->{'root'} = $_[2];    # from this root (HKEY_...), You may then ${$obj->{root}}->...
  $self->{'root_obj'} = $_[3] ? $_[3] : $self;
  bless $self
  }
 else{
   undef($self);
 }
 $self;
}

sub Num2Object {&Win32::Registry::_new};

#define the basic registry objects to be exported.
#these had to be hardwired unfortunately.


# the handles to roots
sub HKEY_CLASSES_ROOT { 0x80000000 };
# and root objects
$Win32::Registry::HKEY_CLASSES_ROOT = _new(HKEY_CLASSES_ROOT,'','HKEY_CLASSES_ROOT');
*main::HKEY_CLASSES_ROOT = \$Win32::Registry::HKEY_CLASSES_ROOT;
$Win32::Registry::HKCR = $Win32::Registry::HKEY_CLASSES_ROOT;

sub HKEY_CURRENT_USER { 0x80000001 };
$Win32::Registry::HKEY_CURRENT_USER = _new(HKEY_CURRENT_USER,'','HKEY_CURRENT_USER');
*main::HKEY_CURRENT_USER = \$Win32::Registry::HKEY_CURRENT_USER;
$Win32::Registry::HKCU = $Win32::Registry::HKEY_CURRENT_USER;

sub HKEY_LOCAL_MACHINE { 0x80000002 };
$Win32::Registry::HKEY_LOCAL_MACHINE = _new(HKEY_LOCAL_MACHINE,'','HKEY_LOCAL_MACHINE');
*main::HKEY_LOCAL_MACHINE = \$Win32::Registry::HKEY_LOCAL_MACHINE;
$Win32::Registry::HKLM = $Win32::Registry::HKEY_LOCAL_MACHINE;

sub HKEY_USERS { 0x80000003 };
$Win32::Registry::HKEY_USERS = _new(HKEY_USERS,'','HKEY_USERS');
*main::HKEY_USERS = \$Win32::Registry::HKEY_USERS;
$Win32::Registry::HKU = $Win32::Registry::HKEY_USERS;

sub HKEY_CURRENT_CONFIG {0x80000005};
$Win32::Registry::HKEY_CURRENT_CONFIG = _new(HKEY_CURRENT_CONFIG, '','HKEY_CURRENT_CONFIG');
*main::HKEY_CURRENT_CONFIG = \$Win32::Registry::HKEY_CURRENT_CONFIG;

sub HKEY_DYN_DATA {0x80000006};
$Win32::Registry::HKEY_DYN_DATA = _new(HKEY_DYN_DATA,'','HKEY_DYN_DATA');
*main::HKEY_DYN_DATA = \$Win32::Registry::HKEY_DYN_DATA;

sub HKEY_PERFORMANCE_DATA {0x80000004};
$Win32::Registry::HKEY_PERFORMANCE_DATA = _new(0x80000004 ,'','HKEY_PERFORMANCE_DATA');
*main::HKEY_PERFORMANCE_DATA = \$Win32::Registry::HKEY_PERFORMANCE_DATA;

sub HKEY_PERFORMANCE_TEXT {0x80000050};
$Win32::Registry::HKEY_PERFORMANCE_TEXT =_new(0x80000050 ,'','HKEY_PERFORMANCE_TEXT');
*main::HKEY_PERFORMANCE_TEXT = \$Win32::Registry::HKEY_PERFORMANCE_TEXT;

sub HKEY_PERFORMANCE_NLSTEXT {0x80000060};
$Win32::Registry::HKEY_PERFORMANCE_NLSTEXT =_new(0x80000060 ,'','HKEY_PERFORMANCE_NLSTEXT');
*main::HKEY_PERFORMANCE_NLSTEXT = \$Win32::Registry::HKEY_PERFORMANCE_NLSTEXT;

%Win32::Registry::RegType = (
  0 => 'REG_NONE',
  1 => 'REG_SZ',
  2 => 'REG_EXPAND_SZ',
  3 => 'REG_BINARY',
  4 => 'REG_DWORD',
  5 => 'REG_DWORD_BIG_ENDIAN',
  6 => 'REG_LINK',
  7 => 'REG_MULTI_SZ',
  8 => 'REG_RESOURCE_LIST',
  9 => 'REG_FULL_RESOURCE_DESCRIPTION',
 10 => 'REG_RESSOURCE_REQUIREMENT_MAP'
);


sub REG_LOADPERSISTENT {0}
sub REG_LOADTEMPORARY  {1}


sub NULL () {undef};


sub Open {push @_,0;goto &_Open}
sub OpenEx {push @_,2;goto &_Open}
sub Create {push @_,1;goto &_Open}
sub CreateEx {push @_,3;goto &_Open}

sub _Open
{
 my $self = (ref $_[0] ne 'Win32::Registry') ? $Win32::Registry::HKLM : shift();

# if( $#_ < 0 or $#_ > 1 ){
#  croak 'Wrong number of arguments!\nusage: [ $SubObjRef = ] $ObjRef->Open( $SubKey [, $SubObjRef ])';
# }

 my $SubKey = shift();
 return $SubKey if ((ref $SubKey and $SubKey->isa('Win32::Registry')));

 if ($SubKey =~ /^\\\\(.*?)\\(.*?)\\(.*)$/) {
no strict 'refs';
  $self = ${uc $2};
use strict 'refs';
  $SubKey = $3;
  $self=$self->Connect($1) or return undef;
 } elsif ($SubKey =~ /^\\(.*)$/) {
  $self=$self->{'root_obj'};
  $SubKey = $1;
 } elsif ($SubKey =~ /^(HKEY_.*?)\\(.*)$/) {
  $SubKey = $2;
no strict 'refs';
  my $hkey = ${uc $1};
use strict 'refs';
  if ($self->Root =~ /^\\\\(.*?)\\/) {
      $self=$hkey->Connect($1) or return undef;
  } else {
    $self = $hkey;
  }
  return $hkey unless $SubKey;
 }

 if ($CFG{canonpath}) {
  $SubKey =~ s/\\\.\\//g;
  $SubKey =~ s/^\.\\//g;
  $SubKey =~ s/\\\.$//g;
  $SubKey =~ s/\\[^\\]+\\\.\.(?:\\|$)/\\/g;
  if ($SubKey =~ /^\.\./) {
     $SubKey = $self->{path}.'\\'.$SubKey;
     $SubKey =~ s/\\[^\\]+\\\.\.(\\|$)/$1/g;
	 $self=$self->{'root_obj'};
	 $SubKey =~ s/^\\//g;
  }
  return $self if ($SubKey eq '.' or $SubKey eq '');
 }

 my ($SubHandle,$SubObj,$Garbage,$Class,$Options,$SAM,$Security,$Disposition);
 if ($_[-1] == 3) {
    ($Class,$Options,$SAM,$Security) = (shift,shift,shift,shift);
 } elsif ($_[-1] == 2) {
    ($Class,$Options,$SAM,$Security) = (undef,undef,shift(),undef);
 }

 unless ($_[-1]==2 and RegOpenKeyEx($self->{'handle'},$SubKey,$Garbage,$SAM,$SubHandle)
         or $_[-1]==1 and RegCreateKey($self->{'handle'},$SubKey,$SubHandle)
         or $_[-1]==3 and RegCreateKeyEx($self->{'handle'},$SubKey,$Garbage,$Class,$Options,$SAM,$Security,$SubHandle,$Disposition)
         or RegOpenKey($self->{'handle'},$SubKey,$SubHandle)
        ) {
  $! = $Win32::Registry::Error = Win32::GetLastError();
  return undef;
 }

 my $SubObjRef = _new( $SubHandle , $self->{'path'} . '\\' . $SubKey, $self->{'root'}, $self->{'root_obj'});
 if ($#_ >= 1) {
  $_[0]=$SubObjRef;
 }
 return $SubObjRef;
}

sub Connect {
  my $self;
  if (ref $_[0]) {
   $self=shift;
  }
  my ($server,$hkey) = @_;
  if (! $server) {
   croak 'usage: $ObjRef = Win32::Registry::Connect( $Server [, $hkey ])',"\n\tor\n",
   '       [$ObjRef = ] $object->Connect( $Server [, $ObjRef])',"\n";
  }
  my ($root,$path,$retobj);

  if (defined $self) {
   $root = $self->{'root'};
   $root =~ s/\\\\.*?\\//;
   if ((uc $root) eq 'HKEY_CLASSES_ROOT') {
      $root = 'HKEY_LOCAL_MACHINE';
      $path = '\SOFTWARE\Classes'. $self->{'path'};
      $hkey = &HKEY_LOCAL_MACHINE;
   } elsif ((uc $root) eq 'HKEY_CURRENT_USER') {
      warn ($Win32::Registry::Error = "It's not possible to connect to remote HKEY_CURRENT_USER!","\n");
      return;
   } else {
no strict 'refs';
     $hkey = &{$self->{root}};
use strict 'refs';
     $path = $self->{path};
   }
  } else {
   $hkey = HKEY_LOCAL_MACHINE unless (defined $hkey and $hkey > 1);
  }

  my $reg;
  Win32::Registry::RegConnectRegistry($server,$hkey,$reg)
   and $root = _new ($reg, '', '\\\\' . $server . '\\' . $root)
  or return undef;

  if ($path) {
   my $obj;
   if ($obj = $root->Open($path)) {
    $_[1] = $obj if @_ == 2 and defined $self;
    return $obj
   } else {
    return undef;
   }
  } else {
   $_[1] = $root if @_ == 2 and defined $self;
   return $root;
  }
}


sub Close
{
 my $self = $_[0];

 if( $#_ != 0 ){
  croak "usage: Close()";
 }

 my $Result;

 if ($Result = RegCloseKey( $self->{'handle'})) {
  undef(%$self);
  undef $_[0];
 } else {
  $! = $Win32::Registry::Error = Win32::GetLastError();
 }

 return($Result);
}

sub SetValues
{
 my $self = shift;$self=Create($self) unless (ref $self and $self->isa('Win32::Registry'));
 my $Result;
 if($#_ % 3 != 2){
  croak "Wrong number of arguments!\nusage: ".'SetValues($ValueName,$Type,$Value [,$ValueName2,$Type2,$Value2 [, ...] ] )';
 }
 my ($SubKey,$type,$value) ;
 my $res;
 @Win32::Registry::Errors=();
 while ( defined($SubKey = shift) and defined($type = shift) and defined($value = shift)) {

     # set the value.
     $Result = RegSetValueEx( $self->{'handle'},$SubKey,NULL,$type,$value);
     if ($Result) {
      $res++;
      push @Win32::Registry::Errors, 0;
     } else {
      my $err = $Win32::Registry::Error = Win32::GetLastError();
      $! = $err;
      push @Win32::Registry::Errors, $err;
     }
 }
 return($res);
}


sub SetValue
{
 my $self = shift;$self=Create($self) unless (ref $self and $self->isa('Win32::Registry'));
 my $Result;
 if($#_ != 2 ){
  croak 'usage: SetValue($SubKey,$Type,$value )';
 }
 my ($SubKey,$type,$value) = @_;
 croak "Win32::Registry::SetValue: the type cannot be null!\n" unless $type;

 # set the value.
 $Result = RegSetValue( $self->{'handle'},$SubKey,$type,$value);

 if(!$Result){
  $! = $Win32::Registry::Error = Win32::GetLastError();
 }

 return($Result);

}


sub SetValueEx
{
 my $self = shift;$self=Create($self) unless (ref $self and $self->isa('Win32::Registry'));
 if($#_ != 3){
  croak 'usage: SetValueEx( $ValueName,$Reserved,$type,$value )';
 }

 my ( $SubKey,$Reserved,$type,$value) =@_;
 my $Result;

 # set the value.
 $Result = RegSetValueEx( $self->{'handle'},$SubKey,$Reserved,$type,$value);

  if(!$Result){
  $! = $Win32::Registry::Error = Win32::GetLastError();
 }

 return($Result);
}


*GetType = \&Win32::Registry::QueryType;
sub QueryType
{
 my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));

 if($#_ < 0 or $#_ > 1 ){
  croak 'usage: QueryType( $SubKey [, $typeref ])';
 }

 #Query the value.
 my ($type,$data);

 return unless (RegQueryValueEx($self->{'handle'}, $_[0], NULL, $type, $data));

 if ($#_ == 1) {
    $_[1]=$type;
    return 1;
 } else {
    return($type);
 }
}

sub GetValue {
	my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));

	if($#_ < 0 or $#_ > 1 ){
		croak 'usage: [ $value = ] GetValue( $SubKey [, $valueref ])';
	}

	my ($type,$data);

	return unless (RegQueryValueEx($self->{'handle'}, $_[0], NULL, $type, $data));
	$data = Win32::ExpandEnvironmentStrings($data)
		if ($CFG{'expand'} and $type == &REG_EXPAND_SZ);

	if ($#_ == 1) {
		$_[1]=$data;
		return 1;
	} else {
		return($data);
	}
}

sub QueryValue {
	my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));

	if($#_ < 0 or $#_ > 1 ){
		croak 'usage: QueryValue( $SubKey [, $valueref ])';
	}

	my $data;
	return unless (RegQueryValue($self->{'handle'}, $_[0], $data));

	if ($#_ == 1) {
		$_[1]=$data;
		return 1;
	} else {
		return($data);
	}
}


sub GetValueEx {&Win32::Registry::QueryValueEx};
sub QueryValueEx {
	my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));

	if($#_ != 0 and $#_ != 2 ){
		croak 'usage: [ ($ValueName, $ValueType, $Value) ] = QueryValueEx( $ValueName [, $ValueType, $Value])';
	}

	#Query the value.
	my ($type,$data);

	unless (RegQueryValueEx($self->{'handle'}, $_[0], NULL, $type, $data)) {
		$! = $Win32::Registry::Error = Win32::GetLastError();
	}
	$data = Win32::ExpandEnvironmentStrings($data)
		if ($CFG{'expand'} and $type == &REG_EXPAND_SZ);

	if ($#_ == 2) {
		$_[1]=$type;$_[2]=$data;
		return 1;
	} else {
		return wantarray ? ($_[0],$type,$data) : $data;
	}
}


sub QueryKey
{
 my $garbage;
 my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));

 if ($#_ == -1) {
  @_=('','','');
 } elsif ($#_ != 2) {
  croak 'usage: QueryKey( $classref, $numberofSubkeys, $numberofVals )';
 }

 if (!RegQueryInfoKey( $self->{'handle'}, $_[0],
     $garbage, $garbage, $_[1],
     $garbage, $garbage, $_[2],
     $garbage, $garbage, $garbage, $garbage)) {
  $! = $Win32::Registry::Error = Win32::GetLastError();
  return undef;
 }
 return( wantarray ? @_ : 1);
}


sub QueryInfoKey
{
 my $garbage;
 my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));

 if ($#_ == -1) {
  @_=('','','','','','','','','','','');
 } elsif ($#_ != 2) {
  croak 'usage: QueryInfoKey( $class, $classsz, $reserved, $numsubkeys,$maxsubkey, $maxclass, $values, $maxvalname, $maxvaldata, $secdesclen,$lastwritetime )';
 }

 if (!RegQueryInfoKey( $self->{'handle'}, $_[0],$_[1],$_[2],$_[3],$_[4],$_[5],$_[6],$_[7],$_[8],$_[9],$_[10])) {
  $! = $Win32::Registry::Error = Win32::GetLastError();
  return undef;
 }
 return( wantarray ? @_ : 1);
}


sub GetKeys {
	my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));
	my $arr;
	if($#_ > 0 ){
		croak 'usage: [(array) = ] $obj->GetKeys( [$arrayref ])';
	}

	if ($#_ == 0) {
		croak "GetKeys requires a list reference as an argument"
		unless (ref $_[0] eq 'ARRAY');
		$arr=$_[0];
	} else {
		$arr=[];
	}

	my ($i,$keyname)=(0,'');

	while( RegEnumKey( $self->{'handle'},$i++, $keyname ) and push( @{$arr}, $keyname )){};

	wantarray and return @$arr
		or return(1);

}

sub ForKeys {
	my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));
	local $_ = $self;
	my $fun = shift;
	if(ref $fun ne 'CODE' ){
		croak 'usage: $obj->ForKeys( \&fun )';
	}

	my ($i,$key) = (0,'');

	while( RegEnumKey( $self->{'handle'},$i++, $key )){
		$_ = $key;
		$fun->($self, $key); # I want to keep them separate, just in case.
	};

	return 1;
}
*ForKey = \&ForKeys;


sub GetValues {
	my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));

	if($#_ != 0){
		croak 'usage: GetValues( $hashref )';
	}

	my ($ValueName,$ValueType,$ValueData);
	my $i=0;
	while( RegEnumValue( $self->{'handle'},
		 $i++,
		 $ValueName,
		 NULL,
		 $ValueType,
		 $ValueData )
	){
		$ValueData = Win32::ExpandEnvironmentStrings($ValueData)
			if ($CFG{'expand'} and $ValueType == &REG_EXPAND_SZ);

		$_[0]->{$ValueName} = [ $ValueName, $ValueType,$ValueData ];
	}

	return(1);
}

sub GetOnlyValues {
	my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));
	my $data=$_[0];
	$self->GetValues(@_) or return;

	my ($key,$value);
	while (($key,$value) = each %$data) {
		$$data{$key}=$$value[2];
	}
	return 1;
}


sub DeleteKey {
	my $self = shift;$self=Open($self) unless ((ref $self and $self->isa('Win32::Registry')));
	my $name = $_[0];$name='' unless defined $name;

	return 1 if RegDeleteKey($self->{'handle'},$name);

	if (defined $_[1] and $_[1] == 1) {
		my $that = $name ? $self->Open($name) : $self;
		return unless $that;
		my ( $classref, $numberofSubkeys, $numberofVals);
		$that->QueryKey( $classref, $numberofSubkeys, $numberofVals );
		return unless $numberofSubkeys;
		my $keyname = '';
		while( RegEnumKey( $that->{'handle'}, 0, $keyname )) {
			$that->DeleteKey($keyname,1) or return;
		};
		if (RegDeleteKey($that->{'handle'},'')) {
			$self->Close() if ($name eq '');
			return 1 ;
		}
	}

	$! = $Win32::Registry::Error = Win32::GetLastError();
	return;
}


*DeleteValues=\&DeleteValue;
sub DeleteValue
{
 my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));
 my $all = $#_ + 1;
 my $num=0;

 if($#_ < 0 ){
  croak 'usage: DeleteValue( $ValueName )';
 }

 my $name;
 while( $name = shift ) {

  RegDeleteValue( $self->{'handle'},$name)
  and $num++;
  if ($self->{'values'}) {
   delete $self->{'values'}->{$name};
  }


 }
 if($all>$num){
  $! = $Win32::Registry::Error = Win32::GetLastError();
 }

 return($num);
}

sub Path{$_[0]->{'path'}}
sub Root{$_[0]->{'root'}}
sub FullPath {$_[0]->{'root'}.$_[0]->{'path'}}

sub MoveKey {
  my($self, $to, $as) = @_;
  $self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));return unless $self;

  my $copy;
  $copy = $self->CopyKey($to, $as)
  and
  $self->DeleteKey(undef, 1)
  and
  $_[0]=$copy;
  return $copy;
}

sub FlushKey {
    my $self = $_[0];
    Win32::Registry::RegFlushKey($self->{'handle'});
}

sub CopyKey {
    my $self = shift;$self=Open($self) unless (ref $self and $self->isa('Win32::Registry'));return unless $self;
    my $to = shift;$to=$self->Open($to.'\.') unless (ref $to and $to->isa('Win32::Registry'));
	croak 'usage: $hkey->CopyKey( $UnderKey [, $as]) or $hkey->CopyKey( $SubkeyName1, $SubkeyName2)'
		unless $to;

	my $as = shift;
	my $self_path = $self->Path();
	if (lc($self_path) eq substr(lc($to->Path()), 0, length($self_path))) {
		# the $to is under $self therefor it's not a key to copy to, but a SubKey to copy
		# $hkey->CopyKey( $SubkeyName1, $SubkeyName2)
		croak 'usage: $hkey->CopyKey( $UnderKey [, $as]) or $hkey->CopyKey( $SubkeyName1, $SubkeyName2)'
			unless $as;
		my $tmp = $to;
		$to = $self->Create($as) or return;
		$self = $tmp;
	} else {
		# $hkey->CopyKey( $otherHkey [, $as])
		unless ($as) {
			$self->Path() =~ /([^\\]+)$/;
			$as = $1;
		}
		$to = $to->Create($as) or return;
	}
    my ($ValueName,$ValueType,$ValueData,$keyname);
    my $i=0;
    while( RegEnumValue( $self->{'handle'},
     $i++,
     $ValueName,
     NULL,
     $ValueType,
     $ValueData )){
        $to->SetValues($ValueName,$ValueType,$ValueData);
    }
    ($i,$keyname)=(0,'');
    while( RegEnumKey( $self->{'handle'},$i++, $keyname ) ){
        eval {
            ($self->Open($keyname))->CopyKey($to)
        };
    };
    return $to;
}

######
# unload the loaded hives and other cleanup

END {
no strict "refs";
    foreach (keys %::Win32_Registry_loaded_keys) {
        my ($root,$key) = /^(.*)\\(.*?)$/o;
        my $reg;
        if ($root =~ /^\\\\(.*)\\(.*)/) {
            $reg = ${$2}->Connect($1);
        } else {
            $reg = ${$root}
        }
        $reg->UnLoad($key) if $reg;

    }
    undef %::Win32_Registry_loaded_keys;
}


######
# load the compiled code

bootstrap Win32::Registry;

# Preloaded methods go here.

#Currently Autoloading is not implemented in Perl for win32
# Autoload methods go after __END__, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Win32::Registry - accessing the Win32 registry

Tweak version 0.00.28.

=head1 SYNOPSIS

 use Win32::Registry;
 print $HKLM->Open('SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Tips')->GetValue('32');

=head1 DESCRIPTION

This module creates an object oriented interface to registry.
It allows you to read&update local as well as remote registry.

Win32::Registry is -w and use strict vars safe. :-)
 (At least it seems to be ;-)
If you find any problems, send me their description and hopefully a fix to Jenda@Krynicky.cz.

      !!! Use with caution !!! Use with caution !!! Use with caution !!!

Editing registry can easily render you computer unusable. If you step over something important ---
happy reinstalling ;-]

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=head2 Base objects

You may use them to ->Open or ->Create subkeys or you may
Connect a remote registry.

The predefined base objects are :

=over 2

=item $HKEY_LOCAL_MACHINE (shortcut = $HKLM)

Informations about the local computer system,
including hardware and OS.

=item $HKEY_CLASSES_ROOT (shortcut = $HKCR)

Object linking and embedding (OLE) and file-class
association data.

=item $HKEY_USERS (shortcut = $HKU)

All actively loaded user profiles, including
HKEY_CURRENT_USER, which always refers to a
child of HKEY_USERS, and the default profile.

=item $HKEY_CURRENT_USER (shortcut = $HKCU)

User profile for the user who is currently logged on,
including environment variables, personal program
groups, desktop settings, network connections,
printers, and application preferences.

=item $HKEY_CURRENT_CONFIG

Points to the current system configuration in the
collection of configurations stored in
Hkey_Local_Machine\Config.

=item $HKEY_DYN_DATA

Handle to informations from the devices currently
installed and loaded, or that failed loading.
This is dynamic information, stored in volatile
memory. Data are updated at startup and whenever
the system configuration is modified. It also
contains some performance data under under
Hkey_Dyn_Data\PerfStats.

=item $HKEY_PERFORMANCE_DATA

=item $HKEY_PERFORMANCE_TEXT

=item $HKEY_PERFORMANCE_NLSTEXT

Handles used to collect performance data with
RegQueryValueEx.
Note that the performance data are not stored in the
Registry database. ReqQueryKeyEx will cause the
system to collect the data.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=back

=head2 Methods and functions

C<Connect>,
C<Open>,
C<OpenEx>,
C<Create>,
C<Close>,
C<Num2Object>

C<GetValue>,
C<GetType>,
C<GetValueEx>,
C<QueryValue>,
C<QueryType>,
C<QueryValueEx>,
C<GetValues>,
C<GetOnlyValues>,
C<GetKeys>

C<DeleteKey>,
C<DeleteValue>,
C<SetValue>,
C<SetValues>,
C<SetValueEx>

C<CopyKey>,
C<MoveKey>

C<FlushKey>,
C<Refresh>,
C<QueryKey>,
C<QueryInfoKey>,
C<Path>,
C<Root>

C<FindKey>,
C<FindKeyDepth>,
C<FindValue>,
C<FindValueDepth>,
C<Load>,
C<Save>,
C<Import>,
C<Export>

Since tweak 0.00.20 you may call most of those methods as ordinary functions while using
registry path as the first argument. Only exceptions are Close(),FlushKey().

=over 2

=item Close

 $obj->Close

Close an open registry key. You should close keys as soon as possible to free
the resources. Object that are being destroyed are automatically closed.
Returns true if successful.


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Connect

 $newobj = Win32::Registry::Connect( $Server [, $hkey ])
 [$newobj = ]$obj->Connect( $Server [, $newobj ])

Connects a remote registry.

If you call it as an ordinary function it connects
the $hkey (NUMERICAL HANDLE!) or HKEY_LOCAL_MACHINE on that machine.

 $newobj = Win32::Registry::Connect($server, &HKEY_USERS);

Since version 0.00.05 you may use any registry object with this method.
It tries to connect $obj->Root on the remote machine and then
->Open the same $obj->Path. If any of these fails you will get an undef.

Ex: $obj = Win32::Registry::Connect( $Server , HKEY_CLASSES_ROOT);
    $obj2 = $HKEY_USERS->Connect( $Server);

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item CopyKey

 $key->CopyKey($to [, $as]);
 Win32::Registry::CopyKey($key, $to [, $as]);
 $key->CopyKey($SubKey1 , $SubKey2);
 Win32::Registry::CopyKey($key, $SubKey1 , $SubKey2);

Copy a $key under $to, possibly with a different name or copy the $SubKey1 as $SubKey2.
You may use this to copy a whole registry key with all subkeys into a different branch.
For example from HKEY_USERS\.DEFAULT to HKEY_CURRENT_USER.

The $key, $to and $SubKey1 may be either paths or registry objects, the $as and $SubKey2 must be key names/paths.
The $to MUST already exist, the copy will be created UNDER this key, it will NOT overwrite it.

 Ex.:
  use Win32::Registry;
  $to = $HKCU->Create('SOFTWARE\Jenda');
  Win32::Registry::CopyKey('HKEY_USERS\.DEFAULT\SOFTWARE\Jenda\ThisScript',$to);

 or

  use Win32::Registry;
  $to = $HKCU->Create('SOFTWARE\Jenda');
  Win32::Registry::CopyKey('HKEY_USERS\.DEFAULT\SOFTWARE\Jenda\ThisScript\'s defaults',$to,'ThisScript');

 or

  use Win32::Registry;
  $HKEY_CLASSES_ROOT->CopyKey( '.pl', '.plx');

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Create

 [ $SubKeyObj = ] $obj->Create("SubKey" [,$SubKeyObj] )
 [ $SubKeyObj = ] Win32::Registry::Create("absolute path","SubKey" [,$SubKeyObj])

Opens a subkey of a Registry object. If it doesn't exist, it gets created. The
created object is returned through the second parameter and as the function
result.

 Eg: $SubKeyObj=$RegObj->Create( "SubKey")
      or die "Cannot create SubKey.\n";
     $RegObj->Create( 'SubKey\SubSubKey',$SubSubKeyObj )
      or die "Cannot create SubKey.\n";
     $Jenda = Win32::Registry::Create('HKEY_LOCAL_MACHINE\SOFTWARE','Jenda');

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item DeleteKey

 $regobj->DeleteKey( "KeyNameToDelete" [, 1]);
 $regobj->DeleteKey();
 Win32::Registry::DeleteKey('HKEY_WHATEVER\path\to\KeyNameToDelete');
 Win32::Registry::DeleteKey('HKEY_WHATEVER\path\to' ,'KeyNameToDelete' [, 1]);

Delete a key from the registry. Returns true if successful.

The optional third parameter allows the function to delete the key recursively.
That is to delete even keys that contain some subkeys.

  Eg: $HKEY_CLASSES_ROOT->DeleteKey( "MyFileType");
      Win32::Registry::DeleteKey('HKEY_CLASSES_ROOT\MyFileType');


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item DeleteValue

 $obj->DeleteValue($ValueName, ...);
 Win32::Registry::DeleteValue('registry path', $ValueName, ...);

Delete a value from the current key

  $reg->DeleteValue( "Name" );
  $reg->DeleteValue( "Name", "Other_Name");

Returns the number of successful deletions and sets $! in case of an error.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Export

 $obj->Export( [$filename, [$continuation]] )

Export the key into a registry script (.REG) file. This method creates
a standard registry script, the same you get when you export a key from
Regedit.exe.

If you do not specify the $filename, the text gets printed to the currently
select()ed filehandle.

If the $continuation is defined, no header is printed out.
You may use this to export several keys into one file.

If you do not want to specify the filename, but need continuation, use
undef() as the $filename.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item FindKey

 $obj->FindKey(\&function [, \&leavefunction])
 $obj->FindKey(\&bool_function,\@array)

Recurses through the subkeys of $obj, similar to File::Find.

If you call this function using the first syntax, it recurses through
the registry and calls &function you passed before precessing each key.
If the &leavefunction is defined, it is being called AFTER processing
the subkeys. The key is passed to &function (or \&leavefunction) as it's
first parameter.

If you use the other form, each time the &bool_function returns
true FindKey pushes the path of the active key to @array.

You may instruct the method to skip processing the subkeys of the current
key by seting $Win32::Registry::Find::skip_subkeys variable to 1 in
the callback function.

 Ex.
  $reg = $HKLM->Open('SOFTWARE\Microsoft\Office');

  # print out all subkeys of HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office
  # and their default values
  sub prt {
   print $_[0]->Path,' = ',$_[0]->GetValue(''),"\n";
   # # or
   # my $self=shift;
   # print $self->Path,' = ',$self->GetValue(''),"\n";
  }
  $reg->FindKey(\&prt);

  # find out what subkeys of HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office
  # have their default value set
  sub dft {
   return $_[0]->GetValue('');
  }
  $reg->FindKey(\&dft,\@arr);
  foreach $key (@arr) {
   print "$key has the default value set.\n"
  }

  sub ExportFoo {
    return unless $Win32::Registry::Find::path =~ /jenda/i;
    $_[0]->Export('c:\temp\Foo.reg', $continued++);
    $Win32::Registry::Find::skip_subkeys = 1;
  }
  $continued=0;
  $HKLM->FindKey(\&ExportFoo);

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item FindKeyDepth

 $obj->FindKeyDepth(\&function)
 $obj->FindKeyDepth(\&bool_function,\@array)

Same as C<FindKey>, but depth first.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item FindValue

 $obj->FindValue(\&function, [, \&KeyEnterFunction [, \&KeyLeaveFunction [, \&SubKeysLeaveFunction]]])

Recurses through the registry, calling &function for every
value found. You may also define functions to be called when

 1. entering the key - &KeyEnterFunction
 2. finished processing the values, but before recursing into subkeys - &KeyLeaveFunction
 3. finished processing all subkeys - &SubKeysLeaveFunction

The &function get's its parameters through global variables :

 Win32::Registry::Find::key - the key in which the value resides
 Win32::Registry::Find::name - the name of the value
 Win32::Registry::Find::type - the type of the value
 Win32::Registry::Find::value - the value

If you set the $Win32::Registry::CFG{'value_objects'} variable,
the &function gets a C<Win32::Registry::Value> object as it's first
parameter.

The other functions get a registry object pointing to the current key
as their first and only argument. Just like in FindKey.

 Ex.
  use Win32::Registry;
  $reg = $HKLM->Open('SOFTWARE\Microsoft\Office');

  sub prt {
   package Win32::Registry::Find;
   if (($type = &REG_SZ or $type = &REG_MULTI_SZ)) {
    print $key->Path," \ $name = $value\n";
   }
   package main;
  }
  $reg->FindValue(\&prt);

 #======================

  $Win32::Registry::CFG{'value_objects'}=1;
  sub foo {
   my $self=shift;
   print $self->Name," : ",$RegType{$self->Type},' : ',$self->Value,"\n";
  }
  $reg->FindValue(\&foo);

 #======================

 sub FooVal {
  if ($Win32::Registry::Find::type == ::REG_BINARY) {
   print "$Win32::Registry::Find::name : ",
    "$Win23::Registry::RegType{$Win32::Registry::Find::type}",
    "($Win32::Registry::Find::type)\n";
  } else {
   print "$Win32::Registry::Find::name : ",
    "$Win23::Registry::RegType{$Win32::Registry::Find::type}",
    "($Win32::Registry::Find::type) = $Win32::Registry::Find::value\n";
  }
 }

 sub inkeyfun   { print "Entering ",$_[0]->Path,"\n"; }

 sub outkeyfun  { print "Finished printing ",$_[0]->Path,"\n"; }

 sub outsubkeys { print "Leaving ",$_[0]->Path,"\n"; }


 $reg = $HKCU->Open('Printers');
 $reg->FindValue(\&::FooVal, \&inkeyfun, \&outkeyfun, \&outsubkeys );


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item FindValueDepth

 $obj->FindValueDepth(\&function)

Recurses through the registry, calling &function for every
value found. Depth first.

See C<FindValue>.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item FlushKey

 $obj->FlushKey()

The FlushKey function writes all the attributes of the specified open
key into the registry.

It is not necessary to call FlushKey to change a key. Registry changes
are flushed to disk by the registry using its lazy flusher. Registry changes
are also flushed to disk at system shutdown.

Unlike C<Close>, the FlushKey function returns only when all the
data has been written to the registry.

The FlushKey function may also write out parts of or all of the other
keys. Calling this function excessively can have a negative effect on an
application's performance.

An application should only call FlushKey if it requires absolute
certainty that registry changes are on disk. In general, FlushKey
rarely, if ever, need be used.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item ForKeys

 $obj->ForKeys(\&fun);
 $obj->ForKeys(sub{...});

Call the specified function/code for each subkey of the current key. The
$obj will be in the first parameter, the name of the subkey the second parameter to the function.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item GetKeys

 $obj->GetKeys(\@ARRAY)
 @ARRAY = $obj->GetKeys()

Get the list of subkeys of current key.
The list must be passed by reference!

In scalar context returns true or false, in array context returns
an array of subkeys.

       foreach $key ($myobj->GetKeys()) {
        ...


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item GetType

Nickname for C<QueryType>

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item GetValue

 $value = $obj->GetValue("value name")
 $obj->GetValue("value name",$value)

This is what Query value should be. It returns the named value from the current key, instead
of the default value of the named subkey.

If you want the default value from the current key use "" as the name.

You should never use QueryValue, it's present only for backwards compatibility with
Win3.x.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item GetValueEx

Nickname for C<QueryValueEx>


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item GetValues

 $obj->GetValues(\%HASH)

GetValues creates a hash containing 'name'=> ( name,type,data )
for each value in the current key.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item GetOnlyValues

 $obj->GetOnlyValues(\%HASH)

Similar to GetValues, the created HASH contains only
the values ($HASH{name} = "value").

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Import

 $obj->Import( $filename [ , \&keyfun [ , \&valuefun ]])
 Win32::Registry::Import( $filename [ , \&keyfun [ , \&valuefun ]])

Imports a registry script (.REG file) into registry. If the $obj points
to a key at a remote computer, the script will be imported into that computer instead
of the local registry.

The optional \&keyfun and \&valuefun parameters give you a way
to control what is imported and where.

The &keyfun gets called for each registry key found in the .REG file.
This function may change the key to where will be the values imported,
the value it returns will be used as the name (path) of the key to save
the values into. This path is relative to the $obj.
If this function returns a false value, the whole key (BUT NOT SUBKEYS!!!) is ignored.
That is, we skip to next key in the .REG file.

The &valuefun (if present) is called for each value imported.
It's prototype is : &valuefun($name,$type,$value,$keypath,$obj)
You may update the $name, $type and $value (that is $_[0],$_[1],$_[2])
if you like, but you should leave $keypath and $obj intact.
If this function returns false, the value is not imported.

 Ex.
  Win32::Registry::Import('c:\temp\Some.reg');
   # import whole c:\temp\Some.reg, to the original place

  $reg = $HKLM->Connect($machinename);
  $reg->Import('c:\temp\Some.reg')
   # import whole c:\temp\Some.reg, to the original place into
   # the remote registry at $machinename

  Win32::Registry::Import('c:\temp\Some.reg', sub {$_[0] =~ /^HKEY_CLASSES_ROOT/});
   # import only the subkeys of HKCR

  Win32::Registry::Import('c:\temp\Some.reg', undef, sub {$_[0] =~ /foo/});
   # import only the values whose names contain string "foo"

  Win32::Registry::Import('c:\temp\Some.reg', undef, sub {$_[0] .= 'foo-'});
   # prepend all the imported values by "foo-"

  Win32::Registry::Import('c:\temp\Some.reg', sub {$_[0] =~ s/ActiveWare/ActiveState/i; $_[0];});
   # import the whole script, but change all occurences of ActiveWare in the keynames
   # to ActiveState

  Win32::Registry::Import('c:\temp\Some.reg', sub {$_[0] =~ s/ActiveWare/ActiveState/i} and $_[0]);
   # similar to previous, but imports only the keys containing "ActiveWare"

  $reg = $HKLM->Create('SOFTWARE\Microsloth');
  $reg->Import('c:\temp\Some.reg',sub {$_[0] =~ /^HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft/./i; $_[0]});
   # imports the whole script saving the keys from HKLM\SOFTWARE\Microsoft into $reg
   # (that is HKLM\SOFTWARE\Microsloth)

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item ImportStr

 $obj->ImportStr( $string [ , \&keyfun [ , \&valuefun ]])
 Win32::Registry::ImportStr( $string [ , \&keyfun [ , \&valuefun ]])

Imports a registry script (.REG file) into registry. Unlike Import() the first parameter is not
a name of a file, but the script itself.

Otherwise it behaves exactly as Import().

 Ex.
  $reg->ImportStr(<<'*END*');
  [HKEY_CLASSES_ROOT\.pl]
  @="Perl"
  "Content Type"="text/plain"

  [HKEY_CLASSES_ROOT\Perl]
  @="Perl script"
  "EditFlags"=hex:00,00,00,00

  [HKEY_CLASSES_ROOT\Perl\Shell]
  @="Open"

  [HKEY_CLASSES_ROOT\Perl\Shell\Edit]
  @="&Edit"
  "EditFlags"=hex:01,00,00,00

  [HKEY_CLASSES_ROOT\Perl\Shell\Edit\Command]
  @="E:\\Soft\\PFE\\PFE32.EXE \"%1\""

  [HKEY_CLASSES_ROOT\Perl\Shell\Edit\ddeexec]
  @="[FileOpen(\"%1\")]"

  [HKEY_CLASSES_ROOT\Perl\Shell\Edit\ddeexec\Application]
  @="PFE32"

  [HKEY_CLASSES_ROOT\Perl\Shell\Edit\ddeexec\ifexec]
  @="E:\\Soft\\PFE\\PFE32.EXE"

  [HKEY_CLASSES_ROOT\Perl\Shell\Edit\ddeexec\topic]
  @="Editor"

  [HKEY_CLASSES_ROOT\Perl\Shell\GUIOpen]
  @="Execute in &GUI"

  [HKEY_CLASSES_ROOT\Perl\Shell\GUIOpen\Command]
  @="E:\\Soft\\ACTIVE~1\\bin\\REMGUI~1.EXE \"%1\" %*"

  [HKEY_CLASSES_ROOT\Perl\Shell\Open]
  @="E&xecute"
  "EditFlags"=hex:01,00,00,00

  [HKEY_CLASSES_ROOT\Perl\Shell\Open\Command]
  @="E:\\Soft\\ActivePerl\\bin\\Perl.exe \"%1\" %*"

  *END*



C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Load

 $reg->Load( $SubKey, $FileName [, REG_LOADTEMPORARY | REG_LOADPERSISTENT ])

The RegLoadKey function creates a subkey under HKEY_USER or
HKEY_LOCAL_MACHINE and stores registration information from a specified
file into that subkey. This registration information is in the form of a
hive. A hive is a discrete body of keys, subkeys, and values that is
rooted at the top of the registry hierarchy. A hive is backed by a
.DAT file and .LOG file.

The $obj should be either HKEY_LOCAL_MACHINE or HKEY_USERS
in the local or remote registry.
$SubKey is the name of the key, the file will be loaded as.
$FileName is the name of the .DAT file.

If you pass REG_LOADTEMPORARY as the third parameter, the hive will be automaticaly
unloaded at the end of script.

You may not load parts of Win95 registry on WinNT and vice versa!

Windows NT: The owner of the calling process must have
the SE_RESTORE_NAME privilege.

Windows 95: Security privileges are not supported nor required.

 Ex.
  $HKLM->Load('User','c:\winnt\profiles\user\ntuser.dat');
   #
  $HKLM->Load('Me','c:\winnt\profiles\me\ntuser.dat', REG_LOADTEMPORARY);
   # loaded only for this script, will be Unload()ed automaticaly
   # if possible.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item UnLoad

 $obj->UnLoad($SubKey)

Unloads a part of registry previously loaded by Load (RegLoadKey).
The $obj should be either HKEY_LOCAL_MACHINE or HKEY_USERS.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item MoveKey

 $key->MoveKey($to [, $as]);
 Win32::Registry::MoveKey($key, $to [, $as]);
 $key->MoveKey($SubKey1 , $SubKey2);
 Win32::Registry::MoveKey($key, $SubKey1 , $SubKey2);

Move a $key under $to, possibly with a different name or rename/move the $SubKey1 to $SubKey2.
You may use this to move a whole registry key with all subkeys into a different branch.
For example from HKEY_USERS\.DEFAULT to HKEY_CURRENT_USER.

The $key, $to and $SubKey1 may be either paths or registry objects, the $as and $SubKey2 must be key names/paths.
The $to MUST already exist, the copy will be created UNDER this key, it will NOT overwrite it.

 Ex.:
  use Win32::Registry;
  $to = $HKCU->Create('SOFTWARE\Jenda');
  Win32::Registry::CopyKey('HKEY_USERS\.DEFAULT\SOFTWARE\Jenda\ThisScript',$to);

 or

  use Win32::Registry;
  $to = $HKCU->Create('SOFTWARE\Jenda');
  Win32::Registry::CopyKey('HKEY_USERS\.DEFAULT\SOFTWARE\Jenda\ThisScript\'s defaults',$to,'ThisScript');

 or

  use Win32::Registry;
  $HKEY_CLASSES_ROOT->MoveKey( 'plfile', 'PerlScript');

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Num2Object

 $object = Win32::Registry::Num2Object($handle)

Makes a new object out of a handle number. Use with care!


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Open

 [ $SubKeyObj = ] $obj->Open("SubKey" [, $SubKeyObj] )
 [ $KeyObj = ] $obj->Open("\Full\path\to\a\Key" [, $KeyObj] )

Opens a subkey of a Registry object. The created object is returned
through the second parameter and as the function result.

If the first parameter starts by a backslash it is considered an absolute path
from the object's root. The same holds for C<Create>.

This function is provided for compatibility with Windows version 3.x. You should
use the C<OpenEx> method.

 Eg: $MS=$HKLM->Open( 'SOFTWARE\\Microsoft')
      or die "Cannot open Microsoft.\n";
     $MS->Open( '\\SOFTWARE\\ActiveWare',$AW )
      or die "Cannot open ActiveWare.\n";

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item OpenEx

 [ $SubKeyObj = ] $obj->Open("SubKey" , $Sam, [, $SubKeyObj] )
 [ $KeyObj = ] $obj->Open("\Full\path\to\a\Key", $Sam [, $KeyObj] )

Opens a subkey of a Registry object. The created object is returned
through the second parameter and as the function result.

The $Sam specifies the requested access. Posible values are
 KEY_ALL_ACCESS Full access (read, write, delete)
 KEY_READ       Read-only access
 KEY_WRITE      Write-only access

If the first parameter starts by a backslash it is considered an absolute path
from the object's root. The same holds for C<Create>.

 Eg: $MS=$HKLM->OpenEx( 'SOFTWARE\\Microsoft',KEY_ALL_ACCESS)
      or die "Cannot open Microsoft.\n";
     $MS->OpenEx( '\\SOFTWARE\\ActiveWare',KEY_WRITE, $AW )
      or die "Cannot open ActiveWare.\n";

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Path

 print $obj->Path;

Returns the path to the key. The root is not included.

 Ex.
  use Win32::Registry;
  $reg=$HKEY_LOCAL_MACHINE->Open('SOFTWARE\\Microsoft');
  print "\$reg's root is ",$reg->Root," and path is ",$reg->Path,".\n";

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item QueryKey

 $obj->QueryKey($class, $numberofSubkeys, $numberofVals )
 ($class, $numberofSubkeys, $numberofVals) = $obj->QueryKey()

Get info about the current key. In list context returns
the data. In scalar context returns just TRUE.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item QueryInfoKey

 $obj->QueryInfoKey($class, $classsz, $reserved, $numsubkeys,$maxsubkey,
                    $maxclass, $values, $maxvalname, $maxvaldata,
                    $secdesclen,$lastwritetime)
 ($class, $classsz, $reserved, $numsubkeys,$maxsubkey, $maxclass,
  $values, $maxvalname, $maxvaldata, $secdesclen,$lastwritetime) =
 $obj->QueryKey()

Get info about the current key. In list context returns
the data. In scalar context returns just TRUE.


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item QueryType

 $type_id = $obj->QueryType("value name")
 $obj->QueryType("value name",$type_id)

This method gets the type of a value in the current key or in some subkey.

There is a nickname C<GetType>

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item QueryValue

 $value = $obj->QueryValue("subkey name")
 $obj->QueryValue("subkey name",$value)

This method gets the content of the default value in the specified subkey.
It's primarily for compatibility with Win3.x (and with the original Win32::Registry).

You should use method GetValue, GetValueEx or QueryValueEx to get the
values in the current key.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item QueryValueEx

 $obj->QueryValueEx("value name", $type, $value);
 ($name,$type,$value) = $obj->QueryValueEx("value name");
 $value = $obj->QueryValueEx("value name");

Similar to C<GetValue>, but returns a value in the current keys, instead of the default
value in a subkey. In list context returns a list containing the name, type and value.
In scalar context returns just the value.

 Notice that you may not use
 ($name1,$type1,$value1) = $obj->QueryValueEx( "value name", $type, $value);
 If you use this function with three parameters it returns 1 in case of success

There is a nickname C<GetValueEx>

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Refresh

 $obj->Refresh()

Used to clear the cache. Since I'm not able to ask for
a single value in a key, I ask for all of them and then save them
for subsequent requests.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Root

 $reg->Root

Gives the root of the key. That is HKEY_LOCAL_MACHINE, HKEY_USERS or such.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item Save

 $reg->Save( $FileName )

Saves the current key into a file.
This file cannot already exist.
The file will have the System, Hidden
and Read-Only attributes set (before you begin searching around ...:-)!

Windows NT: The calling process must have the SE_RESTORE_NAME privilege.

Windows 95: Security privileges are not supported or required.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item SetValue

 $obj->SetValue($subkeyname,$type,$value);
 Win32::Registry::SetValue($keyname, $subkeyname, $type, $value);

SetValue sets the default value in a specified subkey of the current key.

 Ex.
  $reg->SetValue('Text',&REG_SZ,'Hello world.')
  $reg->SetValue('Number',&REG_DWORD,486);
  $reg->SetValue('Binary',&REG_BINARY,pack('c4',45,12,66,87));
  Win32::Registry::SetValue('HKEY_LOCAL_MACHINE\SOFTWARE\JendaTest', 'Number',&REG_DWORD,486);


C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item SetValues

 $obj->SetValues('value name',$Type,$value [, 'other value name',$Type,$value [, ...]])
 Win32::Registry::SetValues('key name','value name',$Type,$value [, 'other value name',$Type,$value [, ...]])

SetValues sets a value or multiple values in the current key.
If a value name is empty, it sets the default value of the key.

Please note the difference between SetValue and SetValues. While
SetValue sets the default value of a subkey, SetValues sets a value in
the current key! Run the examples (of course with a reasonable key opened in $reg
so that you do not corrupt your system!) to see the difference.

Generaly you should not use SetValue at all, cause it is pretty contraintuitive.
It is included only because of compatibility reasons.

The second form is equivalent to Create('key name')->SetValues( 'value name', ...).

 Ex.
  $reg->SetValues('Text',REG_SZ,'Hello world.')
  $reg->SetValues('Number', REG_DWORD, 486, 'Binary',REG_BINARY,pack('c4',45,12,66,87));
  $reg->SetValues( StrangeSyntax => REG_SZ ,'See perlop manpage');
  Win32::Registry::SetValues('HKEY_LOCAL_MACHINE\SOFTWARE\JendaTest',
    FirstName => &REG_SZ, 'Jan', LastName => REG_SZ, 'Krynicky',
    Email => REG_SZ, 'Jenda@Krynicky.cz');

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=item SetValueEx

 $obj->SetValueEx("value name",$Reserved,$Type,$value)
 Win32::Registry::SetValues('key name',"value name",$Reserved,$Type,$value)

Sets a value in the current key or in a subkey. I don't have a clue what the
$Reserved is. This function is included for compatibility with original
Win32::Registry.

C<Win32::Registry> | C<Base objects> |  C<Methods and functions> | C<Constants and Variables>

=back

=head2 Constants and Variables

=over 2

=item Types of registry values

  0 REG_NONE
   No value type.

  1 REG_SZ
   A sequence of characters representing human
   readable text. Unicode null terminated string.
   (You do not have to care for the Unicode nor
   null termination. Use ordinary perl strings.)

  2 REG_EXPAND_SZ
   An expandable data string, which is text that
   contains a variable to be replaced when called by
   an application (ex : %windir%\system\wsock32.dll).
   Unicode null terminated string.

  3 REG_BINARY
   Raw binary data. Most hardware component
   information is stored as binary data, and can be
   displayed in hexadecimal format.

  4 REG_DWORD
   32 bits number.
    REG_DWORD_LITTLE_ENDIAN
   Same as REG_DWORD.

  5 REG_DWORD_BIG_ENDIAN
   32 bits number but in big endian format.
   Not commonly used.

  6 REG_LINK
   A symbolic link (unicode).

  7 REG_MULTI_SZ
   A multiple string. Values that contain lists or
   multiple values in human readable text are usually
   this type (unicode). Entries are separated by
   NULL characters.

  8 REG_RESOURCE_LIST
   Ressource list in the ressource map.

  9 REG_FULL_RESOURCE_DESCRIPTOR
   Resource list in the hardware description

 10 REG_RESSOURCE_REQUIREMENT_MAP
   Resource list in the hardware description.

=item %RegType

Maps the registry data type codes to their human readable names.

 Ex.
  $reg=$HKEY_LOCAL_MACHINE->Open('SOFTWARE\ActiveWare\Perl5');
  ($name,$type,$value) = $reg->GetValueEx('BIN');
  print "$name : $RegType{$type} : $value\n";

=item $Win32::Registry::CFG

This hash is used to store the configuration of Win32::Registry module.
You may use it to change the behaviour of some functions.

 $Win32::Registry::CFG{'value_objects'}

This value affects the C<FindValue>* methods. If it is set, FindValue*
creates C<Win32::Registry::Value> objects for the values found and passes
them to the function. (See C<FindValue>.)

By default not defined.


 $Win32::Registry::CFG{'canonpath'}

This value controls the behaviour of Open() and Create() function. If it
is set (default) the module processes the paths the same way directory
paths are being processed. That is '.' means current directory, ooops
key, '..' the key one step to root and '\' is the root
(HKEY_LOCAL_MACHINE etc).

This means that you may for example write this :

 $reg->Open('..');
or
 $dot->Open('..\.doc');


 $Win32::Registry::CFG{'expand'}

If set to a true value all REG_EXPAND_SZ values will be processed by
Win32::ExpandEnvironmentStrings() to expand the %VARIABLES%.

=back

=head2 NOTES

For performance reasons the module was split into three pieces.
Win32/Registry.pm, Win32/Registry/Find.pm and Win32/Registry/IO.pm.

The two "submodules" are loaded only if necessary. This confuses pl2exe and perl2exe!
If you intend to "compile" the script, you should explicitly use them if you are gonna
use any Find* or Save/Load/Unload/Import/Export. Please keep in mind that Import and Export
use some Find* functions!

 use Win32::Registry;
 use Win32::Registry::Find;
 use Win32::Registry::IO;

should fix all problems.

Sorry for the inconvenience.

=head2 AUTHOR

Jan Krynicky <Jenda@Krynicky.cz> & someone from ActiveState/ActiveWare/Hip Comunications

This module is based on the original Win32::Registry.pm from ActiveWare Perl 3xx.
I've rewriten almost everything during time. It still uses the C/XS code, by ActiveWare,
later cleared and repackaged into libwin32 by GSAR <gsar@activestate.com>.

I try to support both the Perl 3xx and never perls using libwin32 and hide the differences.

=head2 COPYRIGHT

Copyright (c) 1997-1999 Jan Krynicky <Jenda@Krynicky.cz>. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

