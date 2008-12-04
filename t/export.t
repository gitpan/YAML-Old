use Test::YAML();
BEGIN { 
    @Test::YAML::EXPORT =
        grep { not /^(Dump|Load)(File)?$/ } @Test::YAML::EXPORT;
}
use t::TestYAMLOld tests => 3;

use YAML::Old;

ok defined(&Dump),
    'Dump() is exported';
ok defined(&Load),
    'Load() is exported';
ok not(defined &Store),
    'Store() is not exported';
