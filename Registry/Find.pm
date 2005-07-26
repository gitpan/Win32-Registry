package Win32::Registry;
#version 0.00.28

$Win32::Registry::Find_loaded=1;

sub FindKey
{
 my ($self, $fun, $arr) = @_;$self=Open($self) unless ref($self) eq 'Win32::Registry';
 my $outfun;

 if (ref $fun !~ /^CODE\(/ ) {
  die 'Ussage: $obj->FindKey(\&function) or $obj->FindKey(\&bool_function,\@array)',"\n";
 }

 if (defined $arr) {
  if (ref $arr eq 'ARRAY') {
   my $boolfun=$fun;
   undef $fun;
   $fun = sub { push @$arr, $_[0]->{'path'} if &$boolfun($_[0]) };
  } elsif (ref $arr eq 'CODE') {
    $outfun = $arr;
    undef $arr;
  }
 }

 my $Key;

 my $i=0;
 while (RegEnumKey( $self->{'handle'},$i++, $Key ))   #Recursing thru the key
 {
        last if (!defined $Key);

        my $reg;
        if ($reg=$self->Open($Key)) {
         $Win32::Registry::Find::path = $reg->{path};
         $fun->($reg) if defined($fun);
         if (defined $Win32::Registry::Find::skip_subkeys) {
            undef $Win32::Registry::Find::skip_subkeys;
         } else {
            $reg->FindKey($fun,$outfun);
         }
         $outfun->($reg) if defined($outfun);
        }
 }
}


sub FindKeyDepth
{
 my ($self, $fun, $arr) = @_;

 if (ref $fun !~ /^CODE\(/ ) {
  die 'Ussage: $obj->FindKeyDepth(\&function) or $obj->FindKeyDepth(\&bool_function,\@array)',"\n";
 }

 if ($arr) {
  my $boolfun=$fun;
  undef $fun;
  $fun = sub { push @$arr, $_[0]->{'path'} if &$boolfun($_[0]) };
 }

 my $Key;

 my $i=0;
 while (RegEnumKey( $self->{'handle'},$i++, $Key ))   #Recursing thru the key
 {
        last if (!defined $Key);

        my $reg;
        if ($reg=$self->Open($Key)) {
         $reg->FindKey($fun);
         &$fun($reg);
        }
 }
}

sub FindValue {
 my ($self,$fun,$inkeyfun,$outkeyfun,$outsubkeys) = @_;
 if ($fun !~ /^CODE\(/
  or ( defined $inkeyfun and $inkeyfun !~ /^CODE\(/ )
  or ( defined $outkeyfun and $outkeyfun !~ /^CODE\(/ )
  or ( defined $outsubkeys and $outsubkeys !~ /^CODE\(/ )
 ) {
  die 'Ussage: $obj->FindValue(\&function [, \&KeyEnterFunction [, \&KeyLeaveFunction [, \&SubKeysLeaveFunction]]]);',"\n";
 }
 &$inkeyfun($self) if defined $inkeyfun;
 $self->FindValueInKey($fun)
   unless defined $Win32::Registry::Find::skip_values;
 &$outkeyfun($self) if defined $outkeyfun;
 unless (defined $Win32::Registry::Find::skip_subkeys) {
    my $sub;
    if (defined $inkeyfun and defined $outkeyfun) {
        $sub = sub {
            &$inkeyfun($_[0]);
            $_[0]->FindValueInKey($fun)
             unless defined $Win32::Registry::Find::skip_values;
            &$outkeyfun($_[0]);
        };
    } elsif (defined $inkeyfun) {
        $sub = sub {
            &$inkeyfun($_[0]);
            $_[0]->FindValueInKey($fun)
             unless defined $Win32::Registry::Find::skip_values;
        };
    } elsif (defined $outkeyfun) {
        $sub = sub {
            $_[0]->FindValueInKey($fun);
            &$outkeyfun($_[0]);
        };
    } else {
        $sub = sub { FindValueInKey($_[0],$fun)}
    }
    $self->FindKey($sub,$outsubkeys);
 }
 &$outsubkeys($self) if defined $outsubkeys;
}

sub FindValueDepth {
 my ($self,$fun) = @_;
 if ($fun !~ /^CODE\(/) {
  die 'Ussage: $obj->FindValueDepth(\&function);',"\n";
 }
 $self->FindValueInKey($fun);
 $self->FindKeyDepth(sub {FindValueInKey($_[0],$fun)});
}

{
my $oldw;
BEGIN {
$oldw = $^W;  # force warnings off - "x used only once ..."
$^W = 0;
}
sub FindValueInKey {
 my ($self,$fun) = @_;
 if ($fun !~ /^CODE\(/) {
  die 'Ussage: $obj->FindValue(\&function);',"\n";
 }
 my %hash;
 $self->GetValues(\%hash);
 $Win32::Registry::Find::key = $self;
 my ($name,$arr);
 while (($name,$arr) = each %hash) {
  $Win32::Registry::Find::name = $name;
  $Win32::Registry::Find::type = $$arr[1];
  $Win32::Registry::Find::value = $$arr[2];
  if ($Win32::Registry::CFG{'value_objects'}) {
   &$fun(new Win32::Registry::Value($self,$name,$$arr[1],$$arr[2]));
  } else {
   &$fun();
  }
 }
}
BEGIN {$^W=$oldw;}
}

package Win32::Registry::Value;

sub new {
 my ($class,$key,$name,$type,$value) = @_;
 my $self={};
 $self->{'key'}=$key;
 $self->{'name'}=$name;
 $self->{'type'}=$type;
 $self->{'value'}=$value;
 bless $self;
}

sub Set {
 $_[0]->{'key'}->SetValue($_[0]->{'name'},$_[0]->{'type'},$_[1]);
}

sub Delete {
 $_[0]->{'key'}->DeleteValue($_[0]->{'name'});
}

sub Get {
 if (wantarray) {
  return $_[0]->{'name'},$_[0]->{'type'},$_[0]->{'value'};
 } else {
  return $_[0]->{'value'};
 }
}

sub Value {
 return $_[0]->{'value'};
}

sub Name {
 return $_[0]->{'name'};
}

sub Type {
 return $_[0]->{'type'};
}

1;
