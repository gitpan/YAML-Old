package TestYAML;
use lib 'inc';
use Test::YAML -Base;

$Test::YAML::YAML = 'YAML::Old';

$^W = 1;
