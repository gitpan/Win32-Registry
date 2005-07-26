#Portions (c) 1995 Microsoft Corporation. All rights reserved.
#	Developed by ActiveWare Internet Corp., http://www.ActiveWare.com
# modified to use Test::More and test the new features by Jenda@Krynicky.cz

use Test::More qw(no_plan);
use strict;
use warnings;
BEGIN { use_ok( 'Win32::Registry' ); }

$HKEY_CLASSES_ROOT->DeleteKey('ntperl.test.other', 1); # just in case

sub NULL () {undef};

my ($hkey, $hkey2);

ok( $HKEY_CLASSES_ROOT->Create( 'ntperl.test.key', $hkey), "Create HKCR\\ntperl.test.key - return value");

ok( ref $hkey, "Create HKCR\\ntperl.test.key - created object");

ok( $HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key' ), "Delete HKCR\\ntperl.test.key - the delete should succeed");


ok( ! $HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key' ), "Delete HKCR\\ntperl.test.key - the delete should fail");


ok( $HKEY_CLASSES_ROOT->Create( 'ntperl.test.key', $hkey2) && ref( $hkey2), "Create HKCR\\ntperl.test.key again");

ok ( $hkey->Close(), "Close \$hkey");

ok( $HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key' ), "Delete HKCR\\ntperl.test.key");


ok ($hkey2->Close(), "Close \$hkey2");

ok( $HKEY_CLASSES_ROOT->Create( 'ntperl.test.key', $hkey ) && ref($hkey), "Create HKCR\\ntperl.test.key again");

my ($sk0, $sk1, $sk2);
ok( $hkey->Create( 'k0', $sk0 ) && ref($sk0), "Create subkey .\\k0");
ok( $hkey->Create( 'k1', $sk1 ) && ref($sk1), "Create subkey .\\k1");
ok( $hkey->Create( 'k2', $sk2 ) && ref($sk2), "Create subkey .\\k2");
#$sk0->show_me();

my $keys=[];
$hkey->GetKeys( $keys );
is( $#$keys, 2, 'List the subkeys' );

{
	my $i = 0;
	foreach ( sort( @$keys ) ) {
		like( $_, qr/^k$i$/, "Test the subkey names : $_");
		$i++;
	}
}

ok( $hkey->SetValue('k0', REG_SZ, "silly piece of info" ), 'Set default value of k0');

{
	my $data;
	ok( $hkey->QueryValue( 'k0', $data ), 'Query the value');
	is( $data, "silly piece of info", 'Test the value');
}

ok( $sk0->DeleteValue( "\000" ), "Delete the value");
{ my $data;
	ok( $hkey->QueryValue( 'k0', $data ), "Query the value - it should not be there anymore, but the method still returns true");
	isnt( $data, "silly piece of info", "Query the value - it should not be there anymore");
}

ok( !$sk0->DeleteValue( "\000" ), "Delete the value - it should not be there anymore");

ok( $sk0->SetValueEx( 'string0',NULL, REG_SZ, "data0" ), 'Set "string0" value');
ok( $sk0->SetValueEx( 'string1',NULL, REG_SZ, "data1" ), 'Set "string1" value');
ok( $sk0->SetValueEx( 'string2',NULL, REG_SZ, "data2" ), 'Set "string2" value');

ok( $sk0->SetValueEx( 'none',NULL, REG_NONE, "" ), 'Set "none" value');
ok( $sk0->DeleteValue( 'none' ), 'Delete "none" value');

{ my %values;
	ok( $sk0->GetValues( \%values ), "QueryValues");
	my @keys = keys( %values );
	is( scalar(@keys), 3, 'There should be three values');

	my $i = 0;
	foreach ( sort( keys( %values ) ) ) {
		my $aref = $values{ $_ };
		my ( $name, $type, $data ) = @$aref;
		ok( ( $name eq "string$i" && $type == &REG_SZ && $data eq "data$i" ), qq{Test value and type of "string$i"});
		$i++;
	}
}

foreach ( 'string0', 'string1', 'string2' ) {
	ok( $sk0->DeleteValue( $_ ), qq{Delete value "$_"});
}

ok( $sk0->Close() && $sk1->Close() && $sk2->Close(), "Close subkeys");

ok( $hkey->DeleteKey( 'k0' ) && $hkey->DeleteKey( 'k1' ) && $hkey->DeleteKey( 'k2' ), "Delete subkeys");

ok( $hkey->Close(), "Close the HKCR\\ntperl.test.key");

ok( $HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key' ), "Delete the HKCR\\ntperl.test.key");


# test features added by Jenda

ok( $hkey = Win32::Registry::Create( 'HKEY_CLASSES_ROOT\ntperl.test.key' ), "Create() called as function, returning the key");

ok( Win32::Registry::Open( 'HKEY_CLASSES_ROOT\ntperl.test.key', $hkey2 ), "Open() called as function");

ok( $hkey->{'root'} eq $hkey2->{'root'} && $hkey->Path eq $hkey2->Path,
	'The objects should be opened to the same key');

ok( $hkey->{'handle'} != $hkey2->{'handle'}, '... but should have different handles');

my $subsub1;
ok( $subsub1 = $hkey->Create('sub1')->Create('subsub1'), 'Create sub1 and subsub1');

ok( $hkey->Create('sub2'), 'Create sub1 and subsub1');
ok( $hkey->Create('sub3'), 'Create sub1 and subsub1');

my $sub1;
ok( $sub1 = $subsub1->Open('..'), 'Open subsub1\..');
is( $sub1->Path, '\ntperl.test.key\sub1', '... do we have the right key?');

my $sub2;
$sub2 = $hkey->Open('sub2');
$sub2->Create('sub2A');
$sub2->Create('sub2B');
$sub2->Create('sub2C');

{
	my @subkeys = sort $hkey->GetKeys();
	is( join(',', @subkeys), 'sub1,sub2,sub3', 'List the subkeys');
}

{
	my $good = 0;
	$hkey->ForKeys( sub {
		my ($key, $subkeyname) = @_;
		if ($subkeyname =~ /^sub\d$/ and $key->Path eq '\ntperl.test.key' and ref($key->Open($subkeyname))) {
			$good ++
		} else {
			diag("\tsubkey: $subkeyname\n\tpath: $key->{'path'}\n");
		}
	});
	ok( $good == 3, "ForKeys()");
}

ok( $hkey->SetValues(
	'string1', REG_SZ, 'value1',
	'string2', REG_SZ, 'value2',
	'string3', REG_SZ, 'value3',
	'dword1', REG_DWORD, 1,
	'dword2', REG_DWORD, 2,
	'dword3', REG_DWORD, 3,
	'xstring', REG_EXPAND_SZ, '%TEMP%\Perl',
	'bin', REG_BINARY, pack('NNNN',1,25,78,94),
	'mstring', REG_MULTI_SZ, "a rather long line\0another line\0and yet another",
), 'SetValues');

is( $hkey->GetValue('string1'), 'value1', 'GetValue - as function');
{ my $value;
	$hkey->GetValue('string1', $value);
	is($value, 'value1', 'GetValue - as procedure');
}

is( $hkey->GetValue('xstring'), '%TEMP%\Perl', 'GetValue - REG_EXPAND_SZ without expansion');
$Win32::Registry::CFG{'expand'} = 1;
is( $hkey->GetValue('xstring'), "$ENV{TEMP}\\Perl", 'GetValue - REG_EXPAND_SZ with expansion');

is( $hkey->GetValue('dword1'), 1, 'GetValue - REG_DWORD');

is( join(',', unpack('NNNN',$hkey->GetValue('bin')) ), '1,25,78,94',
	'GetValue - REG_BINARY');

is( $hkey->GetValue('mstring'), "a rather long line\0another line\0and yet another",
	'GetValue - REG_MULTI_SZ');

{
	my %values;
	ok( $hkey->GetValues(\%values), "GetValues()");

	is( scalar(keys %values), 9, "GetValues() - count of values");
	is( join(',', @{$values{'string1'}}),
		join(',', 'string1', REG_SZ, 'value1'),
		"GetValues() - compare string1");
	is( join(',', @{$values{'dword1'}}),
		join(',', 'dword1', REG_DWORD, 1),
		"GetValues() - compare dword1");
	is( join(',', @{$values{'xstring'}}),
		join(',', 'xstring', REG_EXPAND_SZ, "$ENV{TEMP}\\Perl"),
		"GetValues() - compare xstring");
	is( join(',', @{$values{'bin'}}),
		join(',', 'bin', REG_BINARY, pack('NNNN',1,25,78,94)),
		"GetValues() - compare bin");
	is( join(',', @{$values{'mstring'}}),
		join(',', 'mstring', REG_MULTI_SZ, "a rather long line\0another line\0and yet another"),
		"GetValues() - compare string1");
}

{
	my %values;
	ok( $hkey->GetOnlyValues(\%values), "GetOnlyValues()");

	is( scalar(keys %values), 9,
		"GetOnlyValues() - count of values");
	is( $values{'string1'}, 'value1',
		"GetOnlyValues() - compare string1");
	is( $values{'dword1'}, 1,
		"GetOnlyValues() - compare dword1");
	is( $values{'xstring'}, "$ENV{TEMP}\\Perl",
		"GetOnlyValues() - compare xstring");
	is( $values{'bin'}, pack('NNNN',1,25,78,94),
		"GetOnlyValues() - compare bin");
	is( $values{'mstring'}, "a rather long line\0another line\0and yet another",
		"GetOnlyValues() - compare string1");
}

{
	my ($total, $found) = (0,0);
	$hkey->FindKey(sub {
		$total++;
		$found++
			if $_[0]->Path() eq '\ntperl.test.key\sub1';
	});
	ok( $total == 7 && $found == 1, 'FindKey( \&entersub)');

	($total, $found) = (0,0);
	$hkey->FindKey(undef, sub {
		$total++;
		$found++
			if $_[0]->Path() eq '\ntperl.test.key\sub1';
	});
	ok( $total == 7 && $found == 1, 'FindKey( undef, \&leavesub)');

	my $level = 0;
	my $list = '';
	$hkey->FindKey(
		sub {
			$list .= ("\t"x$level) . $_[0]->Path() . "\n";
			$level++;
		},
		sub {
			$level--;
			$list .= ("\t"x$level) . $_[0]->Path() . "\n";
		}
	);

	my $good_list = <<'*END*';
\ntperl.test.key\sub1
	\ntperl.test.key\sub1\subsub1
	\ntperl.test.key\sub1\subsub1
\ntperl.test.key\sub1
\ntperl.test.key\sub2
	\ntperl.test.key\sub2\sub2A
	\ntperl.test.key\sub2\sub2A
	\ntperl.test.key\sub2\sub2B
	\ntperl.test.key\sub2\sub2B
	\ntperl.test.key\sub2\sub2C
	\ntperl.test.key\sub2\sub2C
\ntperl.test.key\sub2
\ntperl.test.key\sub3
\ntperl.test.key\sub3
*END*
	$good_list =~ s/(?:\x0D\x0A?|\x0A)/\n/sg;
	is( $list, $good_list, 'FindKey( \&entersub, \&leavesub) - generate list of entered and leaved keys');

	my @matching;
	$hkey->FindKey( sub {$_[0]->Path =~ /sub2/}, \@matching);
	is( join(',', @matching),
		'\ntperl.test.key\sub2,\ntperl.test.key\sub2\sub2A,\ntperl.test.key\sub2\sub2B,\ntperl.test.key\sub2\sub2C',
		'FindKey( \&boolsub, \@matching)');
}


ok( Win32::Registry::SetValues('HKEY_CLASSES_ROOT\ntperl.test.key\sub2\sub2A',
	'And the winner is', REG_SZ, 'Jenda!'
), "SetValues() as a function");

{
	my $found;
	$hkey->FindValue(sub {
		$found = $Win32::Registry::Find::value
			if $Win32::Registry::Find::name eq 'And the winner is';
	});
	is( $found, 'Jenda!', 'FindValues( \&valuesub)');

	$found = '';

	$hkey->FindValue(
		sub {
			$found .= "$Win32::Registry::Find::name=$Win32::Registry::Find::value\n"
				if $Win32::Registry::Find::name =~ /s/;
		},
		sub { $found .= "[" . $_[0]->Root() . $_[0]->Path()."]\n"},
		sub { $found .= "\n"}
	);

	my $good_found = <<"*END*";
[HKEY_CLASSES_ROOT\\ntperl.test.key]
xstring=$ENV{TEMP}\\Perl
string3=value3
string2=value2
mstring=a rather long line\\0another line\\0and yet another
string1=value1

[HKEY_CLASSES_ROOT\\ntperl.test.key\\sub1]

[HKEY_CLASSES_ROOT\\ntperl.test.key\\sub1\\subsub1]

[HKEY_CLASSES_ROOT\\ntperl.test.key\\sub2]

[HKEY_CLASSES_ROOT\\ntperl.test.key\\sub2\\sub2A]
And the winner is=Jenda!

[HKEY_CLASSES_ROOT\\ntperl.test.key\\sub2\\sub2B]

[HKEY_CLASSES_ROOT\\ntperl.test.key\\sub2\\sub2C]

[HKEY_CLASSES_ROOT\\ntperl.test.key\\sub3]

*END*
	$good_found =~ s/(?:\x0D\x0A?|\x0A)/\n/sg;
	$good_found =~ s/\\0/\0/g;

	is( $found, $good_found, 'FindValues( \&valuesub, \&enterkeysub, \&leavekeysub)');
}

{
	my %seen;
	$hkey->FindValue(
		sub {},
		sub { $seen{$_[0]->Path}++ },
		sub { $seen{$_[0]->Path}++ },
		sub { $seen{$_[0]->Path}++ }
	);
	is(scalar(keys %seen), 8, "FindValue( sub {}, \&enterkeysub, \&leavekeysub, \&leavesubkeyssub) - count");
		# yes 8, FindValue() starts with the $obj key.
	ok(! (grep $_ != 3, values %seen), "FindValue( sub {}, \&enterkeysub, \&leavekeysub, \&leavesubkeyssub) - count");

}

ok( $hkey->MoveKey( $HKEY_CLASSES_ROOT,'ntperl.test.other'),
	"\$hkey->MoveKey( \$HKEY_CLASSES_ROOT, 'ntperl.test.other')");

ok( $hkey->Path() eq '\ntperl.test.other' and $hkey->Root() eq 'HKEY_CLASSES_ROOT',
	"MoveKey() - the \$hkey changed");

ok( $hkey = $hkey->CopyKey( $HKEY_CLASSES_ROOT, 'ntperl.test.key'),
	"\$hkey->CopyKey( \$HKEY_CLASSES_ROOT, 'ntperl.test.other')");

ok( $hkey->Path() eq '\ntperl.test.key' and $hkey->Root() eq 'HKEY_CLASSES_ROOT',
	"CopyKey() - returned the copy object");

$HKEY_CLASSES_ROOT->DeleteKey('ntperl.test.other', 1);

ok( $hkey2 = $HKEY_CLASSES_ROOT->CopyKey( 'ntperl.test.key' => 'ntperl.test.other'),
	"\$HKEY_CLASSES_ROOT->CopyKey( 'ntperl.test.key' => 'ntperl.test.other')");

ok( $hkey2->Path() eq '\ntperl.test.other' and $hkey2->Root() eq 'HKEY_CLASSES_ROOT',
	"CopyKey() - returned the copy object");

$hkey2->DeleteKey('', 1);

SKIP: {
	# Export/Import
	skip "Can't create good.reg file in the current directory!", 15 unless open my $OUT, '> good.reg';
	while (<DATA>) {
		print $OUT $_
	}
	close $OUT;

	ok( $hkey->Export('test.reg'), 'Export() - the action');

	my ($GOOD, $TEST);
	open $GOOD, '< good.reg';
	open $TEST, '< test.reg';
	my ($error, $good_line, $test_line) = (0);
	while (defined ($good_line = <$GOOD>)) {
		$test_line = <$TEST>;
		$error++
			if $good_line ne $test_line;
	}
	close $GOOD;
	close $TEST;
	ok( $error == 0, "Export() - the data");

	ok( $HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key', 1), 'Delete the HKCR\ntperl.test.key with subkeys');

	ok( !$HKEY_CLASSES_ROOT->Open( 'ntperl.test.key'), 'It was really deleted');

	ok( $HKEY_CLASSES_ROOT->Import('test.reg'), 'Import() - the action');

	$hkey = $HKEY_CLASSES_ROOT->Open( 'ntperl.test.key');
	ok( $hkey->Open('Sub1') && $hkey->Open('Sub2') && $hkey->Open('Sub3'), 'Import() - subkeys');

	my %values;
	$hkey->GetOnlyValues(\%values);
	ok( scalar(keys %values) == 9, "Import() - count of values");

	ok( $values{'string1'} eq 'value1'
		&& $values{'dword1'} == 1
		&& $values{'xstring'} eq "$ENV{TEMP}\\Perl"
		&& $values{'bin'} eq pack('NNNN',1,25,78,94)
		&& $values{'mstring'} eq "a rather long line\0another line\0and yet another",
		"Import() - compare values");

	$HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key', 1);

	ok( $HKEY_CLASSES_ROOT->Import('test.reg', sub {my $key = shift(); $key =~ s{\\sub(\d)(\\|$)}{\\Sub$1$1$2};$key}),
		"Import() - rename subN to SubNN");

	ok ( ($hkey2 = $hkey->Open('Sub22') and $hkey2->Open('sub2A') and !$hkey->Open('sub2')),
		'Import() - rename subN to SubNN - test');

	undef $hkey2; undef $hkey;

	$HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key', 1);

	ok( $HKEY_CLASSES_ROOT->Import('test.reg', undef, sub {$_[0] =~ /3/}),
		"Import() - filter values");

	my %values;
	$hkey = $HKEY_CLASSES_ROOT->Open( 'ntperl.test.key');
	$hkey->GetValues(\%values);

	ok ( (
		scalar(keys %values) == 2
		and join(',', @{$values{'string3'}}) eq join(',', 'string3', REG_SZ, 'value3')
		and join(',', @{$values{'dword3'}}) eq join(',', 'dword3', REG_DWORD, 3)
		and !exists $values{'string1'}
		),
		'Import() - filter values - test');

	$HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key', 1);

	$HKEY_CLASSES_ROOT->Import('test.reg');
	unlink 'good.reg';
	unlink 'test.reg';

	$hkey = $HKEY_CLASSES_ROOT->Open( 'ntperl.test.key');
	#Save/Load/UnLoad
	unlink 'test.dat';
	unlink 'test.dat.LOG';
	ok( $hkey->Save('test.dat'), 'Save()')
		or diag($^E);

	ok( $HKEY_LOCAL_MACHINE->Load('ntperl.test', 'test.dat', REG_LOADTEMPORARY), 'Load()')
		or diag($^E);

	ok( $hkey2 = $HKEY_LOCAL_MACHINE->Open('ntperl.test'), 'Open as HKEY_LOCAL_MACHINE\ntperl.test');

	ok( $hkey2->GetValue('string1') eq 'value1', "Are there the values there?");

	$hkey2->Close();
	ok( $HKEY_LOCAL_MACHINE->UnLoad('ntperl.test'), 'UnLoad()')
		or diag($^E);
	unlink 'test.dat';
	unlink 'test.dat.LOG';
}

ok( $HKEY_CLASSES_ROOT->DeleteKey( 'ntperl.test.key', 1), 'Delete the HKCR\ntperl.test.key with subkeys');


__DATA__
REGEDIT4

[HKEY_CLASSES_ROOT\ntperl.test.key]
"string1"="value1"
"string2"="value2"
"string3"="value3"
"dword1"=dword:00000001
"dword2"=dword:00000002
"dword3"=dword:00000003
"xstring"=hex(2):25,54,45,4d,50,25,5c,50,65,72,6c,00
"bin"=hex:00,00,00,01,00,00,00,19,00,00,00,4e,00,00,00,5e
"mstring"=hex(7):61,20,72,61,74,68,65,72,20,6c,6f,6e,67,20,6c,69,6e,65,00,61,\
  6e,6f,74,68,65,72,20,6c,69,6e,65,00,61,6e,64,20,79,65,74,20,61,6e,6f,74,68,\
  65,72,00

[HKEY_CLASSES_ROOT\ntperl.test.key\sub1]

[HKEY_CLASSES_ROOT\ntperl.test.key\sub1\subsub1]

[HKEY_CLASSES_ROOT\ntperl.test.key\sub2]

[HKEY_CLASSES_ROOT\ntperl.test.key\sub2\sub2A]
"And the winner is"="Jenda!"

[HKEY_CLASSES_ROOT\ntperl.test.key\sub2\sub2B]

[HKEY_CLASSES_ROOT\ntperl.test.key\sub2\sub2C]

[HKEY_CLASSES_ROOT\ntperl.test.key\sub3]

