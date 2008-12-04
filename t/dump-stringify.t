use t::TestYAMLOld tests => 6;

no_diff;

package Foo;

use overload '""' => \&stringy;

sub stringy { 'Hello mate!' }

sub new { bless { 'Hello' => 'mate!' }, shift };

package main;

my $foo = Foo->new;

my $stringy_dump = <<'';
--- Hello mate!

my $object_dump = <<'';
--- !!perl/hash:Foo
Hello: mate!

my $yaml;

$yaml = Dump($foo);
is $yaml, $object_dump, "Global stringification default dump";

$YAML::Old::Stringify = 1;
$yaml = Dump($foo);
is $yaml, $stringy_dump, "Global stringification enabled dump";

$YAML::Old::Stringify = 0;
$yaml = Dump($foo);
is $yaml, $object_dump, "Global stringification disabled dump";

require YAML::Old::Dumper;
my $dumper = YAML::Old::Dumper->new;

$yaml = $dumper->dump($foo);
is $yaml, $object_dump, "Local stringification default dump";

$dumper->stringify(1);
$yaml = $dumper->dump($foo);
is $yaml, $stringy_dump, "Local stringification enabled dump";

$dumper->stringify(0);
$yaml = $dumper->dump($foo);
is $yaml, $object_dump, "Local stringification disabled dump";